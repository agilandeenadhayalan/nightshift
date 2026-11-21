package com.nightshift.app;

import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Locale;
import java.util.TimeZone;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

/** Pure reducer. A notification is a hint, never permission to answer/capture. */
public final class CallInvitationPolicy {
  private static final Pattern UUID = Pattern.compile("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}");
  private static final Pattern VERSION = Pattern.compile("[1-9][0-9]{0,9}");
  private static final Set<String> KEYS = new HashSet<>(Arrays.asList("schemaVersion", "type", "callId", "eventId", "callVersion", "expiresAt", "registrationId", "registrationVersion", "bindingId"));
  public static final class Binding {
    public final String registrationId, bindingId, boot;
    public final long version, serverUpper, wall, elapsed, expiry;
    public Binding(String registrationId, String bindingId, long version, String boot,
        long serverTime, long expiry, long wall, long elapsed, long requestElapsed) {
      if (!uuid(registrationId) || !uuid(bindingId) || version < 1 || boot == null || boot.isEmpty() ||
          requestElapsed < 0 || requestElapsed > 30000 || expiry <= serverTime || expiry - serverTime > 1800000)
        throw new IllegalArgumentException("Invalid binding");
      this.registrationId=registrationId; this.bindingId=bindingId; this.version=version; this.boot=boot;
      this.serverUpper=serverTime+requestElapsed; this.expiry=expiry; this.wall=wall; this.elapsed=elapsed;
    }
    public long serverNow(long nowWall, long nowElapsed, String nowBoot) {
      long delta=nowElapsed-elapsed;
      if (!boot.equals(nowBoot) || delta<0 || delta>1800000 || Math.abs((nowWall-wall)-delta)>5000)
        return Long.MAX_VALUE;
      return serverUpper+delta;
    }
    public boolean valid(long wall, long elapsed, String boot) { return serverNow(wall,elapsed,boot)<expiry; }
  }
  public static final class Seen {
    public final long version, expires;
    public final boolean terminal;
    public Seen(long version,long expires,boolean terminal) { this.version=version;this.expires=expires;this.terminal=terminal; }
  }
  public static final class Result {
    public final String action, callId;
    public final Map<String,String> payload;
    Result(String action,Map<String,String> data) { this.action=action;payload=data;callId=data.get("callId"); }
  }
  public static boolean uuid(String value) { return value!=null && UUID.matcher(value).matches(); }
  public static long date(String value) {
    if(value==null || !value.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z"))
      throw new IllegalArgumentException("Invalid date");
    try {
      SimpleDateFormat format=new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",Locale.ROOT);
      format.setLenient(false);format.setTimeZone(TimeZone.getTimeZone("UTC"));
      return format.parse(value).getTime();
    } catch(Exception invalid) { throw new IllegalArgumentException("Invalid date"); }
  }
  public static boolean validPayload(Map<String,String> data) {
    try {
      if(data==null || !data.keySet().equals(KEYS)) return false;
      int bytes=2;
      for(var entry:data.entrySet()) {
        if(entry.getValue()==null) return false;
        bytes+=entry.getKey().getBytes(StandardCharsets.UTF_8).length+entry.getValue().getBytes(StandardCharsets.UTF_8).length+6;
      }
      if(bytes>2048 || !"1".equals(data.get("schemaVersion")) ||
        !("call.invitation".equals(data.get("type")) || "call.terminal".equals(data.get("type")))) return false;
      for(String key:Arrays.asList("callId","eventId","registrationId","bindingId")) if(!uuid(data.get(key))) return false;
      for(String key:Arrays.asList("callVersion","registrationVersion")) if(!VERSION.matcher(data.get(key)).matches()) return false;
      date(data.get("expiresAt")); return true;
    } catch(RuntimeException ignored) { return false; }
  }
  public static boolean addressed(Map<String,String> data, Binding binding,long wall,long elapsed,String boot) {
    if(!validPayload(data) || binding==null || !binding.valid(wall,elapsed,boot)) return false;
    long now=binding.serverNow(wall,elapsed,boot), expiry=date(data.get("expiresAt"));
    return data.get("registrationId").equals(binding.registrationId) &&
      data.get("bindingId").equals(binding.bindingId) &&
      Long.parseLong(data.get("registrationVersion"))==binding.version && expiry>now && expiry-now<=30000;
  }
  public static long remaining(Map<String,String> data,Binding binding,long wall,long elapsed,String boot) {
    if(!addressed(data,binding,wall,elapsed,boot)) return 0;
    return Math.max(0,Math.min(date(data.get("expiresAt")),binding.expiry)-binding.serverNow(wall,elapsed,boot));
  }
  public static Result receive(Map<String,String> data,Binding binding,LinkedHashMap<String,Seen> seen,
      long wall,long elapsed,String boot,boolean permission) {
    if(!permission || !addressed(data,binding,wall,elapsed,boot)) return new Result("ignore",Collections.emptyMap());
    long now=binding.serverNow(wall,elapsed,boot);
    Iterator<Map.Entry<String,Seen>> iterator=seen.entrySet().iterator();
    while(iterator.hasNext()) if(iterator.next().getValue().expires<=now) iterator.remove();
    String id=data.get("callId");long version=Long.parseLong(data.get("callVersion"));
    boolean terminal=data.get("type").equals("call.terminal");Seen previous=seen.get(id);
    if(previous!=null && (previous.terminal || previous.version>=version)) return new Result("ignore",Collections.emptyMap());
    // Refuse excess distinct calls instead of evicting live terminal tombstones.
    if(previous==null && seen.size()>=64) return new Result("ignore",Collections.emptyMap());
    seen.put(id,new Seen(version,date(data.get("expiresAt")),terminal));
    return new Result(terminal?"dismiss":"show",new HashMap<>(data));
  }
}

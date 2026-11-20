package com.nightshift.app;

import java.net.URI;
import java.text.ParsePosition;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

/** Fixed-host policy shared by the Android adapter and standalone JVM tests. */
public final class StaffCookiePolicy {
    public static final long MAX_LIFETIME_MS=1800000L;
    public static final long MAX_GENERATION=9007199254740991L;
    private StaffCookiePolicy() {}
    public static String origin(String value,boolean debug) {
        try {
            URI uri=new URI(value);String host=uri.getHost();int port=uri.getPort();
            if(!"https".equals(uri.getScheme())||host==null||!host.equals(host.toLowerCase(Locale.ROOT))
                ||host.endsWith(".")||uri.getRawUserInfo()!=null||uri.getRawQuery()!=null||uri.getRawFragment()!=null
                ||!"".equals(uri.getRawPath())||port==443||port==0||port>65535||!uri.toASCIIString().equals(value))throw new IllegalArgumentException();
            boolean loopback=host.equals("localhost")||host.endsWith(".localhost")||host.startsWith("127.")||host.equals("[::1]");
            if(loopback&&!debug)throw new IllegalArgumentException();
            return value;
        } catch(Exception error) {throw new IllegalArgumentException("Invalid staff origin");}
    }
    private static SimpleDateFormat format(String pattern) {
        SimpleDateFormat format=new SimpleDateFormat(pattern,Locale.US);format.setLenient(false);format.setTimeZone(TimeZone.getTimeZone("UTC"));return format;
    }
    public static String timestamp(long value) {return format("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").format(new Date(value));}
    public static long expiry(String value,long now) {
        if(value==null||!value.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z"))throw new IllegalArgumentException();
        ParsePosition position=new ParsePosition(0);Date date=format("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").parse(value,position);
        if(date==null||position.getIndex()!=value.length()||!timestamp(date.getTime()).equals(value)
            ||date.getTime()<=now||date.getTime()-now>MAX_LIFETIME_MS)throw new IllegalArgumentException();
        return date.getTime();
    }
    public static String install(String token,long expires,long now) {
        if(token==null||!token.matches("[a-f0-9]{64}")||expires<=now||expires-now>MAX_LIFETIME_MS)throw new IllegalArgumentException();
        long maxAge=(expires-now+999L)/1000L;
        return "__Host-nightshift_staff="+token+"; Path=/; Max-Age="+maxAge+"; Expires="
            +format("EEE, dd MMM yyyy HH:mm:ss 'GMT'").format(new Date(expires))+"; Secure; HttpOnly; SameSite=Strict";
    }
    public static String clear() {return "__Host-nightshift_staff=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly; SameSite=Strict";}
}

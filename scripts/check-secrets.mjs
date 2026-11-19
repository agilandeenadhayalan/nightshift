import { execFileSync } from 'node:child_process';
import { readFileSync, statSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// A small deterministic checkout guard; this complements provider-side secret scanning.
// Never print matches or credential values.
export function findings(path, text) {
  const result = [];
  if (/(^|\/)\.env(?:\..+)?$/.test(path) && !path.endsWith('.env.example')) result.push('environment file');
  if (/(?:\.sqlite(?:\d|-[a-z]+)?|\.db|\.jks|\.keystore|\.p12|\.pem)$/.test(path)) result.push('database or key material');
  if (/(?:google-services|service-account[^/]*)\.json$/.test(path)) result.push('provider configuration');
  const patterns = [
    ['private key', /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/],
    ['GitHub token', /\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,})\b/],
    ['AWS access key', /\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/],
    ['Google API key', /\bAIza[0-9A-Za-z_-]{35}\b/],
    ['Agora certificate assignment', /AGORA_APP_CERTIFICATE\s*[=:]\s*["']?[a-fA-F0-9]{32}\b/],
  ];
  for (const [label, pattern] of patterns) if (pattern.test(text)) result.push(label);
  return result;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const files = execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard'], { encoding: 'utf8' }).split('\0').filter(Boolean);
  let count = 0;
  for (const path of new Set(files)) {
    let text;
    try {
      if (statSync(path).size > 2_000_000) continue;
      text = readFileSync(path, 'utf8');
    } catch { continue; }
    for (const label of findings(path, text)) {
      console.error(`${path}: prohibited ${label}`);
      count++;
    }
  }
  if (count) process.exitCode = 1;
  else console.log(`Secret/file guard passed (${files.length} paths); no credential values emitted.`);
}

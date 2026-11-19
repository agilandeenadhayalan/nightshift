#!/usr/bin/env python3
"""Dry-run by default. Create private repo (optional), milestones, labels and issues.

Requires Python 3.10+ and authenticated GitHub CLI for --apply only.
Uses argument arrays and JSON stdin, never shell interpolation.
Remote writes are sequential, resumable and preserve existing issue content.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MARKER = re.compile(r'<!-- nightshift-id: (FA-\d{3}) -->')

class GhError(RuntimeError):
    pass

class GitHub:
    def command(self, argv, payload=None):
        result = subprocess.run(['gh', *argv], input=None if payload is None else json.dumps(payload),
                                text=True, encoding='utf-8', errors='replace',
                                capture_output=True, check=False)
        if result.returncode:
            raise GhError(result.stderr.strip()[:1500] or f'gh exited {result.returncode}')
        return result.stdout

    def api(self, path, method='GET', payload=None):
        argv = ['api', path, '--method', method]
        if payload is not None:
            argv += ['--input', '-']
        out = self.command(argv, payload)
        return json.loads(out) if out.strip() else None

    def pages(self, path):
        records = []
        join = '&' if '?' in path else '?'
        for page in range(1, 10001):
            batch = self.api(f'{path}{join}per_page=100&page={page}')
            if not isinstance(batch, list):
                raise GhError('Expected a paginated list; no mutation was attempted for this response.')
            records.extend(batch)
            if len(batch) < 100:
                return records
        raise GhError('Pagination safety limit reached; refusing to import from an incomplete inventory.')

def load_issues(path):
    rows = json.loads(Path(path).read_text())
    if not isinstance(rows, list) or not rows:
        raise ValueError('Issue file must contain a nonempty list.')
    ids = [row['id'] for row in rows]
    if len(ids) != len(set(ids)):
        raise ValueError('Duplicate local issue ID.')
    for row in rows:
        if not re.fullmatch(r'FA-\d{3}', row['id']):
            raise ValueError('Invalid local issue ID.')
        if MARKER.findall(row['body']) != [row['id']]:
            raise ValueError(f"Missing or ambiguous marker in {row['id']}")
        if any(dep not in ids or dep >= row['id'] for dep in row['dependencies']):
            raise ValueError(f"Invalid/cyclic dependency in {row['id']}")
    return rows

def inventory(issues):
    result = {}
    for issue in issues:
        if 'pull_request' in issue:
            continue
        for key in MARKER.findall(issue.get('body') or ''):
            if key in result:
                raise ValueError(f'Duplicate remote marker {key}; resolve manually before retrying.')
            result[key] = issue
    return result

def apply_import(client, repo, rows, mapping_path, create_repo=False):
    client.command(['auth', 'status'])
    try:
        metadata = client.api(f'repos/{repo}')
    except GhError as error:
        if not create_repo or '404' not in str(error):
            raise
        client.command(['repo', 'create', repo, '--private', '--description',
                        'Independent adult conversation platform — planning and implementation'])
        metadata = client.api(f'repos/{repo}')
    if not metadata.get('private'):
        raise ValueError('This importer expects a private repository. It will not publish this plan to a public repository.')
    existing = inventory(client.pages(f'repos/{repo}/issues?state=all'))
    remote_labels = {x['name'] for x in client.pages(f'repos/{repo}/labels')}
    remote_milestones = {x['title']: x['number'] for x in client.pages(f'repos/{repo}/milestones?state=all')}
    needed_labels = sorted({label for row in rows for label in row['labels']})
    for label in needed_labels:
        if label not in remote_labels:
            client.api(f'repos/{repo}/labels', 'POST', {'name': label, 'color': '346B73',
                      'description': 'Friend platform planning classification'})
            remote_labels.add(label)
    for title in dict.fromkeys(row['milestone'] for row in rows):
        if title not in remote_milestones:
            item = client.api(f'repos/{repo}/milestones', 'POST', {'title': title})
            remote_milestones[title] = item['number']
    mapping = {key: {'number': item['number'], 'url': item['html_url']}
               for key, item in existing.items()}
    created, skipped = [], []
    mapping_path = Path(mapping_path)
    def checkpoint():
        mapping_path.parent.mkdir(parents=True, exist_ok=True)
        temp = mapping_path.with_suffix(mapping_path.suffix + '.tmp')
        temp.write_text(json.dumps({'repository': repo, 'issues': mapping}, indent=2) + '\n')
        temp.replace(mapping_path)
    checkpoint()
    for row in rows:
        key = row['id']
        if key in existing:
            skipped.append(key)
            print(f"SKIP {key} -> #{existing[key]['number']} (existing content preserved)")
            continue
        body = row['body']
        linked = [f"{dep}: {mapping[dep]['url']}" for dep in row['dependencies'] if dep in mapping]
        if linked:
            body += '\n## Imported dependency links\n\n' + '\n'.join('- '+x for x in linked) + '\n'
        item = client.api(f'repos/{repo}/issues', 'POST', {
            'title': f"[{key}] {row['title']}", 'body': body,
            'labels': row['labels'], 'milestone': remote_milestones[row['milestone']]})
        mapping[key] = {'number': item['number'], 'url': item['html_url']}
        existing[key] = item
        created.append(key)
        checkpoint()
        print(f"CREATED {key} -> {item['html_url']}")
    verified = inventory(client.pages(f'repos/{repo}/issues?state=all'))
    missing = [row['id'] for row in rows if row['id'] not in verified]
    if missing:
        raise ValueError('Post-import verification missing: ' + ', '.join(missing))
    return {'created': len(created), 'skipped': len(skipped), 'verified': len(rows),
            'repository': repo, 'mapping': str(mapping_path)}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', required=True, help='Exact OWNER/REPOSITORY; use a new independent private repo.')
    parser.add_argument('--file', default=str(ROOT/'github/issues.json'))
    parser.add_argument('--phases', default='P0', help='Comma-separated P0..P7, or all; default P0 only.')
    parser.add_argument('--create-repo', action='store_true', help='Create missing repository as private with --apply.')
    parser.add_argument('--apply', action='store_true', help='Perform the displayed remote writes; default is dry-run.')
    parser.add_argument('--mapping', default=str(ROOT/'github/import_map.json'))
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+', args.repo):
        parser.error('--repo must be OWNER/REPOSITORY without a URL or shell syntax.')
    rows = load_issues(args.file)
    requested = {f'P{x}' for x in range(8)} if args.phases == 'all' else set(args.phases.split(','))
    if not requested or not requested <= {f'P{x}' for x in range(8)}:
        parser.error('--phases must be all or comma-separated P0..P7.')
    selected = [row for row in rows if row['phase'] in requested]
    print(f"{'APPLY' if args.apply else 'DRY RUN'}: {args.repo}, {len(selected)} issues, phases {','.join(sorted(requested))}")
    for row in selected:
        print(f"{row['id']} {row['title']}")
    if not args.apply:
        print('No network request, repository change, issue creation or local import-map write was made.')
        return 0
    try:
        print(json.dumps(apply_import(GitHub(), args.repo, selected, args.mapping, args.create_repo), indent=2))
        return 0
    except (GhError, ValueError, OSError) as error:
        print(f'Import stopped: {error}\nSome writes may have succeeded. Keep the mapping and rerun the same command; existing markers are preserved.', file=sys.stderr)
        return 1

if __name__ == '__main__':
    raise SystemExit(main())

# Import into GitHub

This package currently contains 64 local issue specifications. It has not created a repository or issues on GitHub. Choose a new independent **private** repository. Do not use an employer's repository for this product.

The importer uses your authenticated GitHub CLI, creates missing labels/milestones and issues sequentially, preserves existing issue content, and maps FA IDs to actual GitHub numbers. Markers make reruns safe after a partial failure. It checks open and closed issues, and refuses ambiguous duplicate markers. It does not push files, publish a website, charge a provider or change repository visibility.

Install Python 3.10+ and GitHub CLI, sign in yourself using `gh auth login`, and check the selected account with `gh auth status`. Never paste a GitHub token into an AI prompt. Replace `YOUR_OWNER` in commands with the intended personal/business account.

From the extracted pack directory, preview all issues without contacting GitHub:

```bash
python3 scripts/import_github_issues.py --repo YOUR_OWNER/nightshift --phases all
```

Create the repository as private if missing, and import the first 8 issues:

```bash
python3 scripts/import_github_issues.py --repo YOUR_OWNER/nightshift --create-repo --phases P0 --apply
```

Import all 64 when ready; existing imported IDs are skipped, including closed issues:

```bash
python3 scripts/import_github_issues.py --repo YOUR_OWNER/nightshift --phases all --apply
```

Or import the 56 core issues only:

```bash
python3 scripts/import_github_issues.py --repo YOUR_OWNER/nightshift --phases P0,P1,P2,P3,P4,P5,P6 --apply
```

Eight milestones are the phase containers, not eight additional epic issues. All-phase import therefore produces **64 issues**, not 72. After an interrupted run, retain `github/import_map.json`, inspect the reported failure, and rerun the same command. A provider timeout may mean the issue was created; the next run inventories markers before writing. Do not delete and recreate existing issues to make their numbers resemble FA IDs.

Dependency links are inserted when the dependency already has a mapping. Import in phase order for complete links. The FA dependency list remains authoritative even if a phase is imported out of order. The importer intentionally does not overwrite human edits to existing issue bodies or labels.

Use the repository prompt to copy this planning pack into the new repo, review files, commit and push. An issue importer alone does not commit documentation. The importer was verified with a fake GitHub service and a no-network dry run; live GitHub permissions and quotas remain to be tested in your chosen account.

# Repository and issue setup prompt

Replace the owner before use. Suggested repository name is technical and not a cleared consumer brand.

```text
Create the planning foundation for OWNER/nightshift as a private independent
GitHub repository. OWNER is: <INSERT_EXACT_OWNER>.

Inspect the current workspace and authenticated GitHub account first. If that exact
repo already exists, inspect it and preserve its content. Do not use any employer repo.
If OWNER is still a placeholder, ask for the owner rather than choosing an organization.

Copy the supplied plan, docs, prompts, github issue specifications and scripts into
the chosen repo. Add a README that describes the project as planning/implementation
work and does not claim a live working app. Do not commit credentials, test customer
data or provider secrets. Preserve actual Markdown newlines.

Run the importer in dry-run mode and validate the 64 local IDs, dependency graph,
8 phase milestones, and 56-core/8-expansion split. Then, within this explicit setup
request, create the private repository if needed and import only P0 (FA-001–008)
using scripts/import_github_issues.py with --apply. Reuse existing markers on retry.
Do not create duplicate epics in addition to the phase milestones.

Commit the planning foundation on a dedicated branch and push it; open a draft PR
where the existing repository supports that workflow. For a brand-new empty repo,
create its initial planning branch/commit without fabricating a comparison base.
Do not overwrite a populated default branch or merge implementation changes.

Return actual repository/branch/PR URLs as applicable, issue URLs, completed checks,
and anything that could not be created. Never say issues exist based only on local JSON.
```

To import all phases instead, explicitly change “only P0” to “P0–P7, all 64 issues”. The script defaults to P0 and dry-run for reviewability.

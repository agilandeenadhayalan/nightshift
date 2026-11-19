# NightShift
One app with two user modes, Customer and Listener. Customers find and call listeners. Listeners go online, answer calls and see earnings. Staff operations in the blueprint are internal.

## 1. Extract on Windows
Save NightShift.zip in Downloads. In PowerShell run:
```powershell
Expand-Archive "$HOME\Downloads\NightShift.zip" -DestinationPath "$HOME\Projects"
Set-Location "$HOME\Projects\NightShift"
```
The ZIP already contains the NightShift folder. Use a fresh destination if you already have local edits.

## 2. Run the existing audio app
Install Node.js 24 or later. From the NightShift folder:
```powershell
Push-Location audio
node --test
node server.mjs
```
Open the printed local URL in two Chromium tabs. Select Listener in one and go online. Select Customer in the other, call the listener, answer and allow microphone access. End the call and check both statements. Press Ctrl+C to stop, then run `Pop-Location`. This implementation supports one pair and test credits. The Android app and live integrations are build work.

## 3. Create the private GitHub repo and issues
Install Git, GitHub CLI and Python 3.10+. Run from the extracted NightShift root in PowerShell. Check that the account shown is your intended personal or business account. These commands assume a new repo.
```powershell
gh auth login
gh auth status
$owner = gh api user --jq .login
git init -b main
git add .
git commit -m "Start NightShift customer and listener app"
gh repo create "$owner/nightshift" --private --source=. --remote=origin --push
py -3 scripts/import_github_issues.py --repo "$owner/nightshift" --phases all
py -3 scripts/import_github_issues.py --repo "$owner/nightshift" --phases all --apply
gh issue list --repo "$owner/nightshift" --limit 100
```
The first importer command previews the backlog. The second creates the labels, eight milestones and 64 issues. Rerun the importer after interruption. If you already created the repo, verify the remote with git remote -v and resume at the importer step.

## 4. Build in Codex and review with Copilot
Open the nightshift GitHub repository in ChatGPT Codex and select main. Start with FA-001. Paste the actual GitHub issue body if your Codex environment cannot read it. Use this prompt:

> Read AGENTS.md, NightShift_Master_Plan.md and github/issues/FA-001.md. Complete FA-001 on its own branch. Use NightShift, Customer and Listener throughout. Preserve the working audio flow. Record unresolved business decisions for me. Run relevant checks, report their results, and prepare a pull request linking the actual GitHub issue number.

Open the same repo in VS Code with GitHub Copilot. Fetch and check out the Codex PR branch. Ask Copilot:

> Review this branch against the issue acceptance criteria. Check both user journeys and the test results. Flag missing evidence with file references. Suggest the smallest fix for each blocking finding.

Let Codex address review findings on that branch. Review and merge the PR, pull main locally, then select the next issue whose dependencies are complete. You can also have Copilot implement an issue locally and Codex review the pushed branch. Give each issue one implementation branch so both tools see the same changes.

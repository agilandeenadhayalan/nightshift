# NightShift planning pack

Prepared for Agilan Deenadhayalan on 28 October 2026. Read **NightShift_Master_Plan.md** first.

| File | Purpose |
|---|---|
| `NightShift_Master_Plan.md` | Recommendation, researched comparison, technology, architecture, billing, economics, phases and founder actions |
| `GitHub_Backlog.md` | Readable list and complete bodies for 64 issues, with 326 acceptance/verification checks |
| `docs/UI_Screen_Specification.md` | Customer, listener, admin and website screens and their states |
| `docs/Engineering_Contracts.md` | Repository layout, entities, APIs, call/money invariants and operations |
| `docs/Test_and_Launch_Plan.md` | Two-phone testing, failure cases and release criteria |
| `docs/Sources_and_Research.md` | Official links, evidence limits and information still needed |
| `prompts/00_Master_Build_Prompt.md` | Main implementation instruction for Cursor/Copilot/Codex |
| `prompts/01_Repository_and_Issues_Prompt.md` | Private repository and first-phase setup |
| `prompts/02_Single_Issue_Implementation.md` | Reusable implementation/PR prompt for any FA ID |
| `prompts/03_Two_Phone_Vertical_Slice.md` | First real audio demonstration |
| `prompts/04_UI_From_Screenshots.md` | Original UI design after screenshot handoff |
| `prompts/05_Money_and_Call_Review.md` | Financial and concurrency review |
| `prompts/06_Android_Release_Readiness.md` | Evidence-based release assessment |
| `github/issues.json` and `github/issues/` | Machine-readable and individual issue specifications |
| `github/IMPORT_GUIDE.md` | Dry-run and resumable GitHub import instructions |
| `scripts/import_github_issues.py` | Sequential private-repo milestone/label/issue importer |
| `scripts/unit_economics.py` | Editable illustrative contribution calculator; no live price fetch |

**Status:** planning completed; application not built or deployed; no live GitHub changes. Local FA IDs are not actual GitHub issue numbers. The 8 milestones contain 64 issues: 56 audio-MVP issues and 8 expansion issues.

First steps: read the plan, resolve FA-001–003 decisions, choose the independent private repo owner, preview P0 import, and start the two-phone audio spike. Screenshots can refine the UI afterward.

Example calculator commands:

```bash
python3 scripts/unit_economics.py
python3 scripts/unit_economics.py --channel-fee-rate 0.30
python3 scripts/unit_economics.py --rtc-usd-per-1000 3.99
```

The third command changes only media cost to the cited HD video list rate; it deliberately keeps the other assumptions unchanged to expose the need for separate video pricing. Results are scenarios, not competitor earnings or an approved tariff. Replace model tax, fees, FX, host compensation and costs with verified values before a business decision.

launch scenario: python3 scripts/unit_economics.py --minutes 60 --gross-per-minute 15 --host-hourly 500

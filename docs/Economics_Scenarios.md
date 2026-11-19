# Development economics scenarios

Related issue: [FA-003 / #3](https://github.com/agilandeenadhayalan/nightshift/issues/3).  
Model and proposed caps revised: 20 November 2026. Decision owner: Agilan Deenadhayalan, with the finance appointment and specialist review still pending.

The calculator now reproduces the historical ₹17 illustration and compares ₹500 per paid connected hour at ₹12, ₹15 and ₹20 per customer minute, using both 15% and 30% channel-fee assumptions. These are arithmetic scenarios, not approved NightShift prices, current provider quotations, tax conclusions or competitor profit estimates.

## Inputs and calculation

`scripts/unit_economics.py` uses Python `Decimal`, a 40-digit intermediate context and no binary floating-point calculations. Amounts are rounded half-up to two decimals only when formatting output. The model is:

`contribution = gross spend / (1 + assumed tax rate) − listener pay − assumed channel fee − RTC cost − variable reserve − amortized OTP cost`.

The channel fee applies to ex-tax spend as an explicit assumption. Each two-person 30-minute session consumes 60 RTC participant-minutes. Listener pay applies to paid connected time; time spent available without a call is not a paid-hour guarantee. `fixed monthly cost / positive contribution per session` gives the fractional break-even session count; round up to whole sessions for planning. Negative or zero contribution has no finite break-even volume in this model.

| Input | Matrix value | Basis / limitation |
|---|---:|---|
| Delivered session duration | 30 minutes | Comparison scenario |
| Participants | 2 | One Customer and one Listener |
| Customer gross price/minute | ₹12 / ₹15 / ₹20 | Requested comparison, tax-inclusive assumption |
| Listener pay/hour | ₹500 | Master-plan proposal; owner approval pending |
| Listener pay/session | ₹250 | 30 paid connected minutes; six minutes would earn ₹50 |
| Assumed tax rate | 18% | Planning assumption; actual tax treatment requires specialist review |
| Assumed channel fee | 15% / 30% | Applied to ex-tax spend; actual provider/channel terms may differ |
| Audio RTC per 1,000 participant-minutes | USD 0.99 | Historical master-plan input, not a current vendor quote |
| Video RTC per 1,000 participant-minutes | USD 3.99 | Historical master-plan input; video remains deferred |
| USD/INR | 88 | Planning FX assumption, not a live exchange rate |
| Variable support/fraud/refund reserve | 2% of gross | Illustrative reserve, not measured experience |
| OTP cost per successful login | ₹0.50 | Assumed all-in SMS expense divided by successful logins; include failed sends when replacing with actual data |
| Calls per successful login | 5 | Amortization assumption; ₹0.10 OTP expense per call |
| Fixed monthly cost | ₹20,000 | Comparison denominator, not spending authorization; excludes unspecified costs |

The historical transcript observation of ₹17 per 30 minutes is not the same as the proposed ₹500/hour plan. The reported competitor purchase of ₹1,999 for 10,000 coins is also not an approved rate input. Purchased coins, promotional credits and listener INR liability remain separate quantities.

## Reproducible scenario results

All contribution amounts below are per 30-minute session, before fixed costs and any omitted acquisition, salary, payment, compliance or operating expense. A positive value is not launch approval.

| Media | Customer ₹/minute | Assumed fee | Contribution | Whole sessions to cover ₹20,000 fixed cost | Assessment |
|---|---:|---:|---:|---:|---|
| Audio | 12 | 15% | −₹3.21 | No finite break-even | Reject unless a separately capped subsidy is approved |
| Audio | 12 | 30% | −₹48.97 | No finite break-even | Reject |
| Audio | 15 | 15% | ₹59.83 | 335 | Positive under assumptions |
| Audio | 15 | 30% | ₹2.62 | 7,628 | Very little contribution before omitted costs |
| Audio | 20 | 15% | ₹164.88 | 122 | Positive under assumptions |
| Audio | 20 | 30% | ₹88.61 | 226 | Positive under assumptions |
| Video | 12 | 15% | −₹19.05 | No finite break-even | Reject |
| Video | 12 | 30% | −₹64.81 | No finite break-even | Reject |
| Video | 15 | 15% | ₹43.99 | 455 | Positive under assumptions |
| Video | 15 | 30% | −₹13.22 | No finite break-even | Reject |
| Video | 20 | 15% | ₹149.04 | 135 | Positive under assumptions |
| Video | 20 | 30% | ₹72.77 | 275 | Positive under assumptions |

At ₹12/minute, both audio scenarios are negative with the proposed listener pay. At ₹15/minute and a 30% fee, audio leaves only ₹2.62 per half-hour in this model and video becomes negative. The calculator labels every negative case `REJECT_NEGATIVE_CONTRIBUTION`; no subsidy authorization exists in this repository.

The default historical illustration remains ₹60 gross spend for 30 minutes, ₹17 listener pay, ₹5.23 audio media cost and ₹19.79 contribution before fixed costs with a 15% assumed channel fee and no OTP allocation. This reproduces the earlier arithmetic without describing any competitor's margin.

## Commands

Run from the repository root on Windows (`python3` can replace `py -3` in WSL):

```powershell
py -3 scripts/unit_economics.py
py -3 scripts/unit_economics.py --scenario-matrix
py -3 scripts/unit_economics.py --minutes 30 --gross-per-minute 20 --host-hourly 500 --channel-fee-rate 0.30 --otp-cost-per-successful-login 0.50 --calls-per-successful-login 5 --fixed-monthly 20000
py -3 -m unittest discover -s tests -p test_unit_economics.py -v
```

The matrix intentionally has fixed documented assumptions. It rejects conflicting single-scenario flags instead of silently ignoring them. Use the single-scenario command for sensitivity analysis. A negative single-scenario calculation still prints its JSON evidence and exits with status 2 so automation cannot treat it as an accepted price.

## Proposed caps awaiting owner approval

These are proposed limits for the current development stage, with Agilan as the decision contact and 20 November 2026 as the revision date. They are not permission to spend or a claim that all controls already exist.

| Category | Current proposal | Required change before paid pilot |
|---|---|---|
| New monetary provider/cloud commitments | ₹0 without explicit owner budget; use already provisioned owner test accounts only | Approve a dated provider/cloud envelope, alerts and responsible account owner; ₹20,000/month is a model input only |
| Test credits | Fictional 10,000-coin fixture per seeded test account; no redeemable value | Define trial eligibility, cumulative issuance limit and abuse controls; fixture resets never apply to real wallets |
| Production free trial/subsidy | ₹0 authorized listener-pay liability | Approve who funds free calls, per-user/campaign cap and hard stop before enabling |
| Real-money top-ups | ₹0; disabled in this milestone | Approve pack catalogue, per-user/day limits, receipt/store route and refund rules |
| Real listener payouts | ₹0; disabled in this milestone | Approve minimum/maximum, daily batch cap, reviewer threshold, bank verification and reconciliation |
| Public concurrency | 0 until test/release gates; local proof uses one consenting pair | Set a capped pilot below measured capacity with support and listener coverage |

The 40-second test tariff is preserved for browser parity and is not an approved promotional budget. Free or subsidized real listener time can create costs even when customers pay zero. Production tariff, compensation, provider terms and all caps remain decisions D09, D12–D15 and D23 in `Decision_Register.md`.

## Verification and open acceptance

The automated suite verifies the historical example, six-minute listener calculation, OTP allocation, all 12 combinations, higher video media cost, negative-case rejection, invalid-input rejection, fixed-cost behavior and CLI rejection behavior. These checks validate arithmetic, not tax, store policy, listener economics at actual occupancy or provider pricing.

FA-003 remains open for the FA-002 policy dependency, approved commercial inputs/caps and owner finance sign-off. No live purchases, payments or provider calls are made by this script.

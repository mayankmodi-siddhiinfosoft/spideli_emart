# Spideli Finance – Customer App QA and Demo (15 October 2026)

| # | Deliverable | File |
|---|---|---|
| 1 | Complete finance testing report (110 scenarios, automated suites, data checks) | `01_FINANCE_TEST_REPORT.md` |
| 2 | Bug fix report (19 defects, all fixed and retested) | `02_BUG_FIX_REPORT.md` |
| 3 | Feature coverage summary (verified, not run by hand, blockers, unresolved) | `03_FEATURE_COVERAGE.md` |
| 4 | English narration script with scene timings | `04_NARRATION_SCRIPT.md` |
| 5 | Client demo video, 1920×1080 MP4, 8 min 23 s, English subtitles (burned in + track) | `Spideli_Finance_Customer_Demo.mp4` (not committed: shared directly) |
| 6 | Subtitles | `Spideli_Finance_Customer_Demo.srt` |

The demo uses real screen recordings of the customer app in a private test environment (fictional customers, test money). The narration is a computer-generated voice; there is no human presenter.

Test environment to reproduce everything: `finance/qa-env/` (`start.sh`, `seed.py`, `verify.py`, `admin.py`, `customer.mjs`) and the app built with `--dart-define=USE_FIREBASE_EMULATOR=true`.

---
name: billsplitz-review
description: Repo-specific review lenses for BillSplitz diffs. Use when reviewing any code change, diff, or PR in this repository — especially money math, parsing, persistence, or navigation-flow changes. Each lens is anchored to a real bug previously caught here.
---

Review the diff through every lens in [checklist.md](checklist.md). These are not
generic best practices — each lens exists because that exact failure happened in this
repo and survived a green test suite.

Rules of engagement:

- Run every lens against the diff; report only findings you can anchor to a concrete
  failure scenario (inputs/state → wrong money, lost data, or a false doc).
- Money-math and data-loss findings block merge; style points do not.
- If a lens produces a finding the tests would not have caught, say so explicitly and
  propose the missing test — the fix without the test is half the job (see the
  invariant-test and golden-corpus harnesses in `BillSplitzTests/`).
- Check `docs/decisions/` before flagging something as wrong that a record settles.

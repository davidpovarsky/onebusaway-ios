# CI and TestFlight Run Evidence

**Branch:** `fix/israel-extraction-and-repair-20261027`  
**Date:** 2026-10-27  

---

## 1. Prior Failed Runs (Baseline)

### Run 1: 40416553121
- **Workflow:** `israel-testflight.yml`
- **URL:** https://github.com/davidpovarsky/onebusaway-ios/actions/runs/40416553121
- **Failure Reason:** Expected SHA gate mismatch. Input was `b553da3122c7a4ecda7bbefceb178a994ef937a1` which did not exist as a commit. Checkout was `b553da316784542eb0e97bcadb1e45ea2dc369c9`.

### Run 2: 40416621526
- **Workflow:** `israel-testflight.yml`
- **URL:** https://github.com/davidpovarsky/onebusaway-ios/actions/runs/40416621526
- **Failure Reason:** Compilation failure during `Verify selected source branch with applicable Apple build/tests` (exit code 65).
- **Compiler Error:** `cannot find type 'ShapeCache' in scope` in `OBAWidget` target for `IsraelViewportRouteRepository.swift`.

---

## 2. New Verification Runs

*(To be populated after commit, push, and workflow dispatch)*

- **CI Workflow Run:** PENDING
- **TestFlight Workflow Run:** PENDING

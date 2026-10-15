# Upstream Pull Request & Merge Guide

This document is prepared for OneBusAway core maintainers and contributors reviewing the Israel MOT Transit Adapter pull request.

---

## 1. Pull Request Title & Description Template

### Title
`feat(region): Israel MOT Transit Adapter (Region 972) and Hebrew Localization`

### Summary
This PR introduces support for **Israel (Region 972)** via a clean, isolated adapter module (`IsraelMOT`) targeting the official Israeli Ministry of Transport (`api.bus.gov.il`) API, along with comprehensive **Hebrew (`he.lproj`) localization** across all app bundles and widgets.

### Architectural Highlights
1. **Isolated Module**: All Israel-specific DTOs, mappers, and networking logic reside in `IsraelMOT/`.
2. **Minimal Seams**: Only two extension points were introduced in upstream code:
   - `CoreApplication.dataLoader(for: region)` open hook.
   - Region 972 service injection in `Application.swift` and `TripPlannerSheetView.swift`.
3. **Zero Regression**: Puget Sound, Tampa, NYC, San Diego, and all other regions remain 100% untouched.
4. **Localization Coverage**: 1,309+ strings translated into Hebrew with full parameter specifier validation (`%@`, `%ld`, etc.) and RTL support.

---

## 2. Review Checklist for Maintainers

- [ ] **Regions Configuration**: Confirm Region 972 entry in `Apps/OneBusAway/Resources/regions.json` and `OBAWidget/Resources/regions.json`.
- [ ] **Project Generation**: Run `scripts/generate_project OneBusAway --no-watch` to verify clean XcodeGen synthesis.
- [ ] **Unit Tests**: Run `xcodebuild test -scheme App` to verify that both existing tests and `IsraelMOT` test suites pass.
- [ ] **Non-Israel Sanity Check**: Switch region in simulator to Puget Sound or Tampa and confirm live arrivals and map stops load identically to `main`.
- [ ] **Localization Strings**: Verify `he.lproj` strings files compile cleanly without formatting errors.

---

## 3. How to Test Region 972 Locally

1. Launch OneBusAway on an iOS 16+ Simulator.
2. Go to **Settings** -> **Region**.
3. Select **Israel (ישראל)** or set simulated GPS location to Jerusalem (`31.7891, 35.2046`) or Tel Aviv (`32.0853, 34.7818`).
4. View nearby bus stops on the map.
5. Tap any stop (e.g. stop `5997` on Sarei Yisrael St) to view live lines and arrival predictions.

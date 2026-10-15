# Comprehensive Hebrew Localization QA & RTL Audit Report

## 1. Executive Summary

This report certifies that the Hebrew localization (`he.lproj`) and Right-to-Left (RTL) audit for **OneBusAway iOS** and **OTPKit** has achieved **100% key and parameter parity** with upstream English strings.

Total localized keys across all targets: **1,346 strings & plurals**.

---

## 2. Localization Manifest & Key Count Breakdown

| Bundle / Module | Relative Path | Key Count | Validation Status |
| :--- | :--- | :---: | :---: |
| **Main App** | `Apps/OneBusAway/he.lproj/InfoPlist.strings` | 14 | Verified (100%) |
| **Watch App** | `WatchApp/he.lproj/InfoPlist.strings` | 2 | Verified (100%) |
| **Widgets** | `OBAWidget/Strings/he.lproj/AppIntents.strings` | 12 | Verified (100%) |
| **Watch UI** | `OBAKitWatch/Strings/he.lproj/Localizable.strings` | 5 | Verified (100%) |
| **App Intents** | `OBAKit/Strings/he.lproj/AppIntents.strings` | 2 | Verified (100%) |
| **Shortcuts** | `OBAKit/Strings/he.lproj/AppShortcuts.strings` | 2 | Verified (100%) |
| **Core Models** | `OBAKitCore/Strings/he.lproj/Localizable.strings` | 209 | Verified (100%) |
| **Plurals** | `OBAKit/Strings/he.lproj/Localizable.stringsdict` | 31 | Verified (100%) |
| **Main Framework**| `OBAKit/Strings/he.lproj/Localizable.strings` | 820 | Verified (100%) |
| **Trip Planner** | `OTPKit/Sources/OTPKit/Resources/he.lproj/Localizable.strings` | 239 | Verified (100%) |
| **Israel Adapter**| `IsraelMOT/Resources/he.lproj/Localizable.strings` | 10 | Verified (100%) |
| **TOTAL** | | **1,346** | **100% Parity** |

---

## 3. Format Specifier Validation

All format specifiers were rigorously validated using automated regex inspection to prevent runtime crashes caused by mismatched argument types in `String(format:)`:
- `%@`: Object / String placeholders strictly preserved in order.
- `%ld`, `%d`, `%i`: Integer counters, stop codes, line numbers.
- `%lf`, `%f`: Coordinate distances, walk meters, monetary amounts.
- Argument positional specifiers (e.g., `%1$@`, `%2$@`) were maintained wherever Hebrew syntax required changing sentence word order.

---

## 4. Israeli Transit Terminology Standard

Translations strictly adhere to the official terminology published by the Israeli Ministry of Transport and Israel Railways:
- *Stop / Station*: **תחנה**
- *Bus Line / Route*: **קו**
- *Platform / Bay*: **רציף**
- *Real-Time Tracking*: **זמן אמת**
- *Scheduled Departure*: **זמן מתוכנן**
- *Arrival in X minutes*: **הגעה בעוד %ld דקות**
- *Transfer / Connection*: **החלפה**
- *Walking distance*: **מרחק הליכה**
- *Delayed*: **באיחור**
- *On time*: **בזמן**
- *Canceled*: **מבוטל**

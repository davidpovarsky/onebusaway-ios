# OneBusAway Israel — TestFlight setup

Date: 2026-10-19. Internal beta only for iPad crash debugging.

## Verified state

- Original OneBusAway iOS bundle ID: `org.onebusaway.iphone`; original upstream team: `4ZQCMA634J`. Do not use either for this distribution.
- Existing release workflows target upstream or main and are left unchanged.
- Maktabah has a working signed TestFlight workflow. OneBusAway does not yet have the required repository-level signing configuration.
- The Apple Developer portal has not yet been inspected for registration of the new IDs.

## App Store Connect identity to register

| Field | Value |
| --- | --- |
| App main Bundle ID | `com.davidpovarsky.onebusawayisrael` |
| Widget extension Bundle ID | `com.davidpovarsky.onebusawayisrael.OBAWidget` |
| App Group | `group.com.davidpovarsky.onebusawayisrael` |
| App name | OneBusAway Israel (or a documented alternative if already taken) |
| SKU | `onebusaway-israel-ios` |
| Language | Hebrew |
| Product | iOS / iPadOS, internal TestFlight only |
| Development team | The *verified actual paid Apple Developer team* used by Maktabah |
| Marketing version | Inherited from current OneBusAway source; build number from GitHub Actions |

Register two explicit bundle identifiers; the Widget is a separate App ID.
Enable the same App Group for both. The main app also uses HealthKit and
production Push Notifications, which must be enabled on its App ID.
Do not enable the original upstream Associated Domains or Apple Pay merchant.
The watch app is excluded in the current workflow.

## Required repository configuration (names only)

GitHub Secrets for `davidpovarsky/onebusaway-ios`:

- `APPLE_TEAM_ID`
- `APPLE_CERTIFICATE_P12_B64`
- `APPLE_CERTIFICATE_PASSWORD`
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_P8`
- `ISRAEL_APP_PROVISIONING_PROFILE_B64`
- `ISRAEL_WIDGET_PROVISIONING_PROFILE_B64`

The first six names already exist in Maktabah, but their contents must not
be printed, committed, or copied via logs. The two Israel profile values
MUST be created specifically for these two app identifiers; Maktabah's
existing app profile must never be reused.

One GitHub repository variable is additionally required:
`ISRAEL_APP_STORE_CONNECT_APP_ID` — numeric Apple app record ID.
The beta workflow refuses to upload if any required value is missing.
The ASC private key is stored as base64, consistent with Maktabah's setup.

## Workflow and use on every branch (including main)

File: `.github/workflows/israel-testflight.yml`, registered on **main**.
This is a **manual-only** `workflow_dispatch` workflow. It can build `main`, any feature branch, or an exact commit through the optional `source_ref` input. Helper scripts are checked out from `main` so older source branches need not contain the TestFlight tooling. No automatic uploads or macOS runs on push.

1. In GitHub Actions, select the TestFlight workflow (registered in `main`). Choose `main` or any branch using the branch selector or supply `source_ref` to select a different source branch/tag/SHA. The workflow also works when the source branch predates its addition.
2. First run `operation=validate`. This runs the current tests and checks
   the generated Xcode project without signing or uploading to Apple.
3. Register IDs, group, capabilities, App Store Connect app and both
   App Store provisioning profiles through your authenticated account.
4. Install the eight required repository secrets and numeric repository variable.
5. Re-run with `operation=upload` and `expected_sha` set to the *full 40-character*
   SHA of the source checkout (`source_ref` if supplied; selected branch otherwise). **This includes `main`, if selected.** This signs the app and widget, exports a signed IPA,
   validates the package, and uploads the exact build to Apple.
6. Wait for Apple build processing to finish. Upload transport success does NOT
   mean the build is TestFlight-ready. Add your Apple account as an internal tester.
7. Install only from TestFlight, reproduce the map zoom-out crash, and retrieve
   the TestFlight crash report (or Jetsam diagnostic if memory termination).

The workflow retains matching dSYMs for 30 days as GitHub artifact. Record
the exact SHA, run URL, bundle ID, build number, device model and iPadOS version.
It intentionally **does not expose the signed IPA as a public GitHub artifact**.

Documentation: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
TestFlight crash feedback: https://developer.apple.com/testflight/

## Important scope and known risk

This work prepares a *diagnostic beta*, not an App Store release. The user's
map zoom-out crash remains unverified; the stop-catalog map loader can change
annotation cardinality drastically across zoom gates. The existing synthetic
fallback schedules (20-minute intervals / 90-second stop gaps) are a separate
known defect and must not be represented as authentic timetables.

Do not merge to main, change Apple signing certificates that other apps use,
submit App Store Review, expose credentials, or update Asana without an explicit
user request. Upstream OneBusAway project files remain untouched.

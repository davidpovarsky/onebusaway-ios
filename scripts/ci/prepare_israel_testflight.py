#!/usr/bin/env python3
"""Configure a *generated*, gitignored XcodeGen spec for private Israel TestFlight.

Usage (from repo root):
    scripts/generate_project OneBusAway --no-watch
    python3 scripts/ci/prepare_israel_testflight.py --mode validate
    xcodegen generate

The original Apps/OneBusAway/project.yml, upstream source, and repository
signing defaults are never edited. This script deliberately fails closed if
upstream changes the expected XcodeGen manifest shape.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import sys

EXPECTED_APP_ID = "org.onebusaway.iphone"
EXPECTED_WIDGET_ID = "org.onebusaway.iphone.OBAWidget"
EXPECTED_GROUP = "group.org.onebusaway.iphone"
EXPECTED_TEAM = "4ZQCMA634J"
DEFAULT_BUNDLE_ID = "com.davidpovarsky.onebusawayisrael"
DEFAULT_DISPLAY_NAME = "OneBusAway Israel"


def require_replace(text: str, before: str, after: str, count: int, label: str) -> str:
    actual = text.count(before)
    if actual != count:
        raise ValueError(f"{label}: expected {count} occurrences, found {actual}; check upstream spec")
    return text.replace(before, after)


def require_regex(text: str, expression: str, replacement: str, count: int, label: str) -> str:
    changed, actual = re.subn(expression, replacement, text, flags=re.MULTILINE)
    if actual != count:
        raise ValueError(f"{label}: expected {count} matches, found {actual}; check upstream spec")
    return changed


def yaml_string(value: str) -> str:
    # JSON strings are also valid YAML double-quoted scalars.
    return json.dumps(value, ensure_ascii=False)


def transform(text: str, *, bundle_id: str, team: str, app_group: str,
              app_profile: str, widget_profile: str, display_name: str,
              app_store_id: str | None) -> str:
    widget_id = f"{bundle_id}.OBAWidget"

    # XcodeGen's source of truth stays upstream; only ephemeral generated project.yml changes.
    text = require_replace(text, "bundleIdPrefix: org.onebusaway",
                           f"bundleIdPrefix: {bundle_id.rsplit('.', 1)[0]}",
                           1, "bundle prefix")
    text = require_replace(text, EXPECTED_GROUP, app_group, 4, "app-group identity")
    text = require_replace(text, "CFBundleDisplayName: OneBusAway",
                           f"CFBundleDisplayName: {yaml_string(display_name)}",
                           2, "app/widget display names")
    text = require_replace(text, "ExtensionURLScheme: onebusaway",
                           "ExtensionURLScheme: onebusawayisrael", 2, "widget URL scheme")
    text = require_replace(text, 'CFBundleURLSchemes: ["onebusaway"]',
                           'CFBundleURLSchemes: ["onebusawayisrael"]',
                           1, "app URL scheme")

    # Never ship someone else's associated domains or Apple Pay merchant identifier.
    text = require_regex(
        text, r"^        com\.apple\.developer\.associated-domains:\n(?:          - [^\n]*\n)+",
        "", 1, "third-party associated domains"
    )
    text = require_regex(
        text, r"^        com\.apple\.developer\.in-app-payments:\n(?:          - [^\n]*\n)+",
        "", 1, "third-party Apple Pay merchant"
    )

    # The shared push_config.yml says development. Store-distribution profiles use production.
    # Root spec overrides included spec without modifying upstream.
    text = require_replace(text, "        com.apple.developer.healthkit: true\n",
                           "        com.apple.developer.healthkit: true\n"
                           "        aps-environment: production\n",
                           1, "production APNs entitlement")

    # Hide upstream App Store review links until our own ASC app ID exists.
    if app_store_id:
        text = require_regex(text, r"^          AppStoreID: .*$",
                             f"          AppStoreID: {yaml_string(app_store_id)}",
                             1, "App Store Connect app ID")
    else:
        text = require_regex(text, r"^          AppStoreID: .*\n", "",
                             1, "remove upstream App Store ID")

    # Personal TestFlight should not prompt for donations to an unrelated upstream product.
    text = require_replace(text, "            Enabled: true\n",
                           "            Enabled: false\n", 1, "donations setting")

    text = require_regex(
        text, r"^        PRODUCT_BUNDLE_IDENTIFIER: " + re.escape(EXPECTED_WIDGET_ID) + r"$",
        "        PRODUCT_BUNDLE_IDENTIFIER: " + widget_id + "\n"
        "        CODE_SIGN_STYLE: Manual\n"
        "        CODE_SIGN_IDENTITY: Apple Distribution\n"
        f"        PROVISIONING_PROFILE_SPECIFIER: {yaml_string(widget_profile)}",
        1, "widget target identity"
    )
    text = require_regex(
        text, r"^        PRODUCT_BUNDLE_IDENTIFIER: " + re.escape(EXPECTED_APP_ID) + r"$",
        "        PRODUCT_BUNDLE_IDENTIFIER: " + bundle_id + "\n"
        "        CODE_SIGN_STYLE: Manual\n"
        "        CODE_SIGN_IDENTITY: Apple Distribution\n"
        f"        PROVISIONING_PROFILE_SPECIFIER: {yaml_string(app_profile)}",
        1, "main target identity"
    )
    text = require_regex(
        text, r"^        DEVELOPMENT_TEAM: " + re.escape(EXPECTED_TEAM) + r"$",
        f"        DEVELOPMENT_TEAM: {team}",
        2, "app and widget team identities"
    )

    if EXPECTED_GROUP in text or EXPECTED_TEAM in text:
        raise ValueError("Upstream Apple signing identifiers remained in generated spec")

    return text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("validate", "upload"), required=True)
    parser.add_argument("--manifest", type=Path, default=Path("project.yml"))
    args = parser.parse_args()

    bundle_id = os.environ.get("ISRAEL_APP_BUNDLE_ID", DEFAULT_BUNDLE_ID).strip()
    if not re.fullmatch(r"[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+){2,}", bundle_id):
        parser.error("ISRAEL_APP_BUNDLE_ID is not a valid reverse-DNS identifier")
    app_group = "group." + bundle_id
    name = DEFAULT_DISPLAY_NAME
    team = os.environ.get("APPLE_TEAM_ID", "").strip()
    if args.mode == "upload":
        if not re.fullmatch(r"[A-Z0-9]{10}", team):
            parser.error("APPLE_TEAM_ID must be the real 10-character paid team ID")
        app_profile = os.environ.get("ISRAEL_APP_PROFILE_NAME", "").strip()
        widget_profile = os.environ.get("ISRAEL_WIDGET_PROFILE_NAME", "").strip()
        if not app_profile or not widget_profile:
            parser.error("Two App Store provisioning profile names are required")
    else:
        team = "VALIDA1234"  # Dummy only; never used to sign or upload.
        app_profile = "VALIDATION_ONLY_MAIN"
        widget_profile = "VALIDATION_ONLY_WIDGET"

    app_store_id = os.environ.get("ISRAEL_APP_STORE_CONNECT_APP_ID", "").strip() or None
    if app_store_id and not app_store_id.isdigit():
        parser.error("ISRAEL_APP_STORE_CONNECT_APP_ID must be a numeric Apple app ID")

    manifest = args.manifest
    if not manifest.is_file():
        parser.error("Run scripts/generate_project OneBusAway --no-watch first")

    original = manifest.read_text(encoding="utf-8")
    transformed = transform(
        original, bundle_id=bundle_id, team=team, app_group=app_group,
        app_profile=app_profile, widget_profile=widget_profile,
        display_name=name, app_store_id=app_store_id
    )
    manifest.write_text(transformed, encoding="utf-8", newline="\n")
    print(f"Prepared ephemeral XcodeGen manifest for {bundle_id} ({args.mode});")
    print("source Apps/OneBusAway/project.yml unchanged.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(f"TestFlight identity preparation failed: {error}", file=sys.stderr)
        sys.exit(1)

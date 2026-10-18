#!/usr/bin/env python3
"""Validate the fully merged XcodeGen project spec before signing."""
from __future__ import annotations

import argparse
import json
import sys


def verify(spec: dict, team: str, bundle: str, mode: str) -> None:
    targets = spec["targets"]
    app = targets["App"]
    widget = targets["OBAWidget"]
    group = "group." + bundle

    for target, expected_id in ((app, bundle), (widget, bundle + ".OBAWidget")):
        base = target["settings"]["base"]
        if base.get("PRODUCT_BUNDLE_IDENTIFIER") != expected_id:
            raise ValueError("Wrong target bundle ID: " + expected_id)
        if base.get("DEVELOPMENT_TEAM") != team:
            raise ValueError("Target Apple Team ID mismatch")
        if base.get("CODE_SIGN_STYLE") != "Manual":
            raise ValueError("Missing manual signing configuration")
        if base.get("CODE_SIGN_IDENTITY") != "Apple Distribution":
            raise ValueError("Missing Apple Distribution identity")
        if not base.get("PROVISIONING_PROFILE_SPECIFIER"):
            raise ValueError("Missing target profile selection")
        ent = target["entitlements"]["properties"]
        if group not in ent.get("com.apple.security.application-groups", []):
            raise ValueError("App Group mismatch")
        if ent.get("com.apple.developer.associated-domains"):
            raise ValueError("Original OneBusAway associated domain leaked")
        if ent.get("com.apple.developer.in-app-payments"):
            raise ValueError("Original OneBusAway Apple Pay merchant leaked")

    app_ent = app["entitlements"]["properties"]
    if app_ent.get("aps-environment") != "production":
        raise ValueError("Production push entitlement not configured")
    if app_ent.get("com.apple.developer.healthkit") is not True:
        raise ValueError("Required HealthKit entitlement missing")
    info = app["info"]["properties"]
    if info["OBAKitConfig"]["AppGroup"] != group:
        raise ValueError("Runtime App Group configuration mismatch")
    if info["CFBundleDisplayName"] != "OneBusAway Israel":
        raise ValueError("Wrong beta display name")
    if info["OBAKitConfig"].get("AppStoreID") == "329380089":
        raise ValueError("Upstream App Store review link leaked")
    winfo = widget["info"]["properties"]
    if winfo["OBAKitConfig"]["AppGroup"] != group:
        raise ValueError("Widget runtime App Group mismatch")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", required=True)
    ap.add_argument("--team", required=True)
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--mode", choices=("validate", "upload"), required=True)
    args = ap.parse_args()
    with open(args.spec, encoding="utf-8") as f:
        spec = json.load(f)
    verify(spec, args.team, args.bundle, args.mode)
    print("Resolved XcodeGen identities, entitlements, App Groups and widget: PASS")


if __name__ == "__main__":
    try:
        main()
    except (KeyError, TypeError, ValueError, OSError) as e:
        print("TestFlight resolved spec validation FAILED: " + str(e), file=sys.stderr)
        sys.exit(1)

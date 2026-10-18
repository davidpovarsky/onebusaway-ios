# Profile metadata verification for the dedicated TestFlight workflow.
from __future__ import annotations

import plistlib
from pathlib import Path


def decode_profile(path: str) -> dict:
    return plistlib.loads(Path(path).read_bytes())

from datetime import datetime, timezone
import argparse
import re
import sys


def validate(path: str, team: str, bundle: str, group: str, is_main: bool) -> tuple[str, str]:
    profile = decode_profile(path)
    ent = profile.get("Entitlements", {})
    if profile.get("TeamIdentifier", [None])[0] != team:
        raise ValueError("Profile Apple Team ID mismatch")
    if ent.get("application-identifier") != team + "." + bundle:
        raise ValueError("Provisioned application identifier mismatch")
    if ent.get("com.apple.developer.team-identifier") != team:
        raise ValueError("Profile entitlement Team ID mismatch")
    if group not in ent.get("com.apple.security.application-groups", []):
        raise ValueError("Missing application group")
    if ent.get("get-task-allow") is not False:
        raise ValueError("Expected distribution profile, not development")
    if profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices"):
        raise ValueError("Expected App Store distribution profile")
    if is_main and ent.get("aps-environment") != "production":
        raise ValueError("Expected production APNs capability")
    if is_main and ent.get("com.apple.developer.healthkit") is not True:
        raise ValueError("Expected HealthKit capability")
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, datetime):
        raise ValueError("Profile expiration missing")
    expiry = expiry.replace(tzinfo=timezone.utc) if expiry.tzinfo is None else expiry
    if expiry <= datetime.now(timezone.utc):
        raise ValueError("Expired provisioning profile")
    name, uuid = profile.get("Name"), profile.get("UUID")
    if not isinstance(name, str) or not name or "\n" in name or "\r" in name:
        raise ValueError("Invalid profile name")
    if not isinstance(uuid, str) or not re.fullmatch(r"[0-9a-fA-F-]{36}", uuid):
        raise ValueError("Invalid profile UUID")
    return name, uuid


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--main", required=True)
    ap.add_argument("--widget", required=True)
    ap.add_argument("--team", required=True)
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--env-file", required=True)
    a = ap.parse_args()
    group = "group." + a.bundle
    app = validate(a.main, a.team, a.bundle, group, True)
    widget = validate(a.widget, a.team, a.bundle + ".OBAWidget", group, False)
    values = {
        "ISRAEL_APP_PROFILE_NAME": app[0],
        "ISRAEL_APP_PROFILE_UUID": app[1],
        "ISRAEL_WIDGET_PROFILE_NAME": widget[0],
        "ISRAEL_WIDGET_PROFILE_UUID": widget[1],
    }
    with open(a.env_file, "a", encoding="utf-8") as file:
        for key, value in values.items():
            file.write(key + "=" + value + "\n")
    print("App Store profiles validated: app and widget, exact team and group.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, IndexError, TypeError) as error:
        print("Invalid provisioning profile: " + str(error), file=sys.stderr)
        sys.exit(1)

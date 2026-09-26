#!/usr/bin/env python3
"""List Hyprland apps and terminate a selected process without shell expansion."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys


def process_identity(pid):
    getuid = getattr(os, "getuid", None)
    if getuid is None:
        raise OSError("Running-app management requires Linux")
    process = Path("/proc") / str(pid)
    if process.stat().st_uid != getuid():
        raise ValueError("The selected app belongs to another user")
    return process.joinpath("stat").read_text().rsplit(")", 1)[1].split()[19]


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if action == "list":
            result = subprocess.run(
                ["hyprctl", "clients", "-j"], capture_output=True, check=True, timeout=5,
            )
            apps = {}
            for client in json.loads(result.stdout):
                pid = client.get("pid", 0)
                if not isinstance(pid, int) or pid <= 1 or pid in apps:
                    continue
                try:
                    identity = process_identity(pid)
                except (OSError, ValueError):
                    continue
                name = client.get("class") or client.get("initialClass") or "App"
                title = client.get("title") or ""
                apps[pid] = {"pid": pid, "identity": identity,
                             "name": name, "title": title}
            print(json.dumps({"apps": sorted(apps.values(), key=lambda app: app["name"].lower()),
                              "error": ""}))
        elif (action == "terminate" and len(sys.argv) == 4
              and sys.argv[2].isdecimal() and sys.argv[3].isdecimal()):
            pid = int(sys.argv[2])
            if pid <= 1 or process_identity(pid) != sys.argv[3]:
                raise ValueError("The selected app is no longer running")
            os.kill(pid, signal.SIGTERM)
        else:
            raise ValueError("Invalid running-app action")
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr.decode("utf-8", errors="replace"), file=sys.stderr)
        if action == "list":
            print(json.dumps({"apps": [], "error": "Apps unavailable — see qs logs"}))
        else:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

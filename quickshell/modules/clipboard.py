#!/usr/bin/env python3
"""Bridge cliphist to the launcher without passing clipboard content through a shell."""
import json
import subprocess
import sys


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if action == "list":
            result = subprocess.run(["cliphist", "list"], capture_output=True)
            if result.returncode:
                detail = result.stderr.decode("utf-8", errors="replace").strip()
                if "opening db:" in detail and "no such file or directory" in detail.lower():
                    print(json.dumps({"entries": [], "error": ""}))
                    return 0
                result.check_returncode()
            entries = []
            for line in result.stdout.decode("utf-8", errors="replace").splitlines():
                identifier, separator, preview = line.partition("\t")
                if separator and identifier.isdecimal():
                    entries.append({"id": identifier, "preview": " ".join(preview.split()) or "Empty text"})
            print(json.dumps({"entries": entries, "error": ""}))
        elif action == "copy" and len(sys.argv) == 3 and sys.argv[2].isdecimal():
            result = subprocess.run(
                ["cliphist", "decode"], input=(sys.argv[2] + "\t\n").encode(),
                check=True, capture_output=True,
            )
            subprocess.run(["wl-copy"], input=result.stdout, check=True, capture_output=True)
        else:
            raise ValueError("Invalid clipboard action")
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        if isinstance(error, FileNotFoundError):
            message = f"Missing clipboard dependency: {error.filename}"
        elif isinstance(error, subprocess.CalledProcessError):
            detail = (error.stderr or b"").decode("utf-8", errors="replace").strip()
            message = f"Clipboard command failed: {error.cmd[0]} (exit {error.returncode})"
            if detail:
                message += ": " + " ".join(detail.split())
        else:
            message = str(error)
        if action == "list":
            print(json.dumps({"entries": [], "error": message}))
        else:
            print(message, file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

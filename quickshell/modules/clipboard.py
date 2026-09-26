#!/usr/bin/env python3
"""Bridge cliphist to the launcher without passing clipboard content through a shell."""
import json
import base64
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from io import BytesIO


def database_key():
    # `version` reports the effective db-path, including cliphist overrides.
    result = subprocess.run(["cliphist", "version"], capture_output=True)
    for line in result.stdout.decode("utf-8", errors="replace").splitlines():
        name, separator, value = line.partition("\t")
        if separator and name == "db-path":
            path = Path(value)
            try:
                stat = path.stat()
                return f"{path}:{stat.st_dev}:{stat.st_ino}"
            except OSError:
                return ""
    return ""


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if action == "list":
            result = subprocess.run(["cliphist", "list"], capture_output=True)
            if result.returncode:
                detail = result.stderr.decode("utf-8", errors="replace").strip()
                detail_lower = detail.lower()
                if "opening db:" in detail_lower and (
                    "please store something first" in detail_lower
                    or "no such file or directory" in detail_lower
                ):
                    print(json.dumps({"entries": [], "error": ""}))
                    return 0
                result.check_returncode()
            entries = []
            for line in result.stdout.decode("utf-8", errors="replace").splitlines():
                identifier, separator, preview = line.partition("\t")
                if separator and identifier.isdecimal():
                    entries.append({
                        "id": identifier,
                        "preview": " ".join(preview.split()) or "Empty text",
                        "isImage": bool(re.fullmatch(
                            r"\[\[ binary data .* (?:png|jpeg|jpg|gif|bmp|webp|tiff) \d+x\d+ \]\]",
                            preview.strip(), re.IGNORECASE,
                        )),
                    })
            print(json.dumps({"entries": entries, "error": "", "databaseKey": database_key()}))
        elif action == "preview" and len(sys.argv) == 3 and sys.argv[2].isdecimal():
            result = subprocess.run(
                ["cliphist", "decode"], input=(sys.argv[2] + "\t\n").encode(),
                check=True, capture_output=True,
            )
            from PIL import Image
            with Image.open(BytesIO(result.stdout)) as image:
                image.draft("RGB", (256, 144))
                image.thumbnail((128, 72), Image.Resampling.BILINEAR)
                thumbnail = image.convert("RGBA")
                output = BytesIO()
                thumbnail.save(output, format="PNG")
            print(json.dumps({"source": "data:image/png;base64,"
                              + base64.b64encode(output.getvalue()).decode("ascii")}))
        elif action == "copy" and len(sys.argv) == 3 and sys.argv[2].isdecimal():
            result = subprocess.run(
                ["cliphist", "decode"], input=(sys.argv[2] + "\t\n").encode(),
                check=True, capture_output=True,
            )
            with tempfile.TemporaryFile() as error_output:
                copied = subprocess.run(
                    ["wl-copy"], input=result.stdout,
                    stdout=subprocess.DEVNULL, stderr=error_output,
                )
                if copied.returncode:
                    error_output.seek(0)
                    raise subprocess.CalledProcessError(
                        copied.returncode, copied.args, stderr=error_output.read(),
                    )
        else:
            raise ValueError("Invalid clipboard action")
    except (OSError, ImportError, subprocess.CalledProcessError, ValueError) as error:
        if isinstance(error, FileNotFoundError):
            message = f"Missing clipboard dependency: {error.filename}"
        elif isinstance(error, subprocess.CalledProcessError):
            detail = (error.stderr or b"").decode("utf-8", errors="replace").strip()
            message = f"Clipboard command failed: {error.cmd[0]} (exit {error.returncode})"
            if detail:
                message += ":\n" + detail
        else:
            message = str(error)
        if action == "list":
            print(message, file=sys.stderr)
            print(json.dumps({"entries": [], "error": "History unavailable — see qs logs"}))
        else:
            print(message, file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

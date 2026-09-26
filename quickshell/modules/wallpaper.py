#!/usr/bin/env python3
"""Restore or atomically save the selected wallpaper."""
import json
from pathlib import Path
import os
import sys
import tempfile


def main():
    cache = Path.home() / ".cache"
    selection = cache / "quickshell_wallpaper.txt"
    try:
        if len(sys.argv) == 3 and sys.argv[1] == "select":
            path = Path(sys.argv[2]).expanduser().resolve()
            if not path.is_file():
                raise ValueError("Wallpaper file does not exist")
            cache.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(mode="w", dir=cache, delete=False) as file:
                file.write(str(path))
                temporary = file.name
            os.replace(temporary, selection)
        elif len(sys.argv) == 2 and sys.argv[1] == "restore":
            try:
                saved = selection.read_text().strip()
            except OSError:
                saved = ""
            candidates = [Path(saved)] if saved else []
            candidates.append(Path.home() / "Pictures/Wallpapers/wallpaper.png")
            path = next((candidate for candidate in candidates if candidate.is_file()), None)
            if path:
                path = path.resolve()
        else:
            raise ValueError("Invalid wallpaper action")
        print(json.dumps({"path": str(path) if path else "", "source": path.as_uri() if path else "",
                          "request": sys.argv[2] if sys.argv[1] == "select" else ""}))
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

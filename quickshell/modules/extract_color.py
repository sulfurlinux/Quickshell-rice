#!/usr/bin/env python3
import json
import os
import sys
import tempfile


def get_dominant_color(img_path):
    if img_path.startswith("file://"):
        img_path = img_path[7:]

    if not os.path.exists(img_path):
        return "#cba6f7"

    try:
        from PIL import Image, ImageStat

        with Image.open(img_path) as image:
            image.draft("RGB", (100, 100))
            image.thumbnail((50, 50), Image.Resampling.BILINEAR)
            image = image.convert("RGB")
            means = ImageStat.Stat(image).mean

        r, g, b = (int(channel) for channel in means)

        brightness = (r * 299 + g * 587 + b * 114) / 1000

        if brightness < 90:
            factor = 120 / max(brightness, 10)
            r = min(int(r * factor), 240)
            g = min(int(g * factor), 240)
            b = min(int(b * factor), 250)

        return f"#{r:02x}{g:02x}{b:02x}"

    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        return "#cba6f7"


def atomic_write(path, content):
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=os.path.dirname(path), delete=False) as file:
        file.write(content)
        temporary = file.name
    os.replace(temporary, path)


def main():
    if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] != "--selected"):
        print(f"Usage: {sys.argv[0]} <image-path>", file=sys.stderr)
        return 1

    img_path = sys.argv[1]
    clean_path = img_path[7:] if img_path.startswith("file://") else img_path
    accent = get_dominant_color(clean_path)

    cache_dir = os.path.expanduser("~/.cache")
    os.makedirs(cache_dir, exist_ok=True)

    if len(sys.argv) == 3:
        with open(os.path.join(cache_dir, "quickshell_wallpaper.txt"), encoding="utf-8") as file:
            if file.read().strip() != clean_path:
                return 0

    theme_data = {
        "background": "#1e1e2e",
        "surface": "#313244",
        "text": "#cdd6f4",
        "subtext": "#a6adc8",
        "accent": accent,
    }

    # Save the theme for Quickshell.
    theme_file = os.path.join(cache_dir, "quickshell_theme.json")
    atomic_write(theme_file, json.dumps(theme_data))

    # Save variables consumed by hyprlock.conf.
    hyprlock_conf = os.path.join(cache_dir, "hyprlock_colors.conf")
    atomic_write(hyprlock_conf, f"$accent = rgb({accent.lstrip('#')})\n"
                 "$background = rgb(1e1e2e)\n$text = rgb(cdd6f4)\n")

    # Keep the wallpaper path separate from hyprlock.conf.
    # Write it atomically so hyprlock never sees a partially written file.
    wallpaper_conf = os.path.join(cache_dir, "hyprlock_wallpaper.conf")
    atomic_write(wallpaper_conf, f"$wallpaper = {clean_path}\n")

    print(json.dumps({"wallpaper": clean_path, "theme": theme_data}))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

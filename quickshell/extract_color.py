#!/usr/bin/env python3
import json
import os
import sys


def get_dominant_color(img_path):
    if img_path.startswith("file://"):
        img_path = img_path[7:]

    if not os.path.exists(img_path):
        return "#cba6f7"

    try:
        from PIL import Image

        with Image.open(img_path) as image:
            image = image.convert("RGB")
            image = image.resize((50, 50), Image.Resampling.LANCZOS)
            pixels = list(image.getdata())

        if not pixels:
            return "#cba6f7"

        total_r = sum(pixel[0] for pixel in pixels)
        total_g = sum(pixel[1] for pixel in pixels)
        total_b = sum(pixel[2] for pixel in pixels)
        count = len(pixels)

        r = total_r // count
        g = total_g // count
        b = total_b // count

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


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <image-path>", file=sys.stderr)
        return 1

    img_path = sys.argv[1]
    clean_path = img_path[7:] if img_path.startswith("file://") else img_path
    accent = get_dominant_color(clean_path)

    cache_dir = os.path.expanduser("~/.cache")
    os.makedirs(cache_dir, exist_ok=True)

    theme_data = {
        "background": "#1e1e2e",
        "surface": "#313244",
        "text": "#cdd6f4",
        "subtext": "#a6adc8",
        "accent": accent,
    }

    # Save the theme for Quickshell.
    theme_file = os.path.join(cache_dir, "quickshell_theme.json")
    with open(theme_file, "w", encoding="utf-8") as file:
        json.dump(theme_data, file)

    # Save variables consumed by hyprlock.conf.
    hyprlock_conf = os.path.join(cache_dir, "hyprlock_colors.conf")
    with open(hyprlock_conf, "w", encoding="utf-8") as file:
        file.write(f"$accent = rgb({accent.lstrip('#')})\n")
        file.write("$background = rgb(1e1e2e)\n")
        file.write("$text = rgb(cdd6f4)\n")

    # Keep the background path in the actual hyprlock configuration in sync.
    hyprlock_main_conf = os.path.expanduser("~/.config/hypr/hyprlock.conf")
    if os.path.exists(hyprlock_main_conf):
        with open(hyprlock_main_conf, "r", encoding="utf-8") as file:
            lines = file.readlines()

        with open(hyprlock_main_conf, "w", encoding="utf-8") as file:
            for line in lines:
                if line.strip().startswith("path ="):
                    file.write(f"    path = {clean_path}\n")
                else:
                    file.write(line)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

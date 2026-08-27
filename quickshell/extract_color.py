#!/usr/bin/env python3
import os
import json
import sys

def get_dominant_color(img_path):
    if img_path.startswith("file://"):
        img_path = img_path[7:]

    if not os.path.exists(img_path):
        return "#cba6f7"

    try:
        from PIL import Image
        img = Image.open(img_path)
        img = img.convert('RGB')

        img = img.resize((50, 50), Image.Resampling.LANCZOS)
        pixels = list(img.getdata())

        total_r = sum(p[0] for p in pixels)
        total_g = sum(p[1] for p in pixels)
        total_b = sum(p[2] for p in pixels)
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

        return '#{:02x}{:02x}{:02x}'.format(r, g, b)

    except Exception as e:
        print(f"Fehler: {e}")

    return "#cba6f7"

if __name__ == "__main__":
    if len(sys.argv) > 1:
        img_path = sys.argv[1]
        if img_path.startswith("file://"):
            clean_path = img_path[7:]
        else:
            clean_path = img_path

        accent = get_dominant_color(clean_path)

        cache_dir = os.path.expanduser('~/.cache')
        theme_data = {
            "background": "#1e1e2e",
            "surface": "#313244",
            "text": "#cdd6f4",
            "subtext": "#a6adc8",
            "accent": accent
        }

        # 1. Save JSON theme for Quickshell
        theme_file = os.path.join(cache_dir, 'quickshell_theme.json')
        with open(theme_file, 'w') as f:
            json.dump(theme_data, f)

        # 2. Save color file for Hyprlock
        hyprlock_conf = os.path.join(cache_dir, 'hyprlock_colors.conf')
        with open(hyprlock_conf, 'w') as f:
            f.write(f"$accent = rgb({accent.lstrip('#')})\n")
            f.write(f"$background = rgb(1e1e2e)\n")
            f.write(f"$text = rgb(cdd6f4)\n")

        # 3. Write the background path into the hyprlock.conf
        hyprlock_main_conf = os.path.expanduser('~/.config/hypr/hyprlock.conf')
        if os.path.exists(hyprlock_main_conf):
            with open(hyprlock_main_conf, 'r') as f:
                lines = f.readlines()

            with open(hyprlock_main_conf, 'w') as f:
                for line in lines:
                    if line.strip().startswith("path ="):
                        f.write(f"    path = {clean_path}\n")
                    else:
                        f.write(line)

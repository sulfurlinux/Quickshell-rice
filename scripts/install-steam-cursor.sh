#!/usr/bin/env bash
set -euo pipefail

theme_name="BreezeX-RosePine-Linux"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
destination="$data_home/icons/default"
theme_source=""

for icon_dir in /usr/share/icons "$data_home/icons" "$HOME/.icons"; do
    if [[ -d "$icon_dir/$theme_name/cursors" ]]; then
        theme_source="$icon_dir/$theme_name"
        break
    fi
done

if [[ -z "$theme_source" ]]; then
    printf 'Could not find %s. Install rose-pine-cursor first.\n' "$theme_name" >&2
    exit 1
fi

if [[ -e "$destination" ]]; then
    printf '%s already exists; move it aside before installing the Steam fallback theme.\n' "$destination" >&2
    exit 1
fi

mkdir -p "$(dirname "$destination")"
cp -rL "$theme_source" "$destination"
printf 'Installed %s as Steam\x27s default Xcursor theme at %s. Restart Steam to apply it.\n' \
    "$theme_name" "$destination"

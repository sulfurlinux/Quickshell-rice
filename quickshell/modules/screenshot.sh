#!/usr/bin/env bash
set -euo pipefail
umask 077

target=${1:-}
action=${2:-}
destination=${3:-"$HOME/Pictures/Screenshots"}

case "$target" in area|screen) ;; *) echo 'Invalid screenshot target' >&2; exit 1 ;; esac
case "$action" in save|copy|copysave) ;; *) echo 'Invalid screenshot action' >&2; exit 1 ;; esac

required=(grim flock mktemp)
[[ $target == area ]] && required+=(hyprpicker slurp)
[[ $action != save ]] && required+=(wl-copy)
for tool in "${required[@]}"; do
    command -v "$tool" >/dev/null || { echo "Missing dependency: $tool" >&2; exit 1; }
done

runtime=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}
exec 9>"$runtime/quickshell-screenshot-${UID}.lock"
flock -n 9 || exit 0

picker_pid=
selector_pid=
workdir=
cleanup() {
    if [[ -n $selector_pid ]]; then
        kill "$selector_pid" 2>/dev/null || true
        wait "$selector_pid" 2>/dev/null || true
    fi
    if [[ -n $picker_pid ]]; then
        kill "$picker_pid" 2>/dev/null || true
        wait "$picker_pid" 2>/dev/null || true
    fi
    [[ -z $workdir ]] || rm -rf -- "$workdir"
    return 0
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP
workdir=$(mktemp -d "$runtime/quickshell-screenshot.XXXXXX")

geometry=()
if [[ $target == area ]]; then
    hyprpicker -r -z >"$workdir/picker.log" 2>&1 9>&- &
    picker_pid=$!
    sleep 0.2
    if ! kill -0 "$picker_pid" 2>/dev/null; then
        cat "$workdir/picker.log" >&2
        echo 'Could not freeze displays with hyprpicker' >&2
        exit 1
    fi

    slurp -b 00000066 -s 00000000 -c cba6f7ff >"$workdir/geometry" 9>&- &
    selector_pid=$!
    if wait "$selector_pid"; then
        selector_pid=
    else
        selector_pid=
        exit 130
    fi
    selection=$(cat "$workdir/geometry")
    [[ -n $selection ]] || exit 130
    geometry=(-g "$selection")
fi

# Capture once: the saved file and clipboard must contain identical pixels.
grim "${geometry[@]}" "$workdir/capture.png" 9>&-
if [[ -n $picker_pid ]]; then
    kill "$picker_pid" 2>/dev/null || true
    wait "$picker_pid" 2>/dev/null || true
    picker_pid=
fi

image="$workdir/capture.png"
if [[ $action != copy ]]; then
    mkdir -p -- "$destination"
    image="$destination/Screenshot_$(date +%Y-%m-%d_%H-%M-%S_%N).png"
    mv -- "$workdir/capture.png" "$image"
fi
if [[ $action != save ]]; then
    wl-copy --type image/png <"$image" 9>&-
fi

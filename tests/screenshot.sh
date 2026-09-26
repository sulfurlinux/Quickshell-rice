#!/usr/bin/env bash
# Run with: bash tests/screenshot.sh
# Mock Wayland tools to test capture sequencing and cleanup without a compositor.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/runtime"
export XDG_RUNTIME_DIR="$fixture/runtime"
export SCREENSHOT_TEST_DIR="$fixture"
export PATH="$fixture/bin:$PATH"

cat >"$fixture/mock" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$(basename "$0")" in
    flock) exit "${LOCK_STATUS:-0}" ;;
    hyprpicker)
        [[ ${PICKER_FAIL:-0} == 0 ]] || exit 1
        [[ $* == '-r -z' ]]
        touch "$SCREENSHOT_TEST_DIR/frozen"
        trap 'rm -f "$SCREENSHOT_TEST_DIR/frozen"; exit 0' TERM INT
        while :; do sleep 0.05; done
        ;;
    slurp)
        [[ -f "$SCREENSHOT_TEST_DIR/frozen" ]]
        touch "$SCREENSHOT_TEST_DIR/selecting"
        if [[ ${HOLD_SELECTION:-0} == 1 ]]; then
            while :; do sleep 0.05; done
        fi
        [[ ${CANCEL:-0} == 0 ]] || exit 1
        [[ ${EMPTY:-0} == 0 ]] || exit 0
        printf '%s\n' '-1920,0 320x240'
        ;;
    grim)
        echo capture >>"$SCREENSHOT_TEST_DIR/captures"
        if [[ ${EXPECT_AREA:-0} == 1 ]]; then
            [[ -f "$SCREENSHOT_TEST_DIR/frozen" ]]
            [[ $1 == '-g' && $2 == '-1920,0 320x240' ]]
        else
            [[ $# == 1 ]]
        fi
        [[ ${GRIM_FAIL:-0} == 0 ]] || exit 1
        printf 'test-image' >"${@: -1}"
        ;;
    wl-copy)
        [[ ! -f "$SCREENSHOT_TEST_DIR/frozen" ]]
        [[ $* == '--type image/png' ]]
        [[ ${COPY_FAIL:-0} == 0 ]] || exit 1
        cat >"$SCREENSHOT_TEST_DIR/clipboard"
        ;;
esac
MOCK
for tool in flock hyprpicker slurp grim wl-copy; do
    cp "$fixture/mock" "$fixture/bin/$tool"
    chmod +x "$fixture/bin/$tool"
done

assert_clean() {
    [[ ! -f "$fixture/frozen" ]]
    [[ -z $(find "$fixture/runtime" -maxdepth 1 -type d -name 'quickshell-screenshot.*' -print) ]]
}

for target in area screen; do
    for action in save copy copysave; do
        rm -f "$fixture/captures" "$fixture/clipboard"
        destination="$fixture/output $target $action"
        EXPECT_AREA=$([[ $target == area ]] && echo 1 || echo 0) \
            bash "$repo/quickshell/modules/screenshot.sh" "$target" "$action" "$destination"
        [[ $(wc -l <"$fixture/captures") == 1 ]]
        if [[ $action == copy ]]; then
            [[ ! -d "$destination" ]]
        else
            files=("$destination"/*.png)
            [[ ${#files[@]} == 1 && $(cat "${files[0]}") == test-image ]]
        fi
        if [[ $action == save ]]; then
            [[ ! -f "$fixture/clipboard" ]]
        else
            [[ $(cat "$fixture/clipboard") == test-image ]]
        fi
        assert_clean
    done
done
echo 'PASS: all five IPC modes plus screen copysave; one capture, correct geometry, identical clipboard/file'

for behavior in CANCEL EMPTY PICKER_FAIL GRIM_FAIL COPY_FAIL; do
    rm -f "$fixture/captures" "$fixture/clipboard"
    set +e
    env "$behavior=1" EXPECT_AREA=1 bash "$repo/quickshell/modules/screenshot.sh" area copy "$fixture/unused"
    status=$?
    set -e
    [[ $status != 0 ]]
    [[ ! -f "$fixture/clipboard" && ! -d "$fixture/unused" ]]
    if [[ $behavior == CANCEL || $behavior == EMPTY || $behavior == PICKER_FAIL ]]; then
        [[ ! -f "$fixture/captures" ]]
    fi
    assert_clean
done
echo 'PASS: cancel, empty selection, freeze failure, capture failure, clipboard failure clean up'

rm -f "$fixture/captures"
LOCK_STATUS=1 bash "$repo/quickshell/modules/screenshot.sh" area save "$fixture/unused"
[[ ! -f "$fixture/captures" && ! -f "$fixture/frozen" ]]
assert_clean
echo 'PASS: occupied lock does not start a selector or frozen backdrop'

rm -f "$fixture/selecting"
HOLD_SELECTION=1 bash "$repo/quickshell/modules/screenshot.sh" area copy &
capture_pid=$!
for ((attempt = 0; attempt < 100; attempt++)); do
    [[ ! -f "$fixture/selecting" ]] || break
    sleep 0.05
done
[[ -f "$fixture/selecting" ]]
kill -TERM "$capture_pid"
set +e
wait "$capture_pid"
status=$?
set -e
[[ $status == 130 ]]
assert_clean
echo 'PASS: termination during selection removes the frozen backdrop and temporary files'

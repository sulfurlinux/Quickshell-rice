-- Start Quickshell when Hyprland starts.
hl.on("hyprland.start", function()
    hl.exec_cmd("qs")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("xrandr --output DP-1 --primary")
end)

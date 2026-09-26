-- Start Quickshell when Hyprland starts.
hl.on("hyprland.start", function()
    hl.exec_cmd("qs")
    hl.exec_cmd("xrandr --output DP-1 --primary")
end)

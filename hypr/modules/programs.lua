-- Applications used by the Hyprland configuration.
-- qs -c <dein-config-name> ipc call screenshot select
-- qs -c <dein-config-name> ipc call screenshot full
-- qs -c <dein-config-name> ipc call screenshot copy
-- qs -c <dein-config-name> ipc call screenshot copyFull
return {
    browser = "firefox",
    terminal = "ghostty",
    fileManager = "nautilus",
    menu = "quickshell ipc call launcher toggle",
}

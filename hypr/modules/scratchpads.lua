-- Scratchpad window rules and keybindings.

hl.window_rule({
    match = { class = "spotify" },
    workspace = "special:spotify"
})

hl.window_rule({
    match = { class = "discord" },
    workspace = "special:discord"
})

hl.bind("SUPER + M", hl.dsp.workspace.toggle_special("spotify"))
hl.bind("SUPER + D", hl.dsp.workspace.toggle_special("discord"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("spotify"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("discord"))

-- Restore the wallpaper palette after the static appearance defaults.
local colors = { "cba6f7", "d8bcf9", "675a85", "18131d" }
local home = os.getenv("HOME")
local file = home and io.open(home .. "/.cache/hyprland_colors.txt", "r")
if file then
    local saved = {}
    for line in file:lines() do
        if #line == 6 and line:match("^[0-9a-fA-F]+$") then
            saved[#saved + 1] = line
        else
            saved = {}
            break
        end
    end
    file:close()
    if #saved == 4 then colors = saved end
end

hl.config({
    general = {
        col = {
            active_border = {
                colors = { "rgba(" .. colors[1] .. "ee)", "rgba(" .. colors[2] .. "ee)" },
                angle = 45,
            },
            inactive_border = "rgba(" .. colors[3] .. "aa)",
        },
    },
    decoration = {
        shadow = { color = "rgba(" .. colors[4] .. "ee)" },
    },
})

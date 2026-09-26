-- Edit this table to assign workspace numbers to displays.
-- Find display names with: hyprctl monitors
-- Each number must appear once; default must be one of that display's numbers.
-- Set persistent = true to keep empty workspaces visible in the bar.
local displays = {
    {
        monitor = "DP-1",
        workspaces = { 1, 2, 3, 4, 5 },
        default = 1,
        persistent = false,
    },
    {
        monitor = "HDMI-A-1",
        workspaces = { 6, 7, 8, 9, 10 },
        default = 6,
        persistent = false,
    },
}

-- Validate the whole table before registering rules.
local assignedWorkspaces = {}
local assignedMonitors = {}
for _, display in ipairs(displays) do
    assert(type(display.monitor) == "string" and display.monitor ~= "",
        "workspaces.lua: each display needs a monitor name")
    assert(not assignedMonitors[display.monitor],
        "workspaces.lua: duplicate monitor " .. display.monitor)
    assignedMonitors[display.monitor] = true

    local hasDefault = false
    for _, number in ipairs(display.workspaces) do
        assert(type(number) == "number" and number > 0 and number % 1 == 0,
            "workspaces.lua: workspace numbers must be positive integers")
        assert(not assignedWorkspaces[number],
            "workspaces.lua: workspace " .. number .. " is assigned more than once")
        assignedWorkspaces[number] = true
        if number == display.default then hasDefault = true end
    end
    assert(hasDefault,
        "workspaces.lua: default must be listed in workspaces for " .. display.monitor)
end

for _, display in ipairs(displays) do
    for _, number in ipairs(display.workspaces) do
        hl.workspace_rule({
            workspace = tostring(number),
            monitor = display.monitor,
            default = number == display.default,
            persistent = display.persistent == true,
        })
    end
end

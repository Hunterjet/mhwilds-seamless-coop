-- Seamless Co-op for Monster Hunter Wilds - REFramework autorun entry.
-- https://github.com/Hunterjet/mhwilds-seamless-coop (MIT). Modules live in autorun/seamless_coop/.
local ok, err = pcall(function()
    require("seamless_coop.main").start({
        re = re,
        sdk = sdk,
        imgui = imgui,
        json = json,
        io = io,
        reframework = reframework,
        seamless_net = rawget(_G, "seamless_net"),
        clock = os.clock,
    })
end)

if not ok then
    -- Never break other scripts: report the error in the REFramework menu and log instead.
    local message = tostring(err)
    pcall(function() log.error("[seamless_coop] failed to start: " .. message) end)
    re.on_draw_ui(function()
        if imgui.tree_node("Seamless Co-op (failed to start)") then
            imgui.text(message)
            imgui.tree_pop()
        end
    end)
end

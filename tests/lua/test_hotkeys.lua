local t = require("lib.t")
local hotkeys = require("seamless_coop.core.hotkeys")

t.test("hotkeys: parse keys and modifiers", function()
    local b = hotkeys.parse("Ctrl+F12")
    t.eq(b.key, 0x7B)
    t.same(b.mods, { 0x11 })
    t.eq(hotkeys.parse("f9").key, 0x78)
    t.eq(hotkeys.parse("Shift + Alt + K").key, string.byte("K"))
    t.eq(#hotkeys.parse("Shift + Alt + K").mods, 2)
    t.no(hotkeys.parse("Hyper+F1"))
    t.no(hotkeys.parse("F99"))
    t.no(hotkeys.parse(""))
end)

t.test("hotkeys: watcher fires once per press and needs the modifiers", function()
    local down = {}
    local w = hotkeys.watcher(function(vk) return down[vk] == true end)
    local b = hotkeys.parse("Ctrl+F12")
    down[0x7B] = true
    t.no(w:pressed(b))          -- F12 without Ctrl
    down[0x11] = true
    t.ok(w:pressed(b))          -- edge
    t.no(w:pressed(b))          -- still held
    down[0x7B] = false
    t.no(w:pressed(b))
    down[0x7B] = true
    t.ok(w:pressed(b))
    t.no(w:pressed(nil))
end)

local t = require("lib.t")
local build_check = require("seamless_coop.compat.build_check")

local registry = {
    features = { core = { required = true }, story = {}, risky = { needs_verified_build = true } },
    entries = {
        { id = "T", kind = "type", type = "app.T", feature = "core" },
        { id = "T.m", kind = "method", type = "app.T", sig = "m()", feature = "story" },
        { id = "T.f", kind = "field", type = "app.T", name = "_f", feature = "story" },
        { id = "E.A", kind = "enum", type = "app.E", name = "A", feature = "story" },
        { id = "T.x", kind = "method", type = "app.T", sig = "x()", feature = "risky" },
    },
}

local function env(types)
    return {
        find_type = function(name) return types[name] and { name = name } or nil end,
        find_method = function(td, sig) return types[td.name].methods[sig] end,
        find_field = function(td, name) return types[td.name].fields[name] end,
        enum_value = function(td, name) return types[td.name].enum[name] end,
    }
end

local GOOD = {
    ["app.T"] = { methods = { ["m()"] = "M", ["x()"] = "X" }, fields = { _f = "F" } },
    ["app.E"] = { enum = { A = 3 } },
}

t.test("build_check: everything resolves", function()
    local r = build_check.resolve(registry, env(GOOD))
    t.ok(r.core_ok)
    t.eq(#r.failures, 0)
    t.eq(r.resolved["T.m"], "M")
    t.eq(r.resolved["E.A"], 3)
    local d = build_check.decide(registry, r, "verified")
    t.ok(d.enabled)
    t.ok(d.features.story.on)
    t.ok(d.features.risky.on)
end)

t.test("build_check: a missing feature entry disables only that feature", function()
    local types = { ["app.T"] = { methods = { ["x()"] = "X" }, fields = { _f = "F" } }, ["app.E"] = { enum = { A = 3 } } }
    local r = build_check.resolve(registry, env(types))
    t.ok(r.core_ok)
    t.eq(#r.failures, 1)
    t.eq(r.failures[1].id, "T.m")
    local d = build_check.decide(registry, r, "verified")
    t.ok(d.enabled)
    t.no(d.features.story.on)
    t.ok(d.features.story.reason:find("1 of 3"))
    t.ok(d.features.risky.on)
end)

t.test("build_check: a missing core entry disables the whole mod", function()
    local r = build_check.resolve(registry, env({ ["app.E"] = { enum = { A = 3 } } }))
    t.no(r.core_ok)
    local d = build_check.decide(registry, r, "verified")
    t.no(d.enabled)
    t.ok(d.reason:find("unsupported"))
    t.no(d.features.story.on)
end)

t.test("build_check: enums must resolve to integers; lookups that throw count as missing", function()
    local types = {
        ["app.T"] = { methods = { ["m()"] = "M", ["x()"] = "X" }, fields = { _f = "F" } },
        ["app.E"] = { enum = { A = 1.5 } },
    }
    local r = build_check.resolve(registry, env(types))
    t.eq(r.failures[1].id, "E.A")
    local throwing = env(GOOD)
    throwing.find_field = function() error("boom") end
    r = build_check.resolve(registry, throwing)
    t.eq(r.failures[1].id, "T.f")
end)

t.test("build_check: unverified builds keep read-only features, disable risky ones", function()
    local r = build_check.resolve(registry, env(GOOD))
    local d = build_check.decide(registry, r, "unverified")
    t.ok(d.enabled)
    t.ok(d.features.story.on)
    t.no(d.features.risky.on)
end)

t.test("build_check: build status", function()
    local known = { [24705561] = "1.042" }
    t.eq(build_check.build_status(24705561, known), "verified")
    t.eq(build_check.build_status(1, known), "unverified")
    t.eq(build_check.build_status(nil, known), "unknown")
    t.eq(build_check.build_status(0, known), "unknown")
end)

t.test("build_check: the real registry is well formed", function()
    local real = require("seamless_coop.compat.registry")
    local ids = {}
    for _, e in ipairs(real.entries) do
        t.ok(e.id and not ids[e.id], "unique id " .. tostring(e.id))
        ids[e.id] = true
        t.ok(real.features[e.feature], "feature of " .. e.id)
        t.ok(({ type = true, method = true, field = true, enum = true })[e.kind], "kind of " .. e.id)
        if e.kind == "method" then t.ok(e.sig:find("%(.*%)$"), "signature of " .. e.id) end
    end
    t.ok(real.features.core.required)
end)

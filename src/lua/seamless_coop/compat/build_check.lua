-- Build gate (spec F5.1): resolves the registry against the running game and decides which features may run.
-- `env` abstracts REFramework's sdk so this module is testable offline:
--   env.find_type(name) -> handle|nil
--   env.find_method(type_handle, sig) -> handle|nil
--   env.find_field(type_handle, name) -> handle|nil
--   env.enum_value(type_handle, name) -> integer|nil
local M = {}

local function resolve_entry(env, e, type_cache)
    local td = type_cache[e.type]
    if td == nil then
        local ok, res = pcall(env.find_type, e.type)
        td = (ok and res) or false
        type_cache[e.type] = td
    end
    if not td then return nil, "type not found: " .. e.type end
    if e.kind == "type" then return td end
    if e.kind == "method" then
        local ok, m = pcall(env.find_method, td, e.sig)
        if ok and m then return m end
        return nil, "method not found: " .. e.type .. "." .. e.sig
    elseif e.kind == "field" then
        local ok, f = pcall(env.find_field, td, e.name)
        if ok and f then return f end
        return nil, "field not found: " .. e.type .. "." .. e.name
    elseif e.kind == "enum" then
        local ok, v = pcall(env.enum_value, td, e.name)
        if ok and math.type(v) == "integer" then return v end
        return nil, "enum value not found: " .. e.type .. "." .. e.name
    end
    return nil, "unknown entry kind: " .. tostring(e.kind)
end

-- Returns a report:
--   resolved[id] = handle/value, failures = { {id, feature, reason} },
--   features[name] = { total, failed }, core_ok = bool
function M.resolve(registry, env)
    local report = { resolved = {}, failures = {}, features = {}, core_ok = true }
    for name in pairs(registry.features) do report.features[name] = { total = 0, failed = 0 } end
    local type_cache = {}
    for _, e in ipairs(registry.entries) do
        local stats = report.features[e.feature]
        if not stats then
            stats = { total = 0, failed = 0 }
            report.features[e.feature] = stats
        end
        stats.total = stats.total + 1
        local value, reason = resolve_entry(env, e, type_cache)
        if value ~= nil then
            report.resolved[e.id] = value
        else
            stats.failed = stats.failed + 1
            report.failures[#report.failures + 1] = { id = e.id, feature = e.feature, reason = reason }
            local meta = registry.features[e.feature]
            if meta and meta.required then report.core_ok = false end
        end
    end
    return report
end

-- Classifies the Steam build: "verified", "unverified" or "unknown" (no build number available).
function M.build_status(steam_build, verified_builds)
    if not steam_build or steam_build <= 0 then return "unknown" end
    if verified_builds[steam_build] then return "verified" end
    return "unverified"
end

-- Decides the mod state from a resolve() report and the build status.
-- Returns { enabled = bool, reason = string|nil, features = { [name] = { on = bool, reason = string|nil } } }
function M.decide(registry, report, build_status)
    local decision = { enabled = report.core_ok, features = {} }
    if not report.core_ok then
        decision.reason = "unsupported game version (core entries missing)"
    end
    for name, meta in pairs(registry.features) do
        local stats = report.features[name] or { total = 0, failed = 0 }
        local f = { on = true }
        if not report.core_ok then
            f.on, f.reason = false, "mod disabled"
        elseif stats.failed > 0 then
            f.on, f.reason = false, string.format("%d of %d game entries missing", stats.failed, stats.total)
        elseif meta.needs_verified_build and build_status ~= "verified" then
            f.on, f.reason = false, "game build not verified for this feature"
        end
        decision.features[name] = f
    end
    return decision
end

return M

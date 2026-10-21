-- Side-channel protocol: JSON envelope { p = protocol, t = type, s = seq, i = instance, u = 1 if unreliable,
-- d = payload } with strict, per-type schemas (implementation plan §8, spec N4). HELLO, HELLO_ACK and BYE are frozen:
-- they must stay decodable by every protocol version, so peers can always report a version mismatch.
local json = require("seamless_coop.core.json")
local version = require("seamless_coop.core.version")

local M = {}

M.VERSION = version.protocol
M.MAX_BYTES = 4096
M.MAX_INT = 2 ^ 53

local GUID = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

local function str(max, req, pat) return { t = "string", max = max, req = req, pat = pat } end
local function int(min, max, req) return { t = "int", min = min, max = max, req = req } end
local function enum(values, req)
    local set = {}
    for _, v in ipairs(values) do set[v] = true end
    return { t = "enum", set = set, req = req }
end
local function list(item, max, req) return { t = "list", item = item, max = max, req = req } end
local function scalar() return { t = "scalar" } end

local HELLO_FIELDS = {
    mod = str(32, true),
    proto = int(0, 1000000, true),
    build = int(0, M.MAX_INT, true),
    ref = str(64),
    hunter = str(36, true, GUID),
    story = int(-1, 32767, true),
    caps = list(str(24), 16),
    t = int(0, M.MAX_INT, true),
}

local function with(base, extra)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(extra) do out[k] = v end
    return out
end

M.SCHEMAS = {
    HELLO = HELLO_FIELDS,
    HELLO_ACK = with(HELLO_FIELDS, { echo = int(0, M.MAX_INT), held = int(0, 600000) }),
    HEARTBEAT = {
        st = enum({ "idle", "busy", "loading", "segment", "cutscene", "quest" }, true),
        story = int(-1, 32767, true),
        ms = int(-1, M.MAX_INT),
        seg = int(0, M.MAX_INT),
        t = int(0, M.MAX_INT, true),
        echo = int(0, M.MAX_INT),
        held = int(0, 600000),
    },
    BYE = { reason = enum({ "shutdown", "kill_switch", "incompatible", "left_party" }, true) },
    NOTICE = { code = str(32, true, "^[%w_]+$"), args = list(scalar(), 8) },
}

-- Types every protocol version understands (used to report mismatches).
M.FROZEN = { HELLO = true, HELLO_ACK = true, BYE = true }

local function check_value(spec, v, path)
    if spec.t == "string" then
        if type(v) ~= "string" then return path .. ": expected string" end
        if #v > spec.max then return path .. ": too long" end
        if spec.pat and not v:match(spec.pat) then return path .. ": bad format" end
    elseif spec.t == "int" then
        if math.type(v) ~= "integer" then return path .. ": expected integer" end
        if v < spec.min or v > spec.max then return path .. ": out of range" end
    elseif spec.t == "enum" then
        if type(v) ~= "string" or not spec.set[v] then return path .. ": not an allowed value" end
    elseif spec.t == "list" then
        if type(v) ~= "table" or (next(v) ~= nil and #v == 0) then return path .. ": expected list" end
        if #v > spec.max then return path .. ": too many items" end
        for i, item in ipairs(v) do
            local err = check_value(spec.item, item, path .. "[" .. i .. "]")
            if err then return err end
        end
    elseif spec.t == "scalar" then
        local tv = type(v)
        if tv ~= "string" and tv ~= "number" and tv ~= "boolean" then return path .. ": expected scalar" end
        if tv == "string" and #v > 64 then return path .. ": too long" end
    end
    return nil
end

-- Validates a payload against the schema of `mtype`. Unknown fields are ignored (forward compatibility).
function M.validate(mtype, d)
    local schema = M.SCHEMAS[mtype]
    if not schema then return "unknown message type" end
    if type(d) ~= "table" then return "payload must be an object" end
    for name, spec in pairs(schema) do
        local v = d[name]
        if v == nil or v == json.null then
            if spec.req then return name .. ": missing" end
        else
            local err = check_value(spec, v, name)
            if err then return err end
        end
    end
    return nil
end

-- Returns the wire string, or nil + error. `inst` identifies this game session (changes on restart).
-- `proto` overrides the protocol version (loopback test peers only). Unreliable messages carry u = 1 and use their
-- own sequence space: Steam orders reliable messages but not unreliable ones relative to them.
function M.encode(mtype, seq, inst, d, proto, unreliable)
    local err = M.validate(mtype, d or {})
    if err then return nil, "encode " .. mtype .. ": " .. err end
    local s, jerr = json.encode({ p = proto or M.VERSION, t = mtype, s = seq, i = inst, u = unreliable and 1 or nil,
                                  d = d or {} })
    if not s then return nil, jerr end
    if #s > M.MAX_BYTES then return nil, "encode " .. mtype .. ": message too large" end
    return s
end

-- Returns { p, t, s, i, d } or nil + error. Messages from other protocol versions are only accepted for FROZEN types.
function M.decode(bytes)
    if type(bytes) ~= "string" then return nil, "not a string" end
    if #bytes > M.MAX_BYTES then return nil, "message too large" end
    local msg, err = json.decode(bytes, { max_bytes = M.MAX_BYTES, max_depth = 6 })
    if not msg then return nil, err end
    if type(msg) ~= "table" or json.is_array(msg) then return nil, "envelope must be an object" end
    if math.type(msg.p) ~= "integer" then return nil, "bad protocol field" end
    if type(msg.t) ~= "string" or #msg.t > 24 then return nil, "bad type field" end
    if math.type(msg.s) ~= "integer" or msg.s < 0 then return nil, "bad sequence field" end
    if math.type(msg.i) ~= "integer" then return nil, "bad instance field" end
    if msg.u ~= nil and msg.u ~= 1 then return nil, "bad unreliable flag" end
    if msg.p ~= M.VERSION and not M.FROZEN[msg.t] then return nil, "protocol mismatch" end
    local verr = M.validate(msg.t, msg.d)
    if verr then return nil, msg.t .. ": " .. verr end
    return msg
end

return M

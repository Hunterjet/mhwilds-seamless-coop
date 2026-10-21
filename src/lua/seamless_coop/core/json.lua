-- Minimal, strict JSON codec (pure Lua 5.4). Deterministic output: object keys are sorted.
-- Used for side-channel messages, so decode() enforces size/depth limits and rejects anything malformed.
local M = {}

M.null = setmetatable({}, { __tostring = function() return "null" end, __name = "json.null" })

local ARRAY_MT = { __name = "json.array" }

-- Marks a table as an array so that an empty one encodes as [] instead of {}.
function M.array(t)
    return setmetatable(t or {}, ARRAY_MT)
end

function M.is_array(t)
    return getmetatable(t) == ARRAY_MT
end

---------------------------------------------------------------------------------------------------------------------
-- Encoder
---------------------------------------------------------------------------------------------------------------------
local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function enc_string(s)
    return '"' .. s:gsub('[%c"\\]', function(c) return ESC[c] or string.format("\\u%04x", c:byte()) end) .. '"'
end

local function sequence_length(t)
    local n = #t
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    if count == n then return n end
    return nil
end

local encode_value

local function encode_table(t, depth, seen)
    if seen[t] then error("json.encode: cycle detected", 0) end
    if depth > 64 then error("json.encode: nesting too deep", 0) end
    seen[t] = true
    local out
    local n = sequence_length(t)
    if M.is_array(t) or (n and n > 0) then
        if not n then error("json.encode: array has non-sequence keys", 0) end
        local parts = {}
        for i = 1, n do parts[i] = encode_value(t[i], depth + 1, seen) end
        out = "[" .. table.concat(parts, ",") .. "]"
    else
        local keys = {}
        for k in pairs(t) do
            if type(k) ~= "string" then error("json.encode: object keys must be strings", 0) end
            keys[#keys + 1] = k
        end
        table.sort(keys)
        local parts = {}
        for i, k in ipairs(keys) do parts[i] = enc_string(k) .. ":" .. encode_value(t[k], depth + 1, seen) end
        out = "{" .. table.concat(parts, ",") .. "}"
    end
    seen[t] = nil
    return out
end

encode_value = function(v, depth, seen)
    local t = type(v)
    if v == nil or v == M.null then
        return "null"
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then error("json.encode: cannot encode NaN/inf", 0) end
        if math.type(v) == "integer" then return tostring(v) end
        return string.format("%.14g", v)
    elseif t == "string" then
        return enc_string(v)
    elseif t == "table" then
        return encode_table(v, depth, seen)
    end
    error("json.encode: unsupported type " .. t, 0)
end

-- Returns the JSON text, or nil + error message.
function M.encode(value)
    local ok, res = pcall(encode_value, value, 0, {})
    if ok then return res end
    return nil, res
end

---------------------------------------------------------------------------------------------------------------------
-- Decoder
---------------------------------------------------------------------------------------------------------------------
local SIMPLE_ESC = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local Parser = {}
Parser.__index = Parser

function Parser:fail(msg)
    error(string.format("json.decode: %s at byte %d", msg, self.i), 0)
end

function Parser:skip_ws()
    local _, e = self.s:find("^[ \t\r\n]*", self.i)
    self.i = e + 1
end

function Parser:peek()
    return self.s:sub(self.i, self.i)
end

function Parser:string()
    local s, i = self.s, self.i + 1
    local buf = {}
    while true do
        local c = s:sub(i, i)
        if c == "" then self.i = i; self:fail("unterminated string") end
        if c == '"' then break end
        if c:byte() < 0x20 then self.i = i; self:fail("control character in string") end
        if c == "\\" then
            local e = s:sub(i + 1, i + 1)
            if SIMPLE_ESC[e] then
                buf[#buf + 1] = SIMPLE_ESC[e]
                i = i + 2
            elseif e == "u" then
                local hex = s:sub(i + 2, i + 5)
                if not hex:match("^%x%x%x%x$") then self.i = i; self:fail("bad \\u escape") end
                local cp = tonumber(hex, 16)
                i = i + 6
                if cp >= 0xD800 and cp <= 0xDBFF then
                    local lo = s:match("^\\u(%x%x%x%x)", i)
                    local lcp = lo and tonumber(lo, 16)
                    if not lcp or lcp < 0xDC00 or lcp > 0xDFFF then self.i = i; self:fail("bad surrogate pair") end
                    cp = 0x10000 + (cp - 0xD800) * 0x400 + (lcp - 0xDC00)
                    i = i + 6
                elseif cp >= 0xDC00 and cp <= 0xDFFF then
                    self.i = i; self:fail("lone low surrogate")
                end
                buf[#buf + 1] = utf8.char(cp)
            else
                self.i = i; self:fail("bad escape")
            end
        else
            local j = s:find('[%c"\\]', i) or (#s + 1)
            buf[#buf + 1] = s:sub(i, j - 1)
            i = j
        end
    end
    self.i = i + 1
    return table.concat(buf)
end

function Parser:number()
    local s, start = self.s, self.i
    local int = s:match("^-?%d+", start)
    if not int then self:fail("bad number") end
    if int:match("^-?0%d") then self:fail("leading zero") end
    local i = start + #int
    local frac = s:match("^%.%d+", i)
    if s:sub(i, i) == "." and not frac then self:fail("bad fraction") end
    if frac then i = i + #frac end
    local exp = s:match("^[eE][-+]?%d+", i)
    if s:sub(i, i):match("[eE]") and not exp then self:fail("bad exponent") end
    if exp then i = i + #exp end
    local text = s:sub(start, i - 1)
    self.i = i
    if not frac and not exp then
        local v = math.tointeger(tonumber(text))
        if v then return v end
    end
    local v = tonumber(text)
    if not v or v ~= v or v == math.huge or v == -math.huge then self:fail("bad number") end
    return v
end

function Parser:value(depth)
    if depth > self.max_depth then self:fail("nesting too deep") end
    self:skip_ws()
    local c = self:peek()
    if c == "{" then
        self.i = self.i + 1
        local obj = {}
        self:skip_ws()
        if self:peek() == "}" then self.i = self.i + 1; return obj end
        while true do
            self:skip_ws()
            if self:peek() ~= '"' then self:fail("expected string key") end
            local k = self:string()
            self:skip_ws()
            if self:peek() ~= ":" then self:fail("expected ':'") end
            self.i = self.i + 1
            if obj[k] ~= nil then self:fail("duplicate key") end
            obj[k] = self:value(depth + 1)
            self:skip_ws()
            local d = self:peek()
            self.i = self.i + 1
            if d == "}" then return obj end
            if d ~= "," then self.i = self.i - 1; self:fail("expected ',' or '}'") end
        end
    elseif c == "[" then
        self.i = self.i + 1
        local arr = M.array({})
        self:skip_ws()
        if self:peek() == "]" then self.i = self.i + 1; return arr end
        local n = 0
        while true do
            n = n + 1
            arr[n] = self:value(depth + 1)
            self:skip_ws()
            local d = self:peek()
            self.i = self.i + 1
            if d == "]" then return arr end
            if d ~= "," then self.i = self.i - 1; self:fail("expected ',' or ']'") end
        end
    elseif c == '"' then
        return self:string()
    elseif c == "-" or c:match("^%d$") then
        return self:number()
    elseif self.s:sub(self.i, self.i + 3) == "true" then
        self.i = self.i + 4; return true
    elseif self.s:sub(self.i, self.i + 4) == "false" then
        self.i = self.i + 5; return false
    elseif self.s:sub(self.i, self.i + 3) == "null" then
        self.i = self.i + 4; return M.null
    end
    self:fail("unexpected character")
end

-- Returns the decoded value, or nil + error message. opts: max_bytes (default 65536), max_depth (default 16).
-- JSON null decodes to json.null; arrays carry the json.array marker.
function M.decode(s, opts)
    opts = opts or {}
    if type(s) ~= "string" then return nil, "json.decode: input is not a string" end
    if #s > (opts.max_bytes or 65536) then return nil, "json.decode: input too large" end
    local p = setmetatable({ s = s, i = 1, max_depth = opts.max_depth or 16 }, Parser)
    local ok, res = pcall(function()
        local v = p:value(0)
        p:skip_ws()
        if p.i <= #s then p:fail("trailing data") end
        return v
    end)
    if ok then return res end
    return nil, res
end

return M

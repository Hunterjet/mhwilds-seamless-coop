-- Logger: levels, ring buffer for the panel, pluggable sinks. Every line is redacted (no full Steam IDs).
local util = require("seamless_coop.core.util")

local M = {}

M.LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }

local Log = {}
Log.__index = Log

-- opts: level ("info"), clock (fn -> seconds), ring_size (200)
function M.new(opts)
    opts = opts or {}
    return setmetatable({
        level = M.LEVELS[opts.level or "info"] or M.LEVELS.info,
        clock = opts.clock or os.clock,
        sinks = {},
        ring = {},
        ring_size = opts.ring_size or 200,
        next_slot = 1,
        stored = 0,
        warnings = 0,
        errors = 0,
    }, Log)
end

function Log:set_level(name)
    if M.LEVELS[name] then self.level = M.LEVELS[name] end
end

-- sink: { write = fn(line), flush = fn()? }
function Log:add_sink(sink)
    self.sinks[#self.sinks + 1] = sink
end

function Log:write(level, fmt, ...)
    local lv = M.LEVELS[level] or M.LEVELS.info
    if lv < self.level then return end
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = tostring(fmt) end
    msg = util.redact(msg)
    local line = string.format("%10.3f %-5s %s", self.clock(), level:upper(), msg)
    self.ring[self.next_slot] = line
    self.next_slot = self.next_slot % self.ring_size + 1
    if self.stored < self.ring_size then self.stored = self.stored + 1 end
    if lv == M.LEVELS.warn then self.warnings = self.warnings + 1 end
    if lv == M.LEVELS.error then self.errors = self.errors + 1 end
    for _, sink in ipairs(self.sinks) do
        pcall(sink.write, line)
        if lv >= M.LEVELS.warn and sink.flush then pcall(sink.flush) end
    end
end

function Log:debug(fmt, ...) self:write("debug", fmt, ...) end
function Log:info(fmt, ...) self:write("info", fmt, ...) end
function Log:warn(fmt, ...) self:write("warn", fmt, ...) end
function Log:error(fmt, ...) self:write("error", fmt, ...) end

function Log:flush()
    for _, sink in ipairs(self.sinks) do
        if sink.flush then pcall(sink.flush) end
    end
end

-- Last n lines, oldest first.
function Log:lines(n)
    n = math.min(n or self.stored, self.stored)
    local out = {}
    local start = (self.next_slot - n - 1) % self.ring_size + 1
    for i = 0, n - 1 do
        out[#out + 1] = self.ring[(start - 1 + i) % self.ring_size + 1]
    end
    return out
end

-- File sink over an io-like file handle (REFramework's io is sandboxed to reframework/data).
function M.file_sink(handle)
    return {
        write = function(line) handle:write(line, "\n") end,
        flush = function() handle:flush() end,
        close = function() handle:close() end,
    }
end

-- Picks the log slot for this session: slots 1..keep are reused in turn, so only the last `keep` sessions are kept
-- without needing to delete files. state_load/state_save persist {next = n}.
function M.next_slot(state_load, state_save, keep)
    local st = state_load() or {}
    local slot = tonumber(st.next) or 1
    if slot < 1 or slot > keep then slot = 1 end
    state_save({ next = slot % keep + 1 })
    return slot
end

return M

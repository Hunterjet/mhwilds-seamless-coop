-- Frame/timer scheduler. All mod logic runs from here (re.on_frame), never inside game hooks. Every task runs under
-- pcall; a task that faults `max_faults` times within `fault_window` seconds is disabled (spec F5.6).
local M = {}

local Scheduler = {}
Scheduler.__index = Scheduler

-- opts: clock (fn -> seconds), max_faults (5), fault_window (60), on_fault(task, err), on_disabled(task)
function M.new(opts)
    opts = opts or {}
    return setmetatable({
        clock = opts.clock or os.clock,
        max_faults = opts.max_faults or 5,
        fault_window = opts.fault_window or 60,
        on_fault = opts.on_fault,
        on_disabled = opts.on_disabled,
        list = {},
    }, Scheduler)
end

local function add(self, task)
    task.faults = {}
    task.runs = 0
    self.list[#self.list + 1] = task
    return task
end

-- fn(now) runs every tick.
function Scheduler:on_frame(name, fn)
    return add(self, { name = name, kind = "frame", fn = fn, next_at = -math.huge })
end

-- fn(now) runs every `interval` seconds; first run after `opts.delay` (default: next tick).
function Scheduler:every(name, interval, fn, opts)
    local delay = opts and opts.delay or 0
    return add(self, { name = name, kind = "every", interval = interval, fn = fn, next_at = self.clock() + delay })
end

-- fn(now) runs once after `delay` seconds.
function Scheduler:after(name, delay, fn)
    return add(self, { name = name, kind = "after", fn = fn, next_at = self.clock() + delay })
end

function Scheduler:cancel(task)
    if task then task.cancelled = true end
end

function Scheduler:enable(task)
    task.disabled = false
    task.faults = {}
end

local function record_fault(self, task, err, now)
    local faults = task.faults
    faults[#faults + 1] = now
    while #faults > 0 and now - faults[1] > self.fault_window do table.remove(faults, 1) end
    task.last_error = tostring(err)
    if self.on_fault then pcall(self.on_fault, task, err) end
    if #faults >= self.max_faults then
        task.disabled = true
        if self.on_disabled then pcall(self.on_disabled, task) end
    end
end

function Scheduler:tick()
    local now = self.clock()
    local snapshot = table.move(self.list, 1, #self.list, 1, {})
    for _, task in ipairs(snapshot) do
        if not task.cancelled and not task.disabled and now >= task.next_at then
            if task.kind == "every" then
                task.next_at = task.next_at + task.interval
                if task.next_at <= now then task.next_at = now + task.interval end
            elseif task.kind == "after" then
                task.cancelled = true
            end
            task.runs = task.runs + 1
            local ok, err = pcall(task.fn, now)
            if not ok then record_fault(self, task, err, now) end
        end
    end
    for i = #self.list, 1, -1 do
        if self.list[i].cancelled then table.remove(self.list, i) end
    end
end

-- Snapshot for diagnostics: { name, kind, runs, faults, disabled, last_error }.
function Scheduler:status()
    local out = {}
    for _, t in ipairs(self.list) do
        out[#out + 1] = { name = t.name, kind = t.kind, runs = t.runs, faults = #t.faults, disabled = t.disabled == true,
                          last_error = t.last_error }
    end
    return out
end

return M

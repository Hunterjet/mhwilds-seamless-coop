-- Publish/subscribe event bus. emit() delivers immediately; post() queues for the next flush(), which is what game
-- hooks use so they do no work inside the game's call stack. Handlers run under pcall.
local M = {}

local Bus = {}
Bus.__index = Bus

-- opts: on_error(topic, err), max_queue (default 1024)
function M.new(opts)
    opts = opts or {}
    return setmetatable({
        subs = {},
        queue = {},
        max_queue = opts.max_queue or 1024,
        dropped = 0,
        on_error = opts.on_error,
    }, Bus)
end

-- Returns an unsubscribe function.
function Bus:on(topic, fn)
    local list = self.subs[topic]
    if not list then
        list = {}
        self.subs[topic] = list
    end
    local entry = { fn = fn }
    list[#list + 1] = entry
    return function()
        entry.removed = true
        for i, e in ipairs(list) do
            if e == entry then
                table.remove(list, i)
                break
            end
        end
    end
end

function Bus:emit(topic, ...)
    local list = self.subs[topic]
    if not list then return 0 end
    local snapshot = table.move(list, 1, #list, 1, {})
    local delivered = 0
    for _, e in ipairs(snapshot) do
        if not e.removed then
            local ok, err = pcall(e.fn, ...)
            delivered = delivered + 1
            if not ok and self.on_error then pcall(self.on_error, topic, err) end
        end
    end
    return delivered
end

function Bus:post(topic, ...)
    if #self.queue >= self.max_queue then
        self.dropped = self.dropped + 1
        return false
    end
    self.queue[#self.queue + 1] = { topic = topic, args = table.pack(...) }
    return true
end

-- Delivers queued events (including ones posted by handlers during this flush, up to `max`).
function Bus:flush(max)
    max = max or 4096
    local n = 0
    while #self.queue > 0 and n < max do
        local e = table.remove(self.queue, 1)
        self:emit(e.topic, table.unpack(e.args, 1, e.args.n))
        n = n + 1
    end
    return n
end

return M

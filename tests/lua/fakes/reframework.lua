-- Fake REFramework environment for offline tests of main.lua: in-memory json/io, a scriptable sdk, recording imgui.
local M = {}

-- In-memory "reframework/data" folder shared by json and io.
function M.data_store()
    local store = { files = {} }
    store.json = {
        load_file = function(path)
            local v = store.files[path]
            if type(v) == "table" then return v end
            return nil
        end,
        dump_file = function(path, value)
            store.files[path] = value
            return true
        end,
    }
    store.io = {
        open = function(path, mode)
            if tostring(mode):sub(1, 1) == "r" then
                if store.files[path] == nil then return nil, path .. ": No such file or directory" end
                return { close = function() end, read = function() return "" end }
            end
            local buf = {}
            store.files[path] = buf
            return {
                write = function(_, ...)
                    for _, s in ipairs({ ... }) do buf[#buf + 1] = tostring(s) end
                end,
                flush = function() end,
                close = function() buf.closed = true end,
            }
        end,
    }
    return store
end

-- A managed-object stand-in: methods by name, fields by name.
function M.object(type_name, methods, fields)
    return { type_name = type_name, methods = methods or {}, fields = fields or {} }
end

-- sdk fake built from a type table: types[name] = { methods = { [sig] = fn(obj, ...) }, fields = { [name] = value } }
function M.sdk(types, singletons)
    local sdk = {}
    function sdk.find_type_definition(name)
        local t = types[name]
        if not t then return nil end
        local td = { name = name }
        function td:get_method(sig)
            local fn = t.methods and t.methods[sig]
            if not fn then return nil end
            return { call = function(_, obj, ...) return fn(obj, ...) end }
        end
        function td:get_field(fname)
            if not t.fields or t.fields[fname] == nil then return nil end
            local v = t.fields[fname]
            return { get_data = function(_, obj)
                if obj == nil then return v end
                return obj.fields[fname]
            end }
        end
        return td
    end
    function sdk.get_managed_singleton(name)
        return singletons and singletons[name] or nil
    end
    return sdk
end

-- Records every imgui call; buttons listed in `press` return true once.
function M.imgui(press)
    local g = { calls = {}, press = press or {} }
    local function rec(name, ...)
        g.calls[#g.calls + 1] = { name = name, args = { ... } }
    end
    g.tree_node = function(label) rec("tree_node", label) return true end
    g.tree_pop = function() rec("tree_pop") end
    g.text = function(s) rec("text", s) end
    g.text_colored = function(s, c) rec("text_colored", s, c) end
    g.checkbox = function(label, v) rec("checkbox", label, v) return false, v end
    g.button = function(label)
        rec("button", label)
        if g.press[label] then
            g.press[label] = nil
            return true
        end
        return false
    end
    g.same_line = function() rec("same_line") end
    function g.texts()
        local out = {}
        for _, c in ipairs(g.calls) do
            if c.name == "text" or c.name == "text_colored" then out[#out + 1] = c.args[1] end
        end
        return out
    end
    function g.has_text(pattern)
        for _, s in ipairs(g.texts()) do
            if tostring(s):find(pattern) then return true end
        end
        return false
    end
    return g
end

-- re.* callback registry.
function M.re()
    local r = { frame = {}, draw = {}, reset = {}, config_save = {} }
    r.api = {
        on_frame = function(fn) r.frame[#r.frame + 1] = fn end,
        on_draw_ui = function(fn) r.draw[#r.draw + 1] = fn end,
        on_script_reset = function(fn) r.reset[#r.reset + 1] = fn end,
        on_config_save = function(fn) r.config_save[#r.config_save + 1] = fn end,
    }
    function r.run(list)
        for _, fn in ipairs(r[list]) do fn() end
    end
    return r
end

-- System.Guid value-type stand-in (fields mData1..mData4_7).
function M.guid(d1, d2, d3, bytes)
    local f = { mData1 = d1, mData2 = d2, mData3 = d3 }
    for i = 0, 7 do f["mData4_" .. i] = bytes[i + 1] end
    return { get_field = function(_, name) return f[name] end }
end

-- A fake game implementing every registry entry. members: list of
-- { valid, self, hunter (guid), name, platform, index, progress, sync }.
function M.game(opts)
    opts = opts or {}
    local g = { members = opts.members or {}, progress = opts.progress or 250, link_value = 3 }
    local list = { fields = {} }
    list.fields._ListInfo = { get_elements = function() return g.members end }
    local uim, nm, mm = { name = "uim" }, { name = "nm" }, { name = "mm" }
    local function getter(key) return function(o) return o[key] end end
    g.types = {
        ["app.MissionManager"] = { methods = {
            ["getProgressId()"] = function() return g.progress end,
            ["getPartySyncProgressId()"] = function() return 0 end,
        } },
        ["app.NetworkManager"] = { methods = { ["get_UserInfoManager()"] = function() return uim end } },
        ["app.Net_UserInfoManager"] = { methods = {
            ["getUserInfoList(app.net_session_manager.SESSION_TYPE)"] = function(_, st)
                assert(st == g.link_value, "expected the LINK session type")
                return list
            end,
        } },
        ["app.net_session_manager.SESSION_TYPE"] = { fields = { LINK = g.link_value } },
        ["app.Net_UserInfoList"] = { fields = { _ListInfo = true } },
        ["app.Net_UserInfo"] = { methods = {
            ["get_IsValid()"] = getter("valid"),
            ["get_IsSelf()"] = getter("self"),
            ["get_HunterId()"] = getter("hunter"),
            ["get_OnlineId()"] = getter("name"),
            ["get_PlatformId()"] = getter("platform"),
            ["get_MemberIndex()"] = getter("index"),
            ["get_MemberListProgressId()"] = getter("progress"),
            ["get_IsPartySync()"] = getter("sync"),
        } },
    }
    for _, name in ipairs(opts.remove_types or {}) do g.types[name] = nil end
    g.singletons = { ["app.MissionManager"] = mm, ["app.NetworkManager"] = nm }
    g.sdk = M.sdk(g.types, g.singletons)
    return g
end

-- seamless_net plugin stand-in that records traffic.
function M.net(opts)
    opts = opts or {}
    local n = { sent = {}, allowed = {}, inbox = {}, closed = {} }
    n.version = function() return { plugin = "0.1.0", api = 1, channel = 2246 } end
    n.game_build = function() return opts.build or 24705561 end
    n.friends_in_game = function() return opts.friends or {} end
    n.allow = function(id, on)
        n.allowed[id] = on and true or nil
        return true
    end
    n.send = function(id, data, reliable)
        n.sent[#n.sent + 1] = { id = id, data = data, reliable = reliable }
        return true
    end
    n.poll = function()
        local out = n.inbox
        n.inbox = {}
        return out
    end
    n.close = function(id) n.closed[#n.closed + 1] = id return true end
    n.local_id = function() return "76561198000000099" end
    n.status = function()
        return { steam = true, relay = 100, sent = #n.sent, received = 0, dropped_not_allowed = 0, dropped_size = 0,
                 dropped_rate = 0, backup = { state = "done", message = "ok", files = 2, folder = "20261021-100000" } }
    end
    return n
end

return M
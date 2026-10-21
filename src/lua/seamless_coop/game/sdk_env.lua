-- REFramework sdk access for the build gate. The only place that turns registry entries into sdk handles.
local M = {}

function M.new(sdk)
    return {
        find_type = function(name)
            return sdk.find_type_definition(name)
        end,
        find_method = function(td, sig)
            return td:get_method(sig)
        end,
        find_field = function(td, name)
            return td:get_field(name)
        end,
        enum_value = function(td, name)
            local f = td:get_field(name)
            if not f then return nil end
            return math.tointeger(f:get_data(nil))
        end,
    }
end

-- Formats a System.Guid value type as the canonical lower-case 8-4-4-4-12 string.
function M.guid_to_string(g)
    if g == nil then return nil end
    local ok, s = pcall(function()
        local b = {}
        for i = 0, 7 do b[i + 1] = g:get_field("mData4_" .. i) end
        return string.format("%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            g:get_field("mData1"), g:get_field("mData2"), g:get_field("mData3"),
            b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8])
    end)
    if ok then return s end
    local ok2, s2 = pcall(g.call, g, "ToString()")
    if ok2 and type(s2) == "string" then return s2:lower() end
    return nil
end

-- Iterates a managed System.Array (REFramework object) as a Lua list.
function M.array_items(arr)
    if arr == nil then return {} end
    local ok, items = pcall(arr.get_elements, arr)
    if ok and type(items) == "table" then return items end
    local out = {}
    local okn, n = pcall(arr.get_size, arr)
    if not okn or not n then return out end
    for i = 0, n - 1 do
        local oke, e = pcall(arr.get_element, arr, i)
        if oke and e ~= nil then out[#out + 1] = e end
    end
    return out
end

return M

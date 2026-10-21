local t = require("lib.t")
local json = require("seamless_coop.core.json")

t.test("json: encodes scalars, sorted objects and arrays", function()
    t.eq(json.encode({ b = 1, a = "x", c = true }), '{"a":"x","b":1,"c":true}')
    t.eq(json.encode({ 1, 2, 3 }), "[1,2,3]")
    t.eq(json.encode({}), "{}")
    t.eq(json.encode(json.array()), "[]")
    t.eq(json.encode(1.5), "1.5")
    t.eq(json.encode(-7), "-7")
    t.eq(json.encode(json.null), "null")
end)

t.test("json: escapes strings", function()
    t.eq(json.encode('a"b\\c\n\t\1'), '"a\\"b\\\\c\\n\\t\\u0001"')
end)

t.test("json: refuses what JSON cannot represent", function()
    t.no(json.encode(0 / 0))
    t.no(json.encode(math.huge))
    t.no(json.encode({ [1] = 1, x = 2 }))
    t.no(json.encode({ [true] = 1 }))
    local cyc = {}
    cyc.self = cyc
    local s, err = json.encode(cyc)
    t.no(s)
    t.ok(err:find("cycle"))
end)

t.test("json: round trip keeps integers and floats apart", function()
    local v = json.decode('{"i":42,"f":4.5,"e":1e3,"n":-0.25,"s":"x","b":false,"a":[1,"two",null]}')
    t.eq(math.type(v.i), "integer")
    t.eq(v.i, 42)
    t.eq(math.type(v.f), "float")
    t.eq(v.e, 1000.0)
    t.eq(v.n, -0.25)
    t.eq(v.s, "x")
    t.eq(v.b, false)
    t.ok(json.is_array(v.a))
    t.eq(v.a[2], "two")
    t.eq(v.a[3], json.null)
    t.eq(json.decode(json.encode({ x = { 1, 2 } })).x[2], 2)
end)

t.test("json: decodes escapes and unicode (incl. surrogate pairs)", function()
    t.eq(json.decode('"a\\nb\\u0041\\u00e9"'), "a\nbA\u{e9}")
    t.eq(json.decode('"\\ud83d\\ude00"'), "\u{1F600}")
    t.eq(json.decode('"caf\u{e9}"'), "caf\u{e9}")
end)

t.test("json: rejects malformed input", function()
    for _, bad in ipairs({
        "", "{", "[1,]", '{"a":1,}', "01", "1.", ".5", "1e", '"\1"', '"\\x"', '"\\ud83d"', '"\\ude00"',
        "tru", "nul", '{"a" 1}', '{a:1}', "[1 2]", '{"a":1}x', '{"a":1,"a":2}', "NaN", "-",
    }) do
        local v, err = json.decode(bad)
        t.eq(v, nil, "input " .. bad)
        t.ok(err, "error for " .. bad)
    end
end)

t.test("json: enforces size and depth limits", function()
    t.no(json.decode(string.rep(" ", 20) .. "1", { max_bytes = 10 }))
    t.no(json.decode(string.rep("[", 20) .. string.rep("]", 20), { max_depth = 16 }))
    t.ok(json.decode(string.rep("[", 10) .. string.rep("]", 10), { max_depth = 16 }))
    t.no(json.decode(42))
end)

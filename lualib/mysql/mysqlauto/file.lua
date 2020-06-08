local _M = {}

local function getfile(ctx, f)
    return string.format("%s/%s.%s", ctx.dir, ctx.name, f)
end

local function writefile(name, str)
    local file = assert(io.open(name, "w"))
    file:write(str)
    file:close()
end

local function readfile(name)
    local file = assert(io.open(name, "r"))
    local str = file:read("*a")
    file:close()
    return str
end

local function readfilelines(name)
    local file = assert(io.open(name, "r"))
    local ret = {}
    while true do
        local line = file:read("*l")
        if not line then break end
        table.insert(ret, line)
    end
    return ret
end

local function encode_table_column(ret, attrs)
    local function encode_column(lines)
        local ret = {}
        for _, k in ipairs(attrs) do
            local v = lines[k]
            if v then
                table.insert(ret, string.format("%s='%s'", k, v))
            end
        end
        return (table.concat(ret, " "))
    end
    local tbl = {}
    for _, v in ipairs(ret) do table.insert(tbl, encode_column(v)) end
    return (table.concat(tbl, "\n"))
end

local function decode_table_column(tbls)
    local function decode_column(linestr)
        local ret = {}
        for k, v in string.gmatch(linestr, "(%S+)='(.-)'") do ret[k] = v end
        return ret
    end
    local ret = {}
    for _, v in pairs(tbls) do
        local r = decode_column(v)
        table.insert(ret, r)
    end
    return ret
end

local function decode_table_index(tbls)
    local function decode_column(linestr)
        local ret = {}
        for k, v in string.gmatch(linestr, "(%S+)='(.-)'") do ret[k] = v end
        return ret
    end
    local ret = {}
    for _, v in pairs(tbls) do
        local r = decode_column(v)
        local old = ret[r.key_name]
        if old then
            old.column_name = old.column_name .. ',' .. r.column_name
        else
            ret[r.key_name] = r
        end
    end
    return ret
end

function _M.load(ctx)
    ctx.table_list = readfilelines(getfile(ctx, "table.list"))
    ctx.table = setmetatable({}, {
        __index = function(t, k)
            local str = readfilelines(getfile(ctx, "table." .. k))
            local r = decode_table_column(str)
            t[k] = r
            return r
        end
    })
    ctx.tablecreate = setmetatable({}, {
        __index = function(t, k)
            local r = readfile(getfile(ctx, "tablecreate." .. k))
            t[k] = r
            return r
        end
    })
    ctx.index = setmetatable({}, {
        __index = function(t, k)
            local str = readfilelines(getfile(ctx, "index." .. k))
            local r = decode_table_index(str)
            t[k] = r
            return r
        end
    })
    ctx.proc_list = readfilelines(getfile(ctx, "proc.list"))
    ctx.proc = setmetatable({}, {
        __index = function(t, k)
            local r = readfile(getfile(ctx, "proc." .. k))
            t[k] = r
            return r
        end
    })
    ctx.func_list = readfilelines(getfile(ctx, "func.list"))
    ctx.func = setmetatable({}, {
        __index = function(t, k)
            local r = readfile(getfile(ctx, "func." .. k))
            t[k] = r
            return r
        end
    })
    return ctx
end

function _M.newctx(ret, opt)
    ret.name = assert(opt.name)
    ret.dir = assert(opt.dir)
    return ret
end

function _M.compare(ctx, new)
    return new
end

local index_field_attrs = {
    "table", "non_unique", "key_name", "seq_in_index", "column_name",
    "collation", "sub_part", "packed", "null", "index_type", "the_index",
    "comment"
}
local field_attrs = {
    "field", "type", "collation", "null", "key", "default", "extra", "comment",
    "the_index"
}
function _M.save(ctx)
    writefile(getfile(ctx, "table.list"), table.concat(ctx.table_list, "\n"))
    for _, k in ipairs(ctx.table_list) do
        writefile(getfile(ctx, "table." .. k),
                  encode_table_column(ctx.table[k], field_attrs))
        writefile(getfile(ctx, "index." .. k),
                  encode_table_column(ctx.index[k], index_field_attrs))
        writefile(getfile(ctx, "tablecreate." .. k), ctx.tablecreate[k])
    end
    writefile(getfile(ctx, "proc.list"), table.concat(ctx.proc_list, "\n"))
    for _, k in ipairs(ctx.proc_list) do
        writefile(getfile(ctx, "proc." .. k), ctx.proc[k])
    end
    writefile(getfile(ctx, "func.list"), table.concat(ctx.func_list, "\n"))
    for _, k in ipairs(ctx.func_list) do
        writefile(getfile(ctx, "func." .. k), ctx.func[k])
    end
end

return _M

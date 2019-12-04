local _M = {}
local field_attrs = { "field", "type", "collation", "null", "key", "default", "extra", "comment", "the_index" }

local function showcolumn(ctx, tbl)
    local ret = {}
    local sqlret = assert(ctx.query(string.format("show full columns from %s", tbl)))
    for k, v in ipairs(sqlret) do
        local c = {}
        for _k, _v in pairs(v) do
            c[string.lower(_k)] = _v
        end
        c.the_index = tostring(k)
        for _, key in ipairs(field_attrs) do
            if c[key] == nil then c[key] = "__NULL__" end
        end
        table.insert(ret, c)
    end
    return ret
end

local function showtables(ctx)
    local ret = {}
    local sqlret = assert(ctx.query("show tables;"))
    for _, v in ipairs(sqlret) do
        for _, value in pairs(v) do
            table.insert(ret, value)
        end
    end
    return ret
end

local function showcreatetable(ctx, tbl)
    local sqlret = assert(ctx.query(string.format("show create table %s", tbl)))
    local str = sqlret[1]["Create Table"]
    str = string.gsub(str, " AUTO_INCREMENT=%d*", "")
    str = string.gsub(str, " USING BTREE", "USING HASH")
    str = string.gsub(str, " ROW_FORMAT=DYNAMIC", "")
    str = string.gsub(str, " ROW_FORMAT=FIXED", "")
    str = string.gsub(str, " ROW_FORMAT=COMPACT", "")
    str = string.gsub(str, "ENGINE=%w*", "ENGINE=InnoDB")
    return str
end

local function showindex(ctx, tbl)
    local ret = {}
    local sqlret = assert(ctx.query(string.format("show index from %s", tbl)))
    for _, v in ipairs(sqlret) do
        local c = {}
        for _k, _v in pairs(v) do
            c[string.lower(_k)] = _v
        end
        table.insert(ret, c)
    end
    return ret
end

local function showcreateprocedure(ctx, proc)
    local sqlret = assert(ctx.query(string.format("show create procedure %s", proc)))
    local str = sqlret[1]["Create Procedure"]
    str = string.gsub(str, "CREATE(.*)PROCEDURE", "CREATE PROCEDURE")
    --str=string.format("DROP PROCEDURE IF EXISTS `%s`;\nDELIMITER $$\n%s\n$$\nDELIMITER ;",proc,str)
    return str
end

local function showcreatefunction(ctx, proc)
    local sqlret = assert(ctx.query(string.format("show create function %s", proc)))
    local str = sqlret[1]["Create Function"]
    str = string.gsub(str, "CREATE(.*)FUNCTION", "CREATE FUNCTION")
    --str=string.format("DROP PROCEDURE IF EXISTS `%s`;\nDELIMITER $$\n%s\n$$\nDELIMITER ;",proc,str)
    return str
end

local function showdatabase(ctx)
    local sqlret = assert(ctx.query("select database()"))
    return sqlret[1]["database()"]
end

local function showprocedures(ctx)
    local dbname = showdatabase(ctx)
    local sqlret = assert(ctx.query(string.format("select name,type from mysql.proc where db='%s'", dbname)))
    local ret, func = {}, {}
    for _, v in pairs(sqlret) do
        local name, type = v.name, v.type
        if type == 'PROCEDURE' then
            table.insert(ret, name);
        else
            table.insert(func, name)
        end
    end
    return ret, func
end

function _M.newctx(ret, opt)
    ret.query = assert(opt.query)
    return ret
end

function _M.load(ctx)
    ctx.table_list = showtables(ctx)
    ctx.table = setmetatable({}, { __index = function(t, k)
        local r = showcolumn(ctx, k)
        t[k] = r
        return r
    end })
    ctx.tablecreate = setmetatable({}, { __index = function(t, k)
        local r = showcreatetable(ctx, k)
        t[k] = r
        return r
    end })
    ctx.index = setmetatable({}, { __index = function(t, k)
        local r = showindex(ctx, k)
        t[k] = r
        return r
    end })
    local proc, func = showprocedures(ctx)
    ctx.proc_list = proc
    ctx.proc = setmetatable({}, { __index = function(t, k)
        local r = showcreateprocedure(ctx, k)
        t[k] = r
        return r
    end })
    ctx.func_list = func
    ctx.func = setmetatable({}, { __index = function(t, k)
        local r = showcreatefunction(ctx, k)
        t[k] = r
        return r
    end })
    return ctx
end

local function array2dict(array)
    local d = {}
    for k, v in ipairs(array) do
        d[v] = k
    end
    return d
end

local function fieldfind(tbl, k)
    for _, v in pairs(tbl) do
        if v.field == k then return v end
    end
end

local function markfield(set, tbl, v)
    local null = ""
    local default = ""
    if v.null == "NO" then
        null = "NOT NULL"
    end
    if v.default == "__NULL__" then
        if v.null ~= "NO" then
            default = "DEFAULT NULL"
        end
    else
        default = string.format("DEFAULT '%s'", v.default)
    end
    local collate = ""
    if v.collation ~= "" and v.collation ~= "__NULL__" then
        collate = string.format("COLLATE '%s'", v.collation)
    end
    local cmt = ""
    if v.comment ~= "" then
        cmt = string.format("COMMENT '%s'", v.comment)
    end
    local pos = 'FIRST'
    if tonumber(v.the_index) > 1 then
        pos = string.format("ALTER `%s`", set[v.the_index - 1].field)
    end
    return null, default, cmt, collate, pos
end

local function make_changefield(set, tbl, v)
    local null, default, cmt, collate, pos = markfield(set, tbl, v)
    return string.format("alter table `%s` change column `%s` `%s` %s %s  %s %s  %s %s  %s",
    tbl, v.field, v.field, string.lower(v.type), null, default, cmt, collate, string.lower(v.extra or ""), pos)
end

local function make_addfield(set, tbl, v)
    local null, default, cmt, collate, pos = markfield(set, tbl, v)
    return string.format("alter table `%s` add column `%s` %s %s  %s %s  %s %s  %s",
    tbl, v.field, string.lower(v.type), null, default, cmt, collate, string.lower(v.extra or ""), pos)
end

local function tablefield_compare(l, r)
    if l == r then return true end
    assert(l.field == r.field)
    for _, k in ipairs(field_attrs) do
        if k ~= "key" and l[k] ~= r[k] then
            return false
        end
    end
    return true
end

local function fields_re_index(tbl)
    for k, v in ipairs(tbl) do
        v.the_index = tostring(k)
    end
end

local function compare_fields(ret, name, lfields, rfields)
    while true do
        local over = true
        for k, lfield in ipairs(lfields) do
            local rfield = fieldfind(rfields, lfield.field)
            if not rfield then
                table.insert(ret, string.format("alter table `%s` drop column `%s`", name, lfield.field))
                table.remove(lfields, k)
                over = false
                break
            end
        end
        fields_re_index(lfields)
        if over then break end
    end

    while true do
        local over = true
        for k, rfield in ipairs(rfields) do
            local lfield = fieldfind(lfields, rfield.field)
            if not lfield then
                table.insert(ret, make_addfield(lfields, k, rfield))
            elseif not tablefield_compare(lfield, rfield) then
                table.insert(ret, make_changefield(lfields, k, rfield))
            end
        end
        fields_re_index(lfields)
        if over then break end
    end
end

local function gensql(left, right)
    local sdict = array2dict(left.table_list)
    local cdict = array2dict(right.table_list)
    local ret = {}
    for k in pairs(sdict) do
        if not cdict[k] then
            table.insert(ret, (string.format("drop table if exists `%s`", k)))
        else
            local stbl = left.table[k]
            local ctbl = right.table[k]
            compare_fields(ret, k, stbl, ctbl)
        end
    end
    for k in pairs(cdict) do
        if not sdict[k] then table.insert(ret, right.tablecreate[k]) end
    end

    local sdict = array2dict(left.proc_list)
    local cdict = array2dict(right.proc_list)

    for k in pairs(sdict) do
        if not cdict[k] then
            table.insert(ret, (string.format("drop procedure if exists `%s`", k)))
        else
            local sproc = left.proc[k]
            local cproc = right.proc[k]
            if sproc ~= cproc then
                table.insert(ret, (string.format("drop procedure if exists `%s`", k)))
                table.insert(ret, cproc)
            end
        end
    end
    for k in pairs(cdict) do
        if not sdict[k] then table.insert(ret, right.proc[k]) end
    end

    local sdict = array2dict(left.func_list)
    local cdict = array2dict(right.func_list)
    for k in pairs(sdict) do
        if not cdict[k] then
            table.insert(ret, (string.format("drop function if exists `%s`", k)))
        else
            local sfunc = left.func[k]
            local cfunc = right.func[k]
            if sfunc ~= cfunc then
                table.insert(ret, (string.format("drop function if exists `%s`", k)))
                table.insert(ret, cfunc)
            end
        end
    end
    for k in pairs(cdict) do
        if not sdict[k] then table.insert(ret, right.func[k]) end
    end
    return ret
end

function _M.save(ctx)
    local left = _M.newctx({}, ctx)
    _M.load(left)

    local ret = gensql(left, ctx)

    for _, v in ipairs(ret) do
        left.query(v)
    end
end

return _M
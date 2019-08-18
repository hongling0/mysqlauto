local _M={}
local field_attrs={"field","type","collation","null","key","default","extra","comment","the_index"}
local function showcolumn(ctx,tbl)
	local ret={}
	local sqlret=assert(ctx.query,string.format("show full columns from %s",tbl))
	for k,v in ipairs(sqlret) do
		local c={}
		for _k,_v in pairs(v) do
			c[string.lower(_k)]=_v
		end
		c.the_index=tostring(k)
		for _, key in ipairs(field_attrs) do
			if c[key] == nil then c[key] = "__NULL__" end
		end
		table.insert(ret,c)
	end
	return ret
end

local function showtables(ctx)
	local ret={}
	local sqlret=assert(ctx.query("show tables;"))
	for _,v in ipairs(sqlret) do
		for _,value in pairs(v) do
			table.insert(ret,value)
		end
	end
	return ret
end

local function showcreatetable(ctx,tbl)
	local sqlret=assert(ctx.query(string.format("show create table %s",tbl)))
	local str=sqlret[1]["Create Table"]
	str=string.gsub(str," AUTO_INCREMENT=%d*" , "")
	str=string.gsub(str," USING BTREE","USING HASH")
	str=string.gsub(str," ROW_FORMAT=DYNAMIC","")
	str=string.gsub(str," ROW_FORMAT=FIXED","")
	str=string.gsub(str," ROW_FORMAT=COMPACT","")
	str=string.gsub(str,"ENGINE=%w*","ENGINE=InnoDB")
	return str
end

local function showindex(ctx,tbl)
	local ret={}
	local sqlret=assert(ctx.query(string.format("show index from %s",tbl)))
	for _,v in ipairs(sqlret) do
		local c={}
		for _k,_v in pairs(v) do
			c[string.lower(_k)]=_v
		end
		table.insert(ret,c)
	end
	return ret
end

local function showcreateprocedure(query,proc)
	local sqlret=assert(query(string.format("show create procedure %s",proc)))
	local str=sqlret[1]["Create Procedure"]
	str=string.gsub(str, "CREATE(.*)PROCEDURE", "CREATE PROCEDURE")
	--str=string.format("DROP PROCEDURE IF EXISTS `%s`;\nDELIMITER $$\n%s\n$$\nDELIMITER ;",proc,str)
	return str
end

local function showcreatefunction(query,proc)
	local sqlret=assert(query(string.format("show create function %s",proc)))
	local str=sqlret[1]["Create Function"]
	str=string.gsub(str, "CREATE(.*)FUNCTION", "CREATE FUNCTION")
	--str=string.format("DROP PROCEDURE IF EXISTS `%s`;\nDELIMITER $$\n%s\n$$\nDELIMITER ;",proc,str)
	return str
end

local function showdatabase(query)
	local sqlret=assert(query("select database()"))
	return sqlret[1]["database()"]
end

local function showprocedures(query)
	local dbname=showdatabase(query)
	local sqlret=assert(query(string.format("select name,type from mysql.proc where db='%s'",dbname)))
	local ret,func={},{}
	for _,v in pairs(sqlret) do
		local name,type=v.name,v.type
		if type=='PROCEDURE' then
			table.insert(ret,name);
		else
			table.insert(func,name)
		end
	end
	return ret,func
end

function _M.read(ctx)
    ctx.table_list=showtables(ctx)
    ctx.table=setmetatable({},{__index=function(t,k)
        local r=showcolumn(ctx.query,k)
        t[k]=r
        return r
    end})
    ctx.tablecreate=setmetatable({},{__index=function(t,k)
        local r=showcreatetable(ctx.query,k)
        t[k]=r
        return r
    end})
    ctx.index=setmetatable({},{__index=function(t,k)
        local r=showindex(ctx.query,k)
        t[k]=r
        return r
	end})
	local proc,func=showprocedures(ctx.query)
    ctx.proc_list=proc
    ctx.proc=setmetatable({},{__index=function(t,k)
        local r=showcreateprocedure(ctx.query,k)
        t[k]=r
        return r
    end})
    ctx.func_list=func
    ctx.func=setmetatable({},{__index=function(t,k)
        local r=showcreatefunction(ctx.query,k)
        t[k]=r
        return r
    end})
    return ctx
end

return _M

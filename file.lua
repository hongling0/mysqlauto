local _M={}

local function getfile(ctx,f)
    return string.format("%s/%s.%s",ctx.dir,ctx.name,f)
end

local function writefile(name,str)
	local file=assert(io.open(name,"w"))
	file:write(str)
	file:close()
end

local function readfile(name)
	local file=assert(io.open(name,"r"))
	local str=file:read("*a")
	file:close()
	return str
end

local function readfilelines(name)
	local file=assert(io.open(name,"r"))
	local ret={}
	while true do
		local line=file:read("*l")
		if not line then break end
		table.insert(ret,line)
	end
	return ret
end

local function decode_table_column(tbls)
    local function decode_column(linestr)
        local ret={}
        for k,v in string.gmatch(linestr,"(%S+)='(.-)'") do
            ret[k]=v
        end
        return ret
    end
	local ret={}
	for _,v in pairs(tbls) do
		local r=decode_column(v)
		table.insert(ret,r)
	end
	return ret
end

local function decode_table_index(tbls)
    local function decode_column(linestr)
        local ret={}
        for k,v in string.gmatch(linestr,"(%S+)='(.-)'") do
            ret[k]=v
        end
        return ret
    end
	local ret={}
	for _,v in pairs(tbls) do
		local r=decode_column(v)
		local old = ret[r.key_name]
		if old then
			old.column_name = old.column_name..','..r.column_name
		else
			ret[r.key_name] = r
		end
	end
	return ret
end

function _M.read(ctx)
    ctx.table_list=readfilelines(getfile(ctx,"table.list"))
    ctx.table=setmetatable({},{__index=function(t,k)
        local str=readfilelines(getfile(ctx.name..".table."..k))
        local r=decode_table_column(str)
        t[k]=r
        return r
    end})
    ctx.tablecreate=setmetatable({},{__index=function(t,k)
        local r=readfile(getfile(ctx,"tablecreate."..k..".sql"))
        t[k]=r
        return r
    end})
    ctx.index=setmetatable({},{__index=function(t,k)
        local str=readfilelines(getfile(ctx,"index."..k))
        local r=decode_table_index(str)
        t[k]=r
        return r
    end})
    ctx.proc_list=readfilelines(getfile(ctx,"proc.list"))
    ctx.proc=setmetatable({},{__index=function(t,k)
        local r=readfile(getfile(ctx,"proc."..k..".sql"))
        t[k]=r
        return r
    end})
    ctx.func_list=readfilelines(getfile(ctx,"func.list"))
    ctx.func=setmetatable({},{__index=function(t,k)
        local r=readfile(getfile(ctx,"func."..k))
        t[k]=r
        return r
    end})
    return ctx
end

local function compare_table(old,new)
    local ks={}
    for k,v in pairs(old) do
        local nv=new[k]
        if not nv then return false end
        if v~=nv then
            return false
        elseif type(v)=="table" then
            if not compare_table(v,nv) then return false end
        end
    end
    return true
end

function _M.compare(ctx,new)
    local ret={}
    
end
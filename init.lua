local _M={}

_M.db=require "mysql.mysqlauto.db"
_M.file=require "mysql.mysqlauto.file"

function _M.newctx(opt)
    assert(opt.name)
    assert(opt.query)
    assert(opt.dir)
    local ret={}
    _M.db.newctx(ret,opt)
    _M.file.newctx(ret,opt)
    return ret
end

function _M.db2file(ctx)
    _M.db.load(ctx)
    _M.file.save(ctx)
end

function _M.file2db(ctx)
    _M.file.load(ctx)
    _M.db.save(ctx)
end

return _M
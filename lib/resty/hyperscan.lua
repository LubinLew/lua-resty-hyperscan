-- Copyright (C) LubinLew

local bit = require("bit")

local ffi = require('ffi')
local ffi_new  = ffi.new
local ffi_cast = ffi.cast

local nkeys = require('table.nkeys')
local table_new = require ("table.new")

-- module
local _M = {
    _VERSION = '0.2.1',
}

-- metatable
local mt = {
    __metatable = 0, --protected metatable
    __index = function(_, k) ngx.log(ngx.ERR, k .. " member not exist") return nil end,
    __newindex = function(_, k, v) error("Update Prohibited", 2) end
}


-----------------------------------------------------------------------------------------
----------------------------------- API Declaration  ------------------------------------
-----------------------------------------------------------------------------------------
ffi.cdef[[
typedef void whs_hdl_t;

/* test the current system architecture
 * Return:
 *     -1: This system does not support Hyperscan
 *      0: success
 */
int
whs_init(void);

/** create a new hyperscan block scan mode instance
 * Parameter:
 *    debug : 0(disable debug), other(enable debug)
 * Return:
 *   NULL  : Fail(Out of memory)
 *  Non-null : Success(return a handle)
 */
whs_hdl_t*
whs_block_create(const char *name, int debug);

/** Compiling Patterns for block mode
 * Return:
 *    0 : Success
 *   -1 : Error occurred
 */
int
whs_block_compile(whs_hdl_t* handle,
                const char *const *expressions,
                const unsigned int *flags,
                const unsigned int *ids,
                unsigned int count);

/** Scanning for Patterns for block mode
 * Return:
 *    0 : Success(not matched)
 *    1 : Matched
 *   -1 : Error occurred
 */
int
whs_block_scan(whs_hdl_t* handle,
                const char *data,
                unsigned int len,
                unsigned int *id,
                unsigned long long *from,
                unsigned long long *to);

/* destroy the hyperscan block scan mode instance */
void
whs_block_free(whs_hdl_t* handle);

/** create a new hyperscan vector scan mode instance
 * Parameter:
 *    debug : 0(disable debug), other(enable debug)
 * Return:
 *   NULL  : Fail(Out of memory)
 *  Non-null : Success(return a handle)
 */
 whs_hdl_t*
 whs_vector_create(const char* name, int debug);
 
 
 /** Compiling Patterns for vector mode
  * Return:
  *    0 : Success
  *   -1 : Error occurred
  */
 int
 whs_vector_compile(whs_hdl_t* handle,
                    const char* const* expressions,
                    const unsigned int* flags,
                    const unsigned int* ids,
                    unsigned int count);
 
 
 /** Scanning for Patterns for vector mode
  * Return:
  *    0 : Success(not matched)
  *    1 : Matched
  *   -1 : Error occurred
  */
 int
 whs_vector_scan(whs_hdl_t* handle,
                 const char** datas,
                 unsigned int* lens,
                 unsigned int count,
                 unsigned int* id,
                 unsigned int* dataIndex,
                 unsigned long long* to);
 
 
 /* destroy the hyperscan vector scan mode instance */
 void
 whs_vector_free(whs_hdl_t* handle);
]]

-----------------------------------------------------------------------------------------
----------------------------------- Core Code -------------------------------------------
-----------------------------------------------------------------------------------------
local so_name = "libwhs.so"
local whs

-- load library
for k,_ in string.gmatch(package.cpath, "[^;]+") do
    local so_path = string.match(k, "(.*/)")
    if so_path then
        so_path = so_path .. so_name
        local f = io.open(so_path)
        if f ~= nil then
            io.close(f)
            whs = ffi.load(so_path)
        end
    end
end

if not whs then
    return nil, "load shared library libwhs.so failed"
end

if whs.whs_init() ~= 0 then
    return nil, "This system not spport Hyperscan"
end



--Compile flag
local compile_bit_flag = {
    ['i'] = 1,    --HS_FLAG_CASELESS         Set case-insensitive matching
    ['d'] = 2,    --HS_FLAG_DOTALL           Matching a `.` will not exclude newlines.
    ['m'] = 4,    --HS_FLAG_MULTILINE        Set multi-line anchoring.
    ['s'] = 8,    --HS_FLAG_SINGLEMATCH      Set single-match only mode.
    ['e'] = 16,   --HS_FLAG_ALLOWEMPTY       Allow expressions that can match against empty buffers.
    ['u'] = 32,   --HS_FLAG_UTF8             Enable UTF-8 mode for this expression.
    ['p'] = 64,   --HS_FLAG_UCP              Enable Unicode property support for this expression.
    ['f'] = 128,  --HS_FLAG_PREFILTER        Enable prefiltering mode for this expression.
    ['l'] = 256,  --HS_FLAG_SOM_LEFTMOST     Enable leftmost start of match reporting.
    ['c'] = 512,  --HS_FLAG_COMBINATION      Logical combination.
    ['q'] = 1024, --HS_FLAG_QUIET            Don't do any match reporting.
}

local function _translate_compile_flags(str)
    if type(str) ~= 'string' then
        return -1, "Invalid flags type: '" .. type(str) .. "', should be string."
    end

    local flags = 0
    local flag_bytes = {str:byte(1, #str)}
    for i = 1, #flag_bytes do
        local byte = string.char(flag_bytes[i])
        local flag = compile_bit_flag[byte]
        if not flag then
            return -1, "Invalid compile flag '" .. flag_bytes[i] .. "' !"
        else
            flags = bit.bor(flags, flag)
        end
    end

    return flags
end


local function _whs_block_compile(self, patterns)
    -- Parameter Check
    if type(patterns) ~= "table" then
        return false, "#1 paramter should be a table !"
    end
    local count = nkeys(patterns)
    if count < 1 then
        return false, "No Patterns !"
    end

    local expressions = ffi_new('const  char*[?]', count)
    local ids         = ffi_new('unsigned int[?]', count)
    local flags       = ffi_new('unsigned int[?]', count)

    local index = 0
    for _,v in pairs(patterns) do
        ids[index]         = v.id
        flags[index]       = _translate_compile_flags(v.flag)
        expressions[index] = ffi_cast('char*', v.pattern)
        index = index + 1
    end

    local ret = whs.whs_block_compile(self.handle, expressions, flags,  ids, count)
    if ret ~= 0 then
        return false, "compile failed"
    end

    return true
end


local function _whs_block_scan(self, string)
    local id    = ffi_new('unsigned int[1]')
    local from  = ffi_new('unsigned long long[1]')
    local to    = ffi_new('unsigned long long[1]')
    local ret = whs.whs_block_scan(self.handle, string, string.len(string), id, from, to)
    if ret == 1 then
        return true, tonumber(id[0]), tonumber(from[0]), tonumber(to[0])
    end

    return false
end

function _M.block_new(name, debug)
    if not whs then
        return nil, "libwhs.so load failed !"
    end

    if type(name) ~= "string" then
        return nil, "Parameter 'name' should be a string"
    end

    if type(debug) == nil then
        debug = false
    end

    if type(debug) ~= "boolean" then
        return nil, "Parameter 'debug' should be a boolean value"
    end

    local _whs_handle = whs.whs_block_create(name, debug)
    if not _whs_handle then
        return nil, "out of memeory"
    end
    ffi.gc(_whs_handle,whs.whs_block_free)

    local newtab = setmetatable({
            name         =  name,
            handle       = _whs_handle,
            compile      = _whs_block_compile,
            scan         = _whs_block_scan,
        }, mt)

    return newtab
end

local function _whs_vector_compile(self, patterns)
    -- Parameter Check
    if type(patterns) ~= "table" then
        return false, "#1 paramter should be a table !"
    end
    local count = nkeys(patterns)
    if count < 1 then
        return false, "No Patterns !"
    end

    local expressions = ffi_new('const  char*[?]', count)
    local ids         = ffi_new('unsigned int[?]', count)
    local flags       = ffi_new('unsigned int[?]', count)

    local index = 0
    for _,v in pairs(patterns) do
        ids[index]         = v.id
        flags[index]       = _translate_compile_flags(v.flag)
        expressions[index] = ffi_cast('char*', v.pattern)
        index = index + 1
    end

    local ret = whs.whs_vector_compile(self.handle, expressions, flags,  ids, count)
    if ret ~= 0 then
        return false, "compile failed"
    end

    return true
end


local function _whs_vector_scan(self, strings)
    if type(strings) ~= "table" then
        strings = {strings}
    end
    local count = #strings
    local lens = table_new(count, 0)
    for i, v in ipairs(strings) do
        lens[i] = #v
    end

    local id    = ffi_new('unsigned int[1]')
    local dataindex  = ffi_new('unsigned int[1]')
    local to    = ffi_new('unsigned long long[1]')

    local ret = whs.whs_vector_scan(self.handle, strings, lens, count, id, dataindex, to)
    if ret == 1 then
        return true, tonumber(id[0]), tonumber(dataindex[0] + 1), tonumber(to[0])
    end

    return false
end

function _M.vector_new(name, debug)
    if not whs then
        return nil, "libwhs.so load failed !"
    end

    if type(name) ~= "string" then
        return nil, "Parameter 'name' should be a string"
    end

    if type(debug) == nil then
        debug = false
    end

    if type(debug) ~= "boolean" then
        return nil, "Parameter 'debug' should be a boolean value"
    end

    local _whs_handle = whs.whs_vector_create(name, debug)
    if not _whs_handle then
        return nil, "out of memeory"
    end
    ffi.gc(_whs_handle,whs.whs_vector_free)


    local newtab = setmetatable({
            name         =  name,
            handle       = _whs_handle,
            compile      = _whs_vector_compile,
            scan         = _whs_vector_scan,
        }, mt)

    return newtab
end

-----------------------------------------------------------------------------------------
return _M

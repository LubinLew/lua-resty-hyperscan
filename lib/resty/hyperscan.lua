-- Copyright (C) LubinLew

local bit = require("bit")

local ffi      = require('ffi')
local ffi_new  = ffi.new
local ffi_cast = ffi.cast

local nkeys = require('table.nkeys')
local table_new = require("table.new")

---@class Hyperscan.lib
local _M = {
    _VERSION = '0.3',
}

ffi.cdef[[
    void	 free(void *);
]]
-----------------------------------------------------------------------------------------
----------------------------------- API Declaration  ------------------------------------
-----------------------------------------------------------------------------------------
ffi.cdef [[
    typedef struct _whs_match {
        unsigned int id;
        unsigned long long from;
        unsigned long long to;
        unsigned int flags;
    } whs_match_t;
    
    typedef struct _whs_multi_match {
        whs_match_t* matchs;
        uint16_t len;
        uint16_t cur;
    } whs_multi_match_t;
    
    typedef struct _whs_hdl whs_hdl_t;
    
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
    whs_hdl_t *
    whs_block_create(const char *name, int debug);
    
    
    /** Compiling Patterns for block mode
     * Return:
     *    0 : Success
     *   -1 : Error occurred
     */
    int
    whs_block_compile(whs_hdl_t *handle,
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
    whs_block_scan(whs_hdl_t *handle,
                   const char *data,
                   unsigned int len,
                   unsigned int *id,
                   unsigned long long *from,
                   unsigned long long *to);
    
    int
    whs_block_scan_multi_match(whs_hdl_t* handle,
        const char* data,
        unsigned int len,
        whs_multi_match_t* ctx);
    
    
    /* destroy the hyperscan block scan mode instance */
    void
    whs_block_free(whs_hdl_t *handle);
    
    
    /** create a new hyperscan vector scan mode instance
     * Parameter:
     *    debug : 0(disable debug), other(enable debug)
     * Return:
     *   NULL  : Fail(Out of memory)
     *  Non-null : Success(return a handle)
     */
    whs_hdl_t *
    whs_vector_create(const char *name, int debug);
    
    
    /** Compiling Patterns for vector mode
     * Return:
     *    0 : Success
     *   -1 : Error occurred
     */
    int
    whs_vector_compile(whs_hdl_t *handle,
                       const char *const *expressions,
                       const unsigned int *flags,
                       const unsigned int *ids,
                       unsigned int count);
    
    
    /** Scanning for Patterns for vector mode
     * Return:
     *    0 : Success(not matched)
     *    1 : Matched
     *   -1 : Error occurred
     */
    int
    whs_vector_scan(whs_hdl_t *handle,
                    const char **datas,
                    unsigned int *lens,
                    unsigned int count,
                    unsigned int *id,
                    unsigned int *dataIndex,
                    unsigned long long *to);
    
    int
    whs_vector_scan_multi_match(whs_hdl_t* handle,
        const char** datas,
        unsigned int* lens,
        unsigned int count,
        whs_multi_match_t* ctx);
    
    /* destroy the hyperscan vector scan mode instance */
    void
    whs_vector_free(whs_hdl_t *handle);
    
    int whs_serialize_database(whs_hdl_t *handle, char** bytes, size_t* len);
    
    whs_hdl_t* whs_deserialize_database(const char* name, const char *bytes, size_t len);
]]

local whs_multi_match_t = ffi.typeof('whs_multi_match_t')
local whs_match_t       = ffi.typeof('whs_match_t[?]')

---@class Hyperscan.whs_match
---@field id integer
---@field from integer
---@field to integer
---@field flags integer

---@class Hyperscan.whs_multi_match
---@field matchs Hyperscan.whs_match[]
---@field len integer
---@field cur integer

---@return Hyperscan.whs_multi_match
local function create_whs_multi_match(len)
    ---@type Hyperscan.whs_multi_match
    local whs_multi_match = ffi.new(whs_multi_match_t)
    whs_multi_match.matchs = ffi.new(whs_match_t, len)
    whs_multi_match.len = len
    return whs_multi_match
end

-----------------------------------------------------------------------------------------
----------------------------------- Core Code -------------------------------------------
-----------------------------------------------------------------------------------------
local whs
do
    local so_name = "libwhs.so"

    -- load library
    for k, _ in string.gmatch(package.cpath, "[^;]+") do
        local so_path = string.match(k, "(.*/)")
        if so_path then
            so_path = so_path .. so_name
            local f = io.open(so_path)
            if f ~= nil then
                io.close(f)
                whs = ffi.load(so_path)
                break
            end
        end
    end

    if not whs then
        error("load shared library libwhs.so failed")
    end

    if whs.whs_init() ~= 0 then
        error("This system not spport Hyperscan")
    end
end


--Compile flag
local compile_bit_flag = {
    ['i'] = 1, --HS_FLAG_CASELESS         Set case-insensitive matching
    ['d'] = 2, --HS_FLAG_DOTALL           Matching a `.` will not exclude newlines.
    ['m'] = 4, --HS_FLAG_MULTILINE        Set multi-line anchoring.
    ['s'] = 8, --HS_FLAG_SINGLEMATCH      Set single-match only mode.
    ['e'] = 16, --HS_FLAG_ALLOWEMPTY       Allow expressions that can match against empty buffers.
    ['u'] = 32, --HS_FLAG_UTF8             Enable UTF-8 mode for this expression.
    ['p'] = 64, --HS_FLAG_UCP              Enable Unicode property support for this expression.
    ['f'] = 128, --HS_FLAG_PREFILTER        Enable prefiltering mode for this expression.
    ['l'] = 256, --HS_FLAG_SOM_LEFTMOST     Enable leftmost start of match reporting.
    ['c'] = 512, --HS_FLAG_COMBINATION      Logical combination.
    ['q'] = 1024, --HS_FLAG_QUIET            Don't do any match reporting.
}

local function _translate_compile_flags(str)
    if type(str) ~= 'string' then
        return -1, "Invalid flags type: '" .. type(str) .. "', should be string."
    end

    local flags = 0
    local flag_bytes = { str:byte(1, #str) }
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


---@class Hyperscan.pattern
---@field id integer
---@field flag string
---@field pattern string

---@param patterns Hyperscan.pattern[]
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
    for _, v in pairs(patterns) do
        ids[index]         = v.id
        flags[index]       = _translate_compile_flags(v.flag)
        expressions[index] = ffi_cast('char*', v.pattern)
        index              = index + 1
    end

    local ret = whs.whs_block_compile(self.handle, expressions, flags, ids, count)
    if ret ~= 0 then
        return false, "compile failed"
    end

    return true
end

local function _whs_block_scan(self, string)
    local id   = ffi_new('unsigned int[1]')
    local from = ffi_new('unsigned long long[1]')
    local to   = ffi_new('unsigned long long[1]')
    local ret  = whs.whs_block_scan(self.handle, string, #string, id, from, to)
    if ret == 1 then
        return true, tonumber(id[0]), tonumber(from[0]), tonumber(to[0])
    end

    return false
end

local function _whs_block_scan_multi_match(self, maxmatch, string)
    local whs_multi_match = create_whs_multi_match(maxmatch)
    local ret = whs.whs_block_scan_multi_match(self.handle, string, #string, whs_multi_match)
    if ret == 1 or ret == 0 then
        local t = table_new(whs_multi_match.cur, 0)
        for i = 1, whs_multi_match.cur do
            t[i] = whs_multi_match.matchs[i - 1].id
        end
        return true, t
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

    if not debug then
        debug = false
    end

    if type(debug) ~= "boolean" then
        return nil, "Parameter 'debug' should be a boolean value"
    end

    local _whs_handle = whs.whs_block_create(name, debug)
    if not _whs_handle then
        return nil, "out of memeory"
    end
    ffi.gc(_whs_handle, whs.whs_block_free)

    ---@class Hyperscan
    return {
        name       = name,
        handle     = _whs_handle,
        compile    = _whs_block_compile,
        scan       = _whs_block_scan,
        multi_scan = _whs_block_scan_multi_match,
    }
end

---@param patterns Hyperscan.pattern[]
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
    for _, v in pairs(patterns) do
        ids[index]         = v.id
        flags[index]       = _translate_compile_flags(v.flag)
        expressions[index] = ffi_cast('char*', v.pattern)
        index              = index + 1
    end

    local ret = whs.whs_vector_compile(self.handle, expressions, flags, ids, count)
    if ret ~= 0 then
        return false, "compile failed"
    end

    return true
end

local function _whs_vector_scan(self, strings)
    if type(strings) ~= "table" then
        strings = { strings }
    end
    local count = #strings
    local lens = table_new(count, 0)
    for i, v in ipairs(strings) do
        lens[i] = #v
    end

    strings         = ffi_new("const char* [?]", count, strings)
    lens            = ffi_new("unsigned int[?]", count, lens)
    local id        = ffi_new('unsigned int[1]')
    local dataindex = ffi_new('unsigned int[1]')
    local to        = ffi_new('unsigned long long[1]')

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

    if not debug then
        debug = false
    end

    if type(debug) ~= "boolean" then
        return nil, "Parameter 'debug' should be a boolean value"
    end

    local _whs_handle = whs.whs_vector_create(name, debug)
    if not _whs_handle then
        return nil, "out of memeory"
    end
    ffi.gc(_whs_handle, whs.whs_vector_free)

    return {
        name    = name,
        handle  = _whs_handle,
        compile = _whs_vector_compile,
        scan    = _whs_vector_scan,
    }
end

local function _whs_vector_scan_multi_match(self, maxmatch, string)
    local whs_multi_match = create_whs_multi_match(maxmatch)
    local ret = whs.whs_block_scan_multi_match(self.handle, string, #string, whs_multi_match)
    if ret == 1 then
        local t = table_new(whs_multi_match.cur, 0)
        for i = 1, whs_multi_match.cur + 1, 1 do
            t[i] = {
                id = whs_multi_match.matchs[i - 1].id,
            }
        end
        return true, t
    end

    return false
end

---@param t 'vector' | 'block'
function _M.deserialize_database(name, t, data)
    if type(name) ~= 'string' then
        return nil, "Parameter 'name' should be a string"
    end
    if type(data) ~= 'string' then
        return nil, "Parameter 'data' should be a string"
    end
    local _whs_handle = whs.whs_deserialize_database(name, data, #data)
    if not _whs_handle then
        error("d")
        return nil, "out of memeory"
    end
    ffi.gc(_whs_handle, whs.whs_vector_free)

    return {
        name = name,
        handle = _whs_handle,
        scan = t == 'vector' and _whs_vector_scan or _whs_block_scan,
        multi_scan = t == 'vector' and _whs_vector_scan_multi_match or _whs_block_scan_multi_match,
    }
end

function _M.serialize_database(hs)
    local bytes = ffi.new("char*[1]")
    local len = ffi.new("size_t[1]")
    local err = whs.whs_serialize_database(hs.handle, bytes, len)
    if err == 0 then
        ffi.gc(bytes[0],ffi.C.free);
        return ffi.string(bytes[0], len[0])
    end
end

-----------------------------------------------------------------------------------------
return _M

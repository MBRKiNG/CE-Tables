-- ============================================================================
-- AIF Pro - Module: Lua Transpiler & Smart Code Converter
-- File: AIF/AIF_LuaTranspiler.lua
-- ============================================================================

local AIF_LuaTranspiler = {}

-- Generates a 32-bit DJB2 hash safely using universal math (No bitwise operators)
local function GenerateHash(str)
    local hash = 5381
    for i = 1, #str do
        hash = (hash * 33) + string.byte(str, i)
        -- Safe 32-bit modulo for universal Lua/LuaJIT compatibility
        hash = hash % 4294967296
    end
    -- Return as an 8-character uppercase Hex string
    return string.format("%08X", math.floor(hash))
end

-- Converts Auto Assembler code into a flawless, native CE Table Lua Script
function AIF_LuaTranspiler.ConvertAAToLua(aaCode, baseTitle)
    if not aaCode or aaCode == "" then return "-- Error: Empty Auto Assembler Code" end
    
    -- === SAFEGUARD ===
    -- Prevents double-wrapping if the script has already been converted
    if aaCode:upper():find("{$LUA}", 1, true) then
        print("[AIF-Lua] Safeguard active: Script is already a Lua script. Conversion aborted.")
        if showMessage then
            showMessage("Conversion Aborted:\n\nThis script is already a Lua script.\nNo further conversion is possible.")
        end
        return aaCode -- Returns the original code untouched
    end
    -- =============================
    
    -- Clean carriage returns (\r\n) to prevent string corruption
    local cleanCode = aaCode:gsub("\r\n", "\n"):gsub("\r", "\n")
    
    -- Cross-platform timestamp (seconds since epoch) + CPU clock for maximum uniqueness
    local timeStamp = tostring(os.time()) .. "_" .. tostring(os.clock())
    
    -- Generate unique Hash ID based on the actual AA code content AND the exact time
    local hashID = GenerateHash(cleanCode .. "_" .. timeStamp)
    local scriptTitle = (baseTitle or "AIF_Script") .. "_" .. hashID
    
    -- Smart extraction of ENABLE and DISABLE blocks
    local enableBlock = ""
    local disableBlock = ""
    
    local upperCode = cleanCode:upper()
    -- Using % to escape brackets in Lua's pattern matching
    local enStart, enEnd = upperCode:find("%[ENABLE%]")
    local disStart, disEnd = upperCode:find("%[DISABLE%]")
    
    if enStart and disStart then
        enableBlock = cleanCode:sub(enEnd + 1, disStart - 1)
        disableBlock = cleanCode:sub(disEnd + 1)
    elseif enStart then
        enableBlock = cleanCode:sub(enEnd + 1)
    elseif disStart then
        disableBlock = cleanCode:sub(disEnd + 1)
    else
        enableBlock = cleanCode -- Default to enable if tags are missing
    end
    
    -- --- STRIP ORIGINAL CODE FROM DISABLE BLOCK ---
    local disableLower = disableBlock:lower()
    -- Matches standard CE "// Original code", AIF "// --- Original Code", or "{ Original code"
    local origIndex = disableLower:find("//%s*-*%s*original%s*code")
    if not origIndex then
        origIndex = disableLower:find("{%s*original%s*code")
    end
    
    if origIndex then
        disableBlock = disableBlock:sub(1, origIndex - 1)
    end
    
    -- Trim trailing and leading whitespace
    local function trim(s) return s:match("^%s*(.-)%s*$") or "" end
    enableBlock = trim(enableBlock)
    disableBlock = trim(disableBlock)
    
    -- ========================================================================
    -- === NEW: LUA WILDCARD (*) PROTECTION MECHANISM ===
    -- ========================================================================
    local registeredSymbols = {}
    local allocatedSymbols = {}

    -- Find all registersymbol(sym1 sym2 ...) in ENABLE block
    for reg_match in enableBlock:gmatch("registersymbol%s*%(%s*([^%)]+)%)") do
        for name in reg_match:gmatch("(%S+)") do
            registeredSymbols[name] = true
        end
    end

    -- Find all alloc(name, size...) and globalalloc(name, size...) in ENABLE block
    for alloc_match in enableBlock:gmatch("alloc%s*%(%s*([^,%)]+)") do
        local name = alloc_match:match("^%s*(%S+)")
        if name then allocatedSymbols[name] = true end
    end
    for alloc_match in enableBlock:gmatch("globalalloc%s*%(%s*([^,%)]+)") do
        local name = alloc_match:match("^%s*(%S+)")
        if name then allocatedSymbols[name] = true end
    end

    -- Replace unregistersymbol(*) dynamically
    if disableBlock:find("unregistersymbol%s*%(%s*%*%s*%)") then
        local unregLines = {}
        for name in pairs(registeredSymbols) do
            table.insert(unregLines, "  unregistersymbol(" .. name .. ")")
        end
        local unregStr = table.concat(unregLines, "\n")
        if unregStr == "" then unregStr = "  // No registered symbols found for wildcard unregister" end
        
        disableBlock = disableBlock:gsub("unregistersymbol%s*%(%s*%*%s*%)", function() return unregStr end)
    end

    -- Replace dealloc(*) dynamically
    if disableBlock:find("dealloc%s*%(%s*%*%s*%)") then
        local deallocLines = {}
        for name in pairs(allocatedSymbols) do
            table.insert(deallocLines, "  dealloc(" .. name .. ")")
        end
        local deallocStr = table.concat(deallocLines, "\n")
        if deallocStr == "" then deallocStr = "  // No allocated symbols found for wildcard dealloc" end
        
        disableBlock = disableBlock:gsub("dealloc%s*%(%s*%*%s*%)", function() return deallocStr end)
    end
    -- ========================================================================
    
    -- Create 100% unique, dynamic variable names based on the time-hash
    local varEnable = "aa_script_on_" .. hashID
    local varDisable = "aa_script_off_" .. hashID
    
    local luaScript = {}
    table.insert(luaScript, "{$LUA}")
    table.insert(luaScript, "if syntaxcheck then return end")
    table.insert(luaScript, "")
    table.insert(luaScript, "-- ============================================================================")
    table.insert(luaScript, string.format("-- AIF Pro - Auto-Generated Lua Script: %s", scriptTitle))
    table.insert(luaScript, "-- Native CE Table Checkbox Compatible & Fully Isolated via Time-Hash")
    table.insert(luaScript, "-- Includes Wildcard (*) Deallocation Protection")
    table.insert(luaScript, "-- ============================================================================")
    table.insert(luaScript, "")
    
    -- ENABLE SECTION
    table.insert(luaScript, "[ENABLE]")
    if enableBlock ~= "" then
        table.insert(luaScript, "local " .. varEnable .. " = [===[\n" .. enableBlock .. "\n]===]")
        table.insert(luaScript, "local ok, err = autoAssemble(" .. varEnable .. ")")
        table.insert(luaScript, "if not ok then")
        table.insert(luaScript, "    error('AA Injection Failed: ' .. tostring(err))")
        table.insert(luaScript, "end")
    else
        table.insert(luaScript, "-- No ENABLE code found in original script")
    end
    table.insert(luaScript, "")
    
    -- DISABLE SECTION
    table.insert(luaScript, "[DISABLE]")
    if disableBlock ~= "" then
        table.insert(luaScript, "local " .. varDisable .. " = [===[\n" .. disableBlock .. "\n]===]")
        table.insert(luaScript, "local ok, err = autoAssemble(" .. varDisable .. ")")
        table.insert(luaScript, "if not ok then")
        table.insert(luaScript, "    print('AA Disable Warning: ' .. tostring(err))")
        table.insert(luaScript, "end")
    else
        table.insert(luaScript, "-- No DISABLE code found in original script")
    end

    return table.concat(luaScript, "\n")
end

-- Expose to global namespace
_G.AIF = _G.AIF or {}
_G.AIF.LuaTranspiler = AIF_LuaTranspiler
return AIF_LuaTranspiler

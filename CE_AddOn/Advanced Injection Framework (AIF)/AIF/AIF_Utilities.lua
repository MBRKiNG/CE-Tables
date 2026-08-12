-- ============================================================================
-- AIF Pro - Module: Utilities & Helpers
-- File: AIF/AIF_Utilities.lua
-- ============================================================================

local AIF_Utilities = {}

-- Safely retrieves a symbol name from a memory address, or returns the hex string
function AIF_Utilities.SafeGetName(addr)
    local n = getNameFromAddress(addr)
    return (n and n ~= "") and n or string.format("%X", addr)
end

-- Sanitizes user input for symbol names to prevent Auto-Assembler syntax errors
function AIF_Utilities.SanitizeSymbol(name)
    if not name or name == "" then return nil end
    local cleaned = name:gsub("%s+", "_"):gsub("[^%w_]", "")
    if cleaned == "" then return nil end
    -- Prevent symbols from starting with a number
    if cleaned:match("^%d") then cleaned = "s_" .. cleaned end
    return cleaned
end

-- Generates a symbolic disassembly string by replacing raw hex addresses with registered symbol names
function AIF_Utilities.GetSymbolicDisasm(addr)
    local raw = disassemble(addr)
    if not raw or raw == "" then return "" end
    local result = raw
    
    -- Parse string for potential hex addresses (8 or more hex characters)
    for hexAddr in raw:gmatch("%x%x%x%x%x%x%x%x+") do
        local numAddr = tonumber(hexAddr, 16)
        if numAddr then
            local symName = getNameFromAddress(numAddr)
            if symName and symName ~= "" and symName ~= string.format("%X", numAddr) then
                result = result:gsub(hexAddr, symName)
            end
        end
    end
    
    return result
end

-- Expose module to the global AIF namespace
_G.AIF = _G.AIF or {}
_G.AIF.Utilities = AIF_Utilities
return AIF_Utilities

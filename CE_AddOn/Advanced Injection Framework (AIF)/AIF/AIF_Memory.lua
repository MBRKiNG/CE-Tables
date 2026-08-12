-- ============================================================================
-- AIF Pro - Module: Memory & Resource Management
-- File: AIF/AIF_Memory.lua
-- ============================================================================

local AIF_Memory = {}

-- Generates targeted or wildcard resource cleanup blocks based on config
function AIF_Memory.GenerateExplicitDisableBlock(registeredSymbols, allocatedMemory)
    local lines = {}
    local cfg = _G.AIF and _G.AIF.Config or { UseWildcards = true }
    
    table.insert(lines, "  // --- Resource Cleanup ---")
    
    if cfg.UseWildcards then
        table.insert(lines, "  unregistersymbol(*)")
        table.insert(lines, "  dealloc(*)")
    else
        if registeredSymbols and type(registeredSymbols) == "table" then
            for _, sym in ipairs(registeredSymbols) do
                if sym and sym ~= "" then
                    table.insert(lines, string.format("  unregistersymbol(%s)", sym))
                end
            end
        end
        
        if allocatedMemory and type(allocatedMemory) == "table" then
            for _, alloc in ipairs(allocatedMemory) do
                if alloc and alloc ~= "" then
                    table.insert(lines, string.format("  dealloc(%s)", alloc))
                end
            end
        end
    end
    
    return table.concat(lines, "\n")
end

-- Generates strict allocation scripts, optionally forcing near-allocations
function AIF_Memory.GenerateAllocations(allocations, targetAddress, forceNear)
    local lines = {}
    
    if not allocations or type(allocations) ~= "table" then
        return ""
    end
    
    for _, alloc in ipairs(allocations) do
        local name = alloc.name or "newmem"
        local size = alloc.size or "$1000"
        
        if forceNear and targetAddress and targetAddress ~= "" then
            table.insert(lines, string.format("alloc(%s, %s, %s)", name, size, targetAddress))
        else
            table.insert(lines, string.format("alloc(%s, %s)", name, size))
        end
    end
    
    return table.concat(lines, "\n")
end

-- Registers symbols for proper tracking during script enablement
function AIF_Memory.GenerateRegisterBlock(symbols)
    local lines = {}
    
    if not symbols or type(symbols) ~= "table" then
        return ""
    end
    
    local combinedSymbols = {}
    for _, sym in ipairs(symbols) do
        if type(sym) == "table" and sym.name and sym.address then
            table.insert(combinedSymbols, string.format("%s %s", sym.name, sym.address))
        elseif type(sym) == "string" and sym ~= "" then
            table.insert(combinedSymbols, sym)
        end
    end
    
    if #combinedSymbols > 0 then
        table.insert(lines, string.format("registersymbol(%s)", table.concat(combinedSymbols, " ")))
    end
    
    return table.concat(lines, "\n")
end

-- Expose module to the global AIF namespace
_G.AIF = _G.AIF or {}
_G.AIF.Memory = AIF_Memory
return AIF_Memory

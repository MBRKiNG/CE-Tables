-- ============================================================================
-- AIF Pro - Module: Validator (Preflight Analysis)
-- File: AIF/AIF_Validator.lua
-- ============================================================================

local AIF_Validator = {}

-- Performs a preflight analysis of the target injection site
-- baseAddress: The memory address where the hook will be placed
-- requiredBytes: The minimum number of bytes required for the jump (e.g., 5 or 14)
function AIF_Validator.ValidateInjectionSite(baseAddress, requiredBytes)
    local result = {
        isSafe = true,
        warnings = {},
        stolenInstructions = {},
        totalSize = 0,
        requiresNearAlloc = false
    }
    
    local currentAddress = baseAddress
    local is64Bit = targetIs64Bit()
    
    while result.totalSize < requiredBytes do
        local instSize = getInstructionSize(currentAddress)
        
        if not instSize or instSize == 0 then
            result.isSafe = false
            table.insert(result.warnings, string.format("CRITICAL: Invalid or unreadable opcode at %X.", currentAddress))
            break
        end
        
        -- Decode instruction using the AIF Decoder module if available
        local instData
        if _G.AIF and _G.AIF.Decoder then
            instData = _G.AIF.Decoder.DecodeInstruction(currentAddress, is64Bit)
        else
            -- Minimal fallback if the decoder module is unavailable
            instData = {
                address = currentAddress,
                size = instSize,
                rawText = disassemble(currentAddress) or "",
                isRelativeJump = false,
                isRelativeCall = false,
                isRIPRelative = false
            }
        end
        
        table.insert(result.stolenInstructions, instData)
        
        local lowerText = instData.rawText:lower()
        
        -- Prevent hooks that would overwrite a return instruction, causing stack corruption
        if lowerText:match("^ret") or lowerText:match("^iret") then
            result.isSafe = false
            table.insert(result.warnings, string.format("CRITICAL: Return instruction found inside stolen bytes block at %X.", currentAddress))
        end
        
        -- Check for relative control flow or RIP addressing requiring near-allocation (+/- 2GB bounds)
        if instData.isRelativeJump or instData.isRelativeCall or instData.isRIPRelative or lowerText:find("rip") then
            result.requiresNearAlloc = true
            table.insert(result.warnings, string.format("INFO: Relative addressing detected at %X. Near-allocation required.", currentAddress))
        end
        
        result.totalSize = result.totalSize + instSize
        currentAddress = currentAddress + instSize
    end
    
    -- Additional heuristic safety check
    if result.totalSize > 32 then
        table.insert(result.warnings, "WARNING: Hook size exceeds 32 bytes. Ensure the target function bounds are not exceeded.")
    end
    
    return result
end

-- Expose module to the global AIF namespace
_G.AIF = _G.AIF or {}
_G.AIF.Validator = AIF_Validator
return AIF_Validator

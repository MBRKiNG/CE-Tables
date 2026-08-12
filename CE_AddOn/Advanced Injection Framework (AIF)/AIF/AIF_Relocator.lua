-- ============================================================================
-- AIF Pro - Module: Relocator
-- File: AIF/AIF_Relocator.lua
-- ============================================================================

local AIF_Relocator = {}

local function FormatTextWithModuleOffset(text)
    if not text then return "" end
    return text:gsub("(%f[%x]%x%x%x%x%x%x%x?%x?(%f[^%x]))", function(hex)
        local num = tonumber(hex, 16)
        if num and num > 0x10000 then
            local modules = enumModules()
            if modules then
                for _, m in ipairs(modules) do
                    if num >= m.Address and num < (m.Address + m.Size) then
                        local offset = num - m.Address
                        return string.format('"%s"+%X', m.Name, offset)
                    end
                end
            end
            local sym = getNameFromAddress(num)
            if sym and sym ~= "" and not sym:match("^%x+$") then
                if sym:sub(1, 1) == '"' and sym:sub(-1) == '"' then
                    return sym:sub(2, -2)
                end
                return sym
            end
        end
        return hex
    end)
end

function AIF_Relocator.BuildRelocationBlock(baseAddress, decodedInstructions, symbolInput, skipCount)
    local lines = {}
    local stats = {
        relocatedCount = 0,
        ripCount = 0,
        warnings = {}
    }

    skipCount = skipCount or 0

    for i = 1, #decodedInstructions do
        local inst = decodedInstructions[i]
        
        if i > skipCount then
            local offset = inst.address - baseAddress
            local symAddr = (offset > 0) and string.format("%s+%X", symbolInput, offset) or symbolInput
            local rawText = FormatTextWithModuleOffset(inst.rawText or "")

            local comment = ""
            if inst.isRelativeJump or inst.isRelativeCall then
                stats.relocatedCount = stats.relocatedCount + 1
                comment = "  // Relocated Control Flow: " .. rawText
            elseif inst.isRIPRelative then
                stats.ripCount = stats.ripCount + 1
                comment = "  // Relocated RIP-Relative: " .. rawText
            else
                comment = "  // Original: " .. rawText
            end

            if _G.AIF and _G.AIF.Config and _G.AIF.Config.UseComments == false then
                comment = ""
            end

            table.insert(lines, string.format("  reassemble(%s)%s", symAddr, comment))
        end
    end

    return table.concat(lines, "\n"), stats
end

function AIF_Relocator.RequiresNearAllocation(decodedInstructions)
    for i = 1, #decodedInstructions do
        local inst = decodedInstructions[i]
        if inst.isRIPRelative or inst.isRelativeJump or inst.isRelativeCall then
            return true
        end
    end
    return false
end

_G.AIF.Relocator = AIF_Relocator
return AIF_Relocator

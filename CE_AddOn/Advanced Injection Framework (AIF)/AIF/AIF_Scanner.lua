-- ============================================================================
-- AIF Pro - Module: Memory Scanner & AOB Generator
-- File: AIF/AIF_Scanner.lua
-- ============================================================================

local AIF_Scanner = {}

local function DebugLog(msg)
    if _G.AIF and _G.AIF.Config and _G.AIF.Config.Debug then
        print("[AIF-PRO Scanner] " .. tostring(msg))
    end
end

-- Retrieves the address and size of the module containing the target address
function AIF_Scanner.GetModuleBounds(address)
    DebugLog(string.format("Scanning for module bounds containing address: %X", address))
    local modules = enumModules()
    if modules then
        for i, m in ipairs(modules) do
            if address >= m.Address and address < (m.Address + m.Size) then
                DebugLog(string.format("SUCCESS: Found in %s (Base: %X, Size: %X)", m.Name, m.Address, m.Size))
                return m.Address, m.Size
            end
        end
    end
    DebugLog("WARNING: Address not inside any listed module.")
    return nil, nil
end

-- Fallback: Retrieves the raw memory region containing the target address
function AIF_Scanner.FindRegionByAddress(addr)
    DebugLog(string.format("Scanning raw memory regions for address: %X", addr))
    local regions = enumMemoryRegions()
    if not regions then return nil end
    for i = 1, #regions do
        local r = regions[i]
        local b = r.BaseAddress or r.Start or r.Address
        local s = r.RegionSize or r.Size or r.Length
        if b and s and addr >= b and addr < b + s then
            DebugLog(string.format("SUCCESS: Found Memory Region (Base: %X, Size: %X, Protect: %s)", b, s, tostring(r.AllocationProtect)))
            return b, s, r.RegionName or r.FileName or string.format("%X", b)
        end
    end
    DebugLog("ERROR: No valid memory region found.")
    return nil
end

-- Extracts byte data and disassembler text for a specific instruction
function AIF_Scanner.GetInstructionData(addr)
    local sz = getInstructionSize(addr)
    if not sz or sz == 0 then sz = 1 end
    local bytes = readBytes(addr, sz, true)
    if not bytes then return nil end
    local disasm = disassemble(addr)
    return { sz = sz, bytes = bytes, disasm = disasm }
end

-- Verifies if an AOB string returns exactly one unique match within the specified bounds
function AIF_Scanner.CheckAOB(bytes, curModule)
    local base = curModule and curModule.Address or 0x0
    local moduleSize = (curModule and curModule.Size) or 0x7fffffffffff
    local memScanner = createMemScan()
    local memFoundList = createFoundList(memScanner)

    memScanner.firstScan(
        soExactValue, vtByteArray, rtRounded, bytes, nil,
        base, base + moduleSize, "",
        fsmNotAligned, "", true, false, false, false
    )
    memScanner.waitTillDone()
    memFoundList.initialize()

    local foundUnique = (memFoundList.Count == 1)
    memScanner.destroy()
    memFoundList.destroy()
    return foundUnique
end

-- Validates x64 REX prefixes and specific primary opcodes to determine wildcard placement
function AIF_Scanner.CheckOpCode(byteVal)
    if byteVal >= 0x40 and byteVal <= 0x49 then return true end
    if byteVal == 0x0F then return true end
    return false
end

-- Generates a unique Array of Bytes (AOB) signature for the given memory address
function AIF_Scanner.GenerateWildcardAOB(base)
    DebugLog(string.format("\n--- INIT AOB GENERATION [Base: %X] ---", base))
    
    local cfg = _G.AIF.Config
    local searchBase, searchSize = nil, nil
    
    if cfg.SmartAob then 
        searchBase, searchSize = AIF_Scanner.GetModuleBounds(base) 
    end
    
    if not searchBase then
        searchBase, searchSize = AIF_Scanner.FindRegionByAddress(base)
        if cfg.SmartAob and searchBase then 
            DebugLog("[SmartAOB] Warning: Module Bounds failed, using Region Bounds.") 
        end
    end
    
    if not searchBase then
        DebugLog("CRITICAL ERROR: No memory region found for AOB scan bounds.")
        return nil
    end

    local minLen = cfg.AobMinScan or 8
    local maxLen = cfg.AobMaxScan or 48
    local wCardFormat = "??"
    local isX64 = targetIs64Bit()
    local result = nil
    local done = false
    local parts = {}

    if cfg.SmartAob then
        local currentModule = { Address = searchBase, Size = searchSize }
        local AOB = createStringList()
        local AOBWildCard = ""
        local current = 0
        local totalIterations = maxLen

        for i = 1, totalIterations do
            local addr = base + current
            local size = getInstructionSize(addr)
            if not size or size == 0 then size = 1 end

            local byteVal = readBytes(addr, 1)
            if not byteVal then break end

            local byteStr = string.format("%02X", byteVal)
            if byteStr == "CC" then byteStr = wCardFormat end
            AOB.add(byteStr)
            table.insert(parts, byteStr)

            if isX64 and AIF_Scanner.CheckOpCode(byteVal) then
                current = current + 1
                size = size - 1
                local nextByteVal = readBytes(base + current, 1)
                if nextByteVal then
                    local nextByte = string.format("%02X", nextByteVal)
                    if cfg.AobSpaces then AOB.add(" ") end
                    AOB.add(nextByte)
                    table.insert(parts, nextByte)
                end
            end

            AOBWildCard = string.gsub(AOB.text, "%c", "")

            if i >= minLen then
                local testAOB = AOBWildCard
                if not cfg.AobSpaces then testAOB = string.gsub(testAOB, " ", "") end
                DebugLog("[SmartAOB] -> Firing verification scan: " .. testAOB)

                if AIF_Scanner.CheckAOB(testAOB, currentModule) then
                    DebugLog("[SmartAOB] UNIQUE LOCK ACQUIRED!")
                    done = true
                    break
                end
            end

            current = current + size
            if cfg.AobSpaces then AOB.add(" ") end
            for j = 1, size - 1 do
                AOB.add(wCardFormat)
                table.insert(parts, wCardFormat)
                if cfg.AobSpaces then AOB.add(" ") end
            end
        end

        AOBWildCard = string.gsub(AOB.text, "%c", "")
        AOB.destroy()

        if not cfg.AobSpaces then
            AOBWildCard = string.gsub(AOBWildCard, " ", "")
        end

        if done then
            AOBWildCard = AOBWildCard:match("^(.-)%s*$")
            DebugLog("[SmartAOB] FINAL AOB: " .. AOBWildCard .. "\n================================================")
            return AOBWildCard
        else
            DebugLog("[SmartAOB] ABORT: Max length reached without finding a unique AOB.")
            return nil
        end
    else
        -- Legacy Mode Fallback
        local ms = createMemScan()
        local fl = createFoundList(ms)
        local offset = 0
        
        local ok, scanErr = pcall(function()
            while offset < maxLen do
                local addr = base + offset
                local inst = AIF_Scanner.GetInstructionData(addr)
                if not inst then break end
                
                local sz = inst.sz
                local bytes = inst.bytes
                local op = bytes[1] or 0
                
                if isX64 and op >= 0x40 and op <= 0x4F then 
                    table.insert(parts, string.format("%02X", op))
                else 
                    table.insert(parts, (op == 0xCC) and wCardFormat or string.format("%02X", op)) 
                end
                
                for j = 2, sz do 
                    table.insert(parts, wCardFormat) 
                end

                local currentAobStr = table.concat(parts, cfg.AobSpaces and " " or "")
                
                if #parts >= minLen then
                    ms.firstScan(soExactValue, vtByteArray, rtRounded, currentAobStr, nil, searchBase, searchBase + searchSize, "", fsmNotAligned, "", true, false, false, false)
                    ms.waitTillDone()
                    fl.initialize()
                    
                    if fl.Count == 1 and tonumber(fl.getAddress(0), 16) == base then
                        result = currentAobStr
                        done = true
                        break
                    end
                end
                offset = offset + sz
            end
        end)
        
        fl.destroy()
        ms.destroy()
        
        if not ok then 
            DebugLog("[LegacyAOB] FATAL EXCEPTION: " .. tostring(scanErr))
            return nil 
        end
        
        if not done then 
            DebugLog("[LegacyAOB] ABORT: Max length reached.")
            return nil 
        end

        if result and cfg.AobSpaces then 
            result = result:match("^(.-)%s*$") 
        end
        
        DebugLog("[LegacyAOB] FINAL AOB: " .. tostring(result) .. "\n================================================")
        return result
    end
end

-- Expose module to the global AIF namespace
_G.AIF = _G.AIF or {}
_G.AIF.Scanner = AIF_Scanner
return AIF_Scanner

-- ============================================================================
-- AIF Pro - Module: Memory Scanner & AOB Generator (ARM / ARM64)
-- File: AIF/AIF_ScannerARM.lua
-- ============================================================================

local AIF_ScannerARM = {}

local function DebugLog(msg)
    if _G.AIF and _G.AIF.Config and _G.AIF.Config.Debug then
        print("[AIF-PRO ARM Scanner] " .. tostring(msg))
    end
end

-- Retrieves the address and size of the module containing the target address
function AIF_ScannerARM.GetModuleBounds(address)
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
function AIF_ScannerARM.FindRegionByAddress(addr)
    DebugLog(string.format("Scanning raw memory regions for address: %X", addr))
    local regions = enumMemoryRegions()
    if not regions then return nil end
    for i = 1, #regions do
        local r = regions[i]
        local b = r.BaseAddress or r.Start or r.Address
        local s = r.RegionSize or r.Size or r.Length
        if b and s and addr >= b and addr < b + s then
            DebugLog(string.format("SUCCESS: Found Memory Region (Base: %X, Size: %X)", b, s))
            return b, s, r.RegionName or r.FileName or string.format("%X", b)
        end
    end
    DebugLog("ERROR: No valid memory region found.")
    return nil
end

-- Verifies if an AOB string returns exactly one unique match within the specified bounds
function AIF_ScannerARM.CheckAOB(bytes, curModule)
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

-- Generates a unique Array of Bytes (AOB) signature for ARM/ARM64
function AIF_ScannerARM.GenerateWildcardAOB(base)
    DebugLog(string.format("\n--- INIT ARM AOB GENERATION [Base: %X] ---", base))
    
    local cfg = _G.AIF.Config
    local searchBase, searchSize = nil, nil
    
    -- Check Module Bounds if SmartAOB is requested, otherwise Region Bounds
    if cfg.SmartAob then
        searchBase, searchSize = AIF_ScannerARM.GetModuleBounds(base)
    end
    
    if not searchBase then
        searchBase, searchSize = AIF_ScannerARM.FindRegionByAddress(base)
        if cfg.SmartAob and searchBase then 
            DebugLog("[ARM SmartAOB] Warning: Module Bounds failed, using Region Bounds.") 
        end
    end
    
    if not searchBase then
        DebugLog("CRITICAL ERROR: No memory region found for AOB scan bounds.")
        return nil
    end

    local minLen = cfg.AobMinScan or 12 -- Minimum 3 ARM instructions (3 * 4 bytes)
    local maxLen = cfg.AobMaxScan or 48
    local wCardFormat = "??"
    local is64Bit = targetIs64Bit()
    local result = nil
    local done = false
    local parts = {}
    
    if cfg.SmartAob then
        -- ==========================================================
        -- SMART ARM SCANNER MODE
        -- ==========================================================
        local currentModule = { Address = searchBase, Size = searchSize }
        local AOB = createStringList()
        local current = 0
        
        while current < maxLen do
            local addr = base + current
            local size = getInstructionSize(addr)
            if not size or size == 0 then size = 4 end -- Standard ARM instruction size

            local bytes = readBytes(addr, size, true)
            if not bytes then break end

            local instData = nil
            if _G.AIF and _G.AIF.Decoder then
                instData = _G.AIF.Decoder.DecodeInstruction(addr, is64Bit, true) -- true for isARM
            end

            -- Determine if instruction contains a relative offset
            local isRelative = instData and (instData.isRelativeJump or instData.isRelativeCall or instData.isRIPRelative)

            for i = 1, size do
                -- In ARM Little Endian, the opcode is usually in the highest byte.
                if isRelative and i < size then
                    table.insert(parts, wCardFormat)
                    AOB.add(wCardFormat)
                else
                    local hexByte = string.format("%02X", bytes[i])
                    table.insert(parts, hexByte)
                    AOB.add(hexByte)
                end
                if cfg.AobSpaces and (i < size or current + size < maxLen) then
                    AOB.add(" ")
                end
            end

            current = current + size

            if current >= minLen then
                local testAOB = table.concat(parts, cfg.AobSpaces and " " or "")
                if not cfg.AobSpaces then testAOB = testAOB:gsub(" ", "") end
                
                DebugLog("[ARM SmartAOB] -> Firing verification scan: " .. testAOB)
                if AIF_ScannerARM.CheckAOB(testAOB, currentModule) then
                    DebugLog("[ARM SmartAOB] UNIQUE LOCK ACQUIRED!")
                    done = true
                    break
                end
            end
        end

        local finalAob = table.concat(parts, cfg.AobSpaces and " " or "")
        AOB.destroy()

        if done then
            finalAob = finalAob:match("^(.-)%s*$") or finalAob
            DebugLog("[ARM SmartAOB] FINAL AOB: " .. finalAob .. "\n================================================")
            return finalAob
        else
            DebugLog("[ARM SmartAOB] ABORT: Max length reached without finding a unique AOB.")
            return nil
        end
        
    else
        -- ==========================================================
        -- REGULAR / LEGACY ARM SCANNER MODE
        -- ==========================================================
        local ms = createMemScan()
        local fl = createFoundList(ms)
        local offset = 0
        
        local ok, scanErr = pcall(function()
            while offset < maxLen do
                local addr = base + offset
                local size = getInstructionSize(addr)
                if not size or size == 0 then size = 4 end
                
                local bytes = readBytes(addr, size, true)
                if not bytes then break end
                
                local instData = nil
                if _G.AIF and _G.AIF.Decoder then
                    instData = _G.AIF.Decoder.DecodeInstruction(addr, is64Bit, true)
                end

                local isRelative = instData and (instData.isRelativeJump or instData.isRelativeCall or instData.isRIPRelative)

                for i = 1, size do
                    if isRelative and i < size then
                        table.insert(parts, wCardFormat)
                    else
                        table.insert(parts, string.format("%02X", bytes[i]))
                    end
                end
                
                local currentAobStr = table.concat(parts, cfg.AobSpaces and " " or "")
                
                if #parts >= minLen then
                    ms.firstScan(soExactValue, vtByteArray, rtRounded, currentAobStr, nil, searchBase, searchBase + searchSize, "", fsmNotAligned, "", true, false, false, false)
                    ms.waitTillDone()
                    fl.initialize()
                    
                    -- Check if we found exactly one match and it's our base address
                    if fl.Count == 1 and tonumber(fl.getAddress(0), 16) == base then
                        result = currentAobStr
                        done = true
                        break
                    end
                end
                offset = offset + size
            end
        end)
        
        fl.destroy()
        ms.destroy()
        
        if not ok then 
            DebugLog("[ARM LegacyAOB] FATAL EXCEPTION: " .. tostring(scanErr))
            return nil 
        end
        
        if not done then 
            DebugLog("[ARM LegacyAOB] ABORT: Max length reached.")
            return nil 
        end
        
        if result and cfg.AobSpaces then 
            result = result:match("^(.-)%s*$") 
        end
        
        DebugLog("[ARM LegacyAOB] FINAL AOB: " .. tostring(result) .. "\n================================================")
        return result
    end
end

-- Expose module to the global AIF namespace
_G.AIF = _G.AIF or {}
_G.AIF.ScannerARM = AIF_ScannerARM
return AIF_ScannerARM

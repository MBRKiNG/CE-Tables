-- ============================================================================
-- AIF Pro - Module: Templates & Code Generators (ARM / ARM64)
-- File: AIF/AIF_TemplatesARM.lua
-- ============================================================================

local AIF_TemplatesARM = {}

-- Utility: Retrieve active process and window title
local function GetProcessContext()
    local ctx = { process = process or "game.exe", window = "Unknown Window" }
    local pid = getOpenedProcessID()
    if not pid or pid == 0 then return ctx end
    
    local wl = getWindowlist()
    if wl then
        local bestCaption = ""
        for wpid, windows in pairs(wl) do
            if wpid == pid then
                for _, caption in ipairs(windows) do
                    if caption and caption ~= "" then
                        local lowerCap = caption:lower()
                        if not lowerCap:find("default ime") and not lowerCap:find("msctfime") and not lowerCap:find("gdi%+ window") then
                            if string.len(caption) > string.len(bestCaption) then bestCaption = caption end
                        end
                    end
                end
            end
        end
        if bestCaption ~= "" then ctx.window = bestCaption end
    end
    return ctx
end

-- ARCHITECTURE GUARD: Validates if the target process is running on a valid ARM environment
local function ValidateARMArchitecture()
    local proc = (process or ""):lower()
    -- Block standard native x86 / x64 Windows processes from using ARM templates
    if proc:find("x86_64") or proc:find("win32") or proc:find("win64") then
        return false
    end
    return true
end

-- Helper: Replaces raw hex addresses inside opcodes with Module+Offset only if enabled
local function FormatOpcodeWithSymbols(disasmLine)
    local cfg = _G.AIF and _G.AIF.Config or { UseModuleNamesInContext = true }
    local opcodePart = disasmLine:match("^.-%-%s+.-%-%s+(.*)$") or disasmLine:match("^.-%-%s+(.*)$") or disasmLine
    
    if not cfg.UseModuleNamesInContext then
        return opcodePart
    end
    
    opcodePart = opcodePart:gsub("%f[%x](%x%x%x%x%x+)%f[^%x]", function(hex)
        local num = tonumber(hex, 16)
        if num and num > 0x10000 then
            local sym = getNameFromAddress(num)
            if sym and sym ~= "" and not sym:match("^%x+$") then
                if sym:sub(1, 1) == '"' and sym:sub(-1) == '"' then
                    return sym:sub(2, -2)
                end
                return sym
            else
                local modules = enumModules()
                if modules then
                    for _, m in ipairs(modules) do
                        if num >= m.Address and num < (m.Address + m.Size) then
                            local offset = num - m.Address
                            return string.format('"%s"+%X', m.Name, offset)
                        end
                    end
                end
            end
        end
        return hex
    end)
    
    return opcodePart
end

-- Helper: Collects raw instruction data for a given address
local function GetInstructionDetails(addr)
    local cfg = _G.AIF and _G.AIF.Config or { UseModuleNamesInContext = true }
    local addrStr = string.format('"%X"', addr)
    
    if cfg.UseModuleNamesInContext then
        local sym = getNameFromAddress(addr)
        if sym and sym ~= "" and not sym:match("^%x+$") then
            if sym:sub(1, 1) == '"' and sym:sub(-1) == '"' then addrStr = sym:sub(2, -2) else addrStr = sym end
        else
            local modules = enumModules()
            if modules then
                for _, m in ipairs(modules) do
                    if addr >= m.Address and addr < (m.Address + m.Size) then
                        addrStr = string.format('"%s"+%X', m.Name, addr - m.Address)
                        break
                    end
                end
            end
        end
    end

    local sz = getInstructionSize(addr)
    if not sz or sz == 0 then sz = 4 end
    local bytes = readBytes(addr, sz, true) or {}
    local hexList = {}
    for _, b in ipairs(bytes) do table.insert(hexList, string.format("%02X", b)) end
    local byteStr = table.concat(hexList, " ")
    
    local rawDisasm = disassemble(addr) or ""
    local opcodePart = FormatOpcodeWithSymbols(rawDisasm)

    return {
        addrStr = addrStr,
        byteStr = byteStr,
        opcodePart = opcodePart,
        addrLen = #addrStr,
        byteLen = #byteStr
    }
end

-- Generates a standardized, professional script header honoring settings
local function GenerateHeader(ctx, aobHex, injectAddr)
    local cfg = _G.AIF.Config
    if not cfg.IncludeHeader then return "" end
    
    local details = GetInstructionDetails(injectAddr)
    local padAddr = math.max(details.addrLen + 4, 45)
    local padByte = math.max(details.byteLen + 4, 24)
    local headerFmt = string.format("%%-%ds - %%-%ds - %%s", padAddr, padByte)
    local origCodeLine = string.format(headerFmt, details.addrStr, details.byteStr, details.opcodePart)
    
    return string.format([[
// Game   : %s
// Window : %s
// Date   : %s
// Author : %s
// GitHub : %s
// Forum  : %s
// -----------------------------------------------------------
// Original Code: %s
// Generated AoB: %s
// -----------------------------------------------------------
]], ctx.process, ctx.window, os.date("%Y-%m-%d"), cfg.Author, cfg.Github, cfg.Forum, origCodeLine, aobHex or "")
end

-- Generates the clean context block honoring LinesBefore and LinesAfter from Config
local function GenerateOriginalCodeContext(injectAddr, hookSize)
    local cfg = _G.AIF.Config
    if not cfg.IncludeOriginalCode then return "" end
    
    local rawEntries = {}
    local szARM = 4 -- ARM instructions are fixed 4 bytes
    
    -- Gather Lines Before based on Config (LinesBefore)
    local startAddr = injectAddr - (cfg.LinesBefore * szARM)
    local cAddr = startAddr
    while cAddr < injectAddr do
        table.insert(rawEntries, GetInstructionDetails(cAddr))
        cAddr = cAddr + szARM
    end
    
    -- Gather Injection Point / Stolen Instructions
    table.insert(rawEntries, { isMarker = true, text = "// ---------- INJECTING HERE ----------" })
    local bytesRead = 0
    while bytesRead < hookSize do
        table.insert(rawEntries, GetInstructionDetails(injectAddr + bytesRead))
        bytesRead = bytesRead + szARM
    end
    table.insert(rawEntries, { isMarker = true, text = "// ---------- DONE INJECTING ----------" })
    
    -- Gather Lines After based on Config (LinesAfter)
    cAddr = injectAddr + hookSize
    local endAddr = cAddr + (cfg.LinesAfter * szARM)
    while cAddr < endAddr do
        table.insert(rawEntries, GetInstructionDetails(cAddr))
        cAddr = cAddr + szARM
    end
    
    local maxAddrLen = 20
    local maxByteLen = 12
    for _, entry in ipairs(rawEntries) do
        if not entry.isMarker then
            if entry.addrLen > maxAddrLen then maxAddrLen = entry.addrLen end
            if entry.byteLen > maxByteLen then maxByteLen = entry.byteLen end
        end
    end
    
    maxAddrLen = maxAddrLen + 4
    maxByteLen = maxByteLen + 4
    local formatString = string.format("%%-%ds - %%-%ds - %%s", maxAddrLen, maxByteLen)
    
    local contextLines = {}
    table.insert(contextLines, "// ORIGINAL CODE - INJECTION POINT")
    
    for _, entry in ipairs(rawEntries) do
        if entry.isMarker then
            table.insert(contextLines, entry.text)
        else
            table.insert(contextLines, string.format(formatString, entry.addrStr, entry.byteStr, entry.opcodePart))
        end
    end
    
    return "\n{\n" .. table.concat(contextLines, "\n") .. "\n}"
end

-- ============================================================================
-- [ARM] GENERATOR 1: Inline AOB Patcher
-- ============================================================================
function AIF_TemplatesARM.BuildARMAobPatcher(injectAddr, symbolInput)
    local ctx = GetProcessContext()
    local moduleName = (getNameFromAddress(injectAddr) or ""):match("([^%+%:]+)")
    if not moduleName or moduleName == "" then moduleName = ctx.process end
    local patchSize = getInstructionSize(injectAddr)
    if not patchSize or patchSize <= 0 then patchSize = 4 end
    local origBytes = readBytes(injectAddr, patchSize, true) or {}
    local origHex = {}
    for _, b in ipairs(origBytes) do table.insert(origHex, string.format("%02X", b)) end
    local dbOriginal = table.concat(origHex, " ")
    
    local aobScanHex = _G.AIF.ScannerARM and _G.AIF.ScannerARM.GenerateWildcardAOB(injectAddr)
    if not aobScanHex then aobScanHex = table.concat(origHex, _G.AIF.Config.AobSpaces and " " or "") end
    
    local aobScanLine = string.format("aobscanmodule(%s, %s, %s)", symbolInput, moduleName, aobScanHex)
    local restoreSymbol = symbolInput .. "_Restore"
    local disableBlock = _G.AIF.Memory.GenerateExplicitDisableBlock({symbolInput, restoreSymbol}, {restoreSymbol})
    
    local header = GenerateHeader(ctx, aobScanHex, injectAddr)
    local footer = GenerateOriginalCodeContext(injectAddr, patchSize)
    local comment = _G.AIF.Config.UseComments and " // ---> REPLACE WITH YOUR PATCH BYTES <---" or ""
    
    return string.format([[
%s[ENABLE]
%s
alloc(%s, %d)

%s:
  readmem(%s, %d)

%s:
  db %s%s

registersymbol(%s %s)

[DISABLE]
%s:
  readmem(%s, %d)

%s
%s
]], header, aobScanLine, restoreSymbol, patchSize, restoreSymbol, symbolInput, patchSize, symbolInput, dbOriginal, comment, symbolInput, restoreSymbol, symbolInput, restoreSymbol, patchSize, disableBlock, footer)
end

-- ============================================================================
-- [ARM] GENERATOR 2: Dynamic Detour Hook
-- ============================================================================
function AIF_TemplatesARM.BuildARMDynamicDetour(injectAddr, symbolInput)
    local validation = _G.AIF.Validator.ValidateInjectionSite(injectAddr, 4)
    if not validation.isSafe then error("Validation Failed:\n" .. table.concat(validation.warnings, "\n")) end
    
    local ctx = GetProcessContext()
    local moduleName = (getNameFromAddress(injectAddr) or ""):match("([^%+%:]+)")
    if not moduleName or moduleName == "" then moduleName = ctx.process end
    
    local is64Bit = targetIs64Bit()
    local analysis = _G.AIF.ABI.AnalyzeHookRegisters(validation.stolenInstructions, is64Bit, true)
    local scratchRegs = _G.AIF.ABI.ChooseScratchRegisters(analysis, is64Bit, 2, true)
    local pushAsm, popAsm = _G.AIF.ABI.GenerateSaveRestoreBlock(is64Bit, scratchRegs, true, "  ", nil, nil, analysis.usesSIMD, true)
    
    local relocAsm = _G.AIF.Relocator.BuildRelocationBlock(injectAddr, validation.stolenInstructions, symbolInput, 0)
    
    local aobScanHex = _G.AIF.ScannerARM and _G.AIF.ScannerARM.GenerateWildcardAOB(injectAddr) or "AOB_GENERATION_FAILED"
    local aobScanLine = string.format("aobscanmodule(%s, %s, %s)", symbolInput, moduleName, aobScanHex)
    
    local restoreSymbol = symbolInput .. "_Restore"
    local allocStr = _G.AIF.Memory.GenerateAllocations({{name="newmem", size="$1000"}}, symbolInput, validation.requiresNearAlloc)
    local regStr = _G.AIF.Memory.GenerateRegisterBlock({symbolInput, restoreSymbol})
    local disableBlock = _G.AIF.Memory.GenerateExplicitDisableBlock({symbolInput, restoreSymbol}, {"newmem", restoreSymbol})
    
    local nopSize = validation.totalSize - 4
    local nopLine = (nopSize > 0) and string.format("  nop %d", nopSize) or ""
    
    local header = GenerateHeader(ctx, aobScanHex, injectAddr)
    local footer = GenerateOriginalCodeContext(injectAddr, validation.totalSize)
    
    return string.format([[
%s[ENABLE]
%s
%s
alloc(%s, %d)

%s:
  readmem(%s, %d)

label(code)
label(return)

newmem:
code:
%s
  -- ---> WRITE YOUR CUSTOM ARM CODE HERE <---
  
%s
%s
  b return

%s:
  b newmem
%s
return:

%s

[DISABLE]
%s:
  readmem(%s, %d)

%s
%s
]], header, aobScanLine, allocStr, restoreSymbol, validation.totalSize, restoreSymbol, symbolInput, validation.totalSize, pushAsm, popAsm, relocAsm, symbolInput, nopLine, regStr, symbolInput, restoreSymbol, validation.totalSize, disableBlock, footer)
end

-- ============================================================================
-- [ARM] GENERATOR 3: Pointer Registration Detour
-- ============================================================================
function AIF_TemplatesARM.BuildARMBasePointer(injectAddr, symbolInput, baseInput)
    local validation = _G.AIF.Validator.ValidateInjectionSite(injectAddr, 4)
    if not validation.isSafe then error("Validation Failed:\n" .. table.concat(validation.warnings, "\n")) end
    
    local ctx = GetProcessContext()
    local moduleName = (getNameFromAddress(injectAddr) or ""):match("([^%+%:]+)")
    if not moduleName or moduleName == "" then moduleName = ctx.process end
    
    local is64Bit = targetIs64Bit()
    
    local aobScanHex = _G.AIF.ScannerARM and _G.AIF.ScannerARM.GenerateWildcardAOB(injectAddr) or "AOB_GENERATION_FAILED"
    local aobScanLine = string.format("aobscanmodule(%s, %s, %s)", symbolInput, moduleName, aobScanHex)
    
    local restoreSymbol = symbolInput .. "_Restore"
    local allocStr = _G.AIF.Memory.GenerateAllocations({{name="newmem", size="$1000"}}, symbolInput, validation.requiresNearAlloc)
    local regStr = _G.AIF.Memory.GenerateRegisterBlock({symbolInput, restoreSymbol, baseInput})
    local disableBlock = _G.AIF.Memory.GenerateExplicitDisableBlock({symbolInput, restoreSymbol, baseInput}, {"newmem", restoreSymbol})
    
    local relocAsm = _G.AIF.Relocator.BuildRelocationBlock(injectAddr, validation.stolenInstructions, symbolInput, 0)
    local header = GenerateHeader(ctx, aobScanHex, injectAddr)
    local footer = GenerateOriginalCodeContext(injectAddr, validation.totalSize)
    
    local ptrDef = is64Bit and "dq 0" or "dd 0"
    
    local detectedBaseReg = nil
    local firstInst = validation.stolenInstructions[1]
    if firstInst and firstInst.operands then
        for _, op in ipairs(firstInst.operands) do
            local memData = _G.AIF.Decoder.AnalyzeMemoryOperand(op, is64Bit, true)
            if memData.isMemory and memData.baseRegister then
                detectedBaseReg = memData.baseRegister
                break
            end
        end
    end
    detectedBaseReg = detectedBaseReg or (is64Bit and "x0" or "r0")
    
    local ptrStore = string.format("  str %s, [%s]\n", detectedBaseReg, baseInput)
    local nopSize = validation.totalSize - 4
    local nopLine = (nopSize > 0) and string.format("  nop %d", nopSize) or ""

    return string.format([[
%s[ENABLE]
%s
%s
alloc(%s, %d)

%s:
  readmem(%s, %d)

label(code)
label(return)
label(%s)

newmem:
code:
%s
%s
  b return

%s:
  %s

%s:
  b newmem
%s
return:

%s

[DISABLE]
%s:
  readmem(%s, %d)

%s
%s
]], header, aobScanLine, allocStr, restoreSymbol, validation.totalSize, restoreSymbol, symbolInput, validation.totalSize, baseInput, ptrStore, relocAsm, baseInput, ptrDef, symbolInput, nopLine, regStr, symbolInput, restoreSymbol, validation.totalSize, disableBlock, footer)
end

-- ============================================================================
-- [ARM] GENERATOR 4: Advanced Detour Hook (Data & Code Separation)
-- ============================================================================
function AIF_TemplatesARM.BuildARMAdvancedHook(injectAddr, symbolInput)
    local validation = _G.AIF.Validator.ValidateInjectionSite(injectAddr, 4)
    if not validation.isSafe then error("Validation Failed:\n" .. table.concat(validation.warnings, "\n")) end
    
    local ctx = GetProcessContext()
    local moduleName = (getNameFromAddress(injectAddr) or ""):match("([^%+%:]+)")
    if not moduleName or moduleName == "" then moduleName = ctx.process end
    
    local is64Bit = targetIs64Bit()
    local analysis = _G.AIF.ABI.AnalyzeHookRegisters(validation.stolenInstructions, is64Bit, true)
    local scratchRegs = _G.AIF.ABI.ChooseScratchRegisters(analysis, is64Bit, 2, true)
    local pushAsm, popAsm = _G.AIF.ABI.GenerateSaveRestoreBlock(is64Bit, scratchRegs, true, "  ", nil, nil, analysis.usesSIMD, true)
    
    local relocAsm = _G.AIF.Relocator.BuildRelocationBlock(injectAddr, validation.stolenInstructions, symbolInput, 0)
    
    local aobScanHex = _G.AIF.ScannerARM and _G.AIF.ScannerARM.GenerateWildcardAOB(injectAddr) or "AOB_GENERATION_FAILED"
    local aobScanLine = string.format("aobscanmodule(%s, %s, %s)", symbolInput, moduleName, aobScanHex)
    
    local restoreSymbol = symbolInput .. "_Restore"
    local flagSymbol = "bEnableCheat_" .. symbolInput
    
    local allocStr = _G.AIF.Memory.GenerateAllocations({{name="newmem", size="$1000"}, {name="data", size="$100"}}, symbolInput, validation.requiresNearAlloc)
    local regStr = _G.AIF.Memory.GenerateRegisterBlock({symbolInput, restoreSymbol, flagSymbol})
    local disableBlock = _G.AIF.Memory.GenerateExplicitDisableBlock({symbolInput, restoreSymbol, flagSymbol}, {"newmem", "data", restoreSymbol})
    
    local nopSize = validation.totalSize - 4
    local nopLine = (nopSize > 0) and string.format("  nop %d", nopSize) or ""
    
    local header = GenerateHeader(ctx, aobScanHex, injectAddr)
    local footer = GenerateOriginalCodeContext(injectAddr, validation.totalSize)

    return string.format([[
%s[ENABLE]
%s
%s
alloc(%s, %d)

%s:
  readmem(%s, %d)

label(code)
label(original_code)
label(return)
label(%s)

data:
  db 01

newmem:
code:
  -- ARM64 Flag Check
  ldrb w8, [%s]
  cmp w8, #1
  b.ne original_code

%s
  -- ---> WRITE YOUR CUSTOM ARM CODE HERE <---
  
%s
original_code:
%s
  b return

%s:
  b newmem
%s
return:

%s

[DISABLE]
%s:
  readmem(%s, %d)

%s
%s
]], header, aobScanLine, allocStr, restoreSymbol, validation.totalSize, restoreSymbol, symbolInput, validation.totalSize, flagSymbol, flagSymbol, pushAsm, popAsm, relocAsm, symbolInput, nopLine, regStr, symbolInput, restoreSymbol, validation.totalSize, disableBlock, footer)
end

-- Template Registration with Strict Architecture Guard & English Error Handling
function AIF_TemplatesARM.RegisterAll()
    if _G.AIF_TemplatesARM_Registered then return end
    _G.AIF.DebugLog("Registering AIF Pro [ARM] Templates into CE...")
    
    local function GetTargetAddress()
        local mv = getMemoryViewForm()
        local dv = mv and (mv.DisassemblerView or mv.Disassemblerview)
        local selAddr = dv and dv.SelectedAddress or 0
        if selAddr and selAddr ~= 0 then return selAddr end
        return nil
    end

    local function CheckAndExecute(callback)
        if not ValidateARMArchitecture() then
            showMessage("No ARM opcode found / Invalid architecture!\n\nThis ARM template cannot be executed in an x86/x64 native process.")
            return
        end
        callback()
    end

    local function GetSafeSymbol(promptTitle, defaultSym)
        local sym = inputQuery(promptTitle, "Symbol Name:", defaultSym)
        if not sym or sym == "" then return nil end
        local safeSym = _G.AIF.Utilities.SanitizeSymbol(sym)
        if not safeSym then 
            showMessage("Invalid symbol name. Use only letters, numbers, and underscores.")
            return nil 
        end
        return safeSym
    end

    registerAutoAssemblerTemplate("[ARM] Inline AOB Patcher", function(script, form)
        CheckAndExecute(function()
            local addr = GetTargetAddress()
            if not addr then showMessage("No address selected."); return end
            local sym = GetSafeSymbol("ARM AOB Patcher", "INJECT")
            if not sym then return end
            local success, result = pcall(AIF_TemplatesARM.BuildARMAobPatcher, addr, sym)
            if success then script.addText(result) else showMessage("Engine Error: " .. tostring(result)) end
        end)
    end)

    registerAutoAssemblerTemplate("[ARM] Dynamic Detour Hook", function(script, form)
        CheckAndExecute(function()
            local addr = GetTargetAddress()
            if not addr then showMessage("No address selected."); return end
            local sym = GetSafeSymbol("ARM Dynamic Detour Hook", "INJECT")
            if not sym then return end
            local success, result = pcall(AIF_TemplatesARM.BuildARMDynamicDetour, addr, sym)
            if success then script.addText(result) else showMessage("Engine Error: " .. tostring(result)) end
        end)
    end)
    
    registerAutoAssemblerTemplate("[ARM] Pointer Registration Detour", function(script, form)
        CheckAndExecute(function()
            local addr = GetTargetAddress()
            if not addr then showMessage("No address selected."); return end
            local sym = GetSafeSymbol("ARM Pointer Registration", "INJECT")
            if not sym then return end
            local baseSym = GetSafeSymbol("ARM Pointer Registration - Base Name", "base")
            if not baseSym then return end
            local success, result = pcall(AIF_TemplatesARM.BuildARMBasePointer, addr, sym, baseSym)
            if success then script.addText(result) else showMessage("Engine Error: " .. tostring(result)) end
        end)
    end)

    registerAutoAssemblerTemplate("[ARM] Advanced Detour Hook (Process/Code Sep)", function(script, form)
        CheckAndExecute(function()
            local addr = GetTargetAddress()
            if not addr then showMessage("No address selected."); return end
            local sym = GetSafeSymbol("ARM Advanced Hook", "INJECT")
            if not sym then return end
            local success, result = pcall(AIF_TemplatesARM.BuildARMAdvancedHook, addr, sym)
            if success then script.addText(result) else showMessage("Engine Error: " .. tostring(result)) end
        end)
    end)

    _G.AIF_TemplatesARM_Registered = true
end

-- Expose module and trigger registration
_G.AIF = _G.AIF or {}
_G.AIF.TemplatesARM = AIF_TemplatesARM
AIF_TemplatesARM.RegisterAll()

return AIF_TemplatesARM

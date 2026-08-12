-- ============================================================================
-- AIF Pro - Module: Templates & Code Generators (x86 / x64)
-- File: AIF/AIF_Templates.lua
-- ============================================================================

local AIF_Templates = {}

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

-- Helper: Formats address based on user's UseModuleNamesInContext setting
local function GetFormattedAddressString(addr)
    local cfg = _G.AIF and _G.AIF.Config or { UseModuleNamesInContext = true }
    
    -- If user disabled module names, return pure hex address string
    if not cfg.UseModuleNamesInContext then
        return string.format('"%X"', addr)
    end
    
    -- Otherwise, try to resolve Module+Offset
    local sym = getNameFromAddress(addr)
    if sym and sym ~= "" and not sym:match("^%x+$") then
        if sym:sub(1, 1) == '"' and sym:sub(-1) == '"' then
            return sym:sub(2, -2)
        end
        return sym
    end
    
    local modules = enumModules()
    if modules then
        for _, m in ipairs(modules) do
            if addr >= m.Address and addr < (m.Address + m.Size) then
                local offset = addr - m.Address
                return string.format('"%s"+%X', m.Name, offset)
            end
        end
    end
    
    return string.format('"%X"', addr)
end

-- Helper: Replaces raw hex addresses inside opcodes with Module+Offset only if enabled
local function FormatOpcodeWithSymbols(disasmLine)
    local cfg = _G.AIF and _G.AIF.Config or { UseModuleNamesInContext = true }
    local opcodePart = disasmLine:match("^.-%-%s+.-%-%s+(.*)$") or disasmLine:match("^.-%-%s+(.*)$") or disasmLine
    
    if not cfg.UseModuleNamesInContext then
        return opcodePart
    end
    
    -- FIX: Dynamischer Regex schnappt sich alle Hex-Strings ab 5 Zeichen, egal ob 32-Bit oder 64-Bit!
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
    local addrStr = GetFormattedAddressString(addr)
    local sz = getInstructionSize(addr)
    if not sz or sz == 0 then sz = 1 end
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

-- Generates the clean context block with fully dynamic column widths honoring settings
local function GenerateOriginalCodeContext(injectAddr, hookSize, stolenAddrs)
    local cfg = _G.AIF.Config
    if not cfg.IncludeOriginalCode then return "" end
    
    local rawEntries = {}
    
    local startAddr = injectAddr
    for i = 1, cfg.LinesBefore do
        local prev = getPreviousOpcode(startAddr)
        if prev and prev ~= 0 and prev < startAddr then startAddr = prev else break end
    end
    
    -- Gather Lines Before
    local cAddr = startAddr
    while cAddr < injectAddr do
        table.insert(rawEntries, GetInstructionDetails(cAddr))
        local sz = getInstructionSize(cAddr) or 1
        cAddr = cAddr + ((sz > 0) and sz or 1)
    end
    
    -- Gather Injection Point / Stolen Instructions
    table.insert(rawEntries, { isMarker = true, text = "// ---------- INJECTING HERE ----------" })
    if stolenAddrs and #stolenAddrs > 0 then
        for _, sAddr in ipairs(stolenAddrs) do
            local addrVal = sAddr.address or injectAddr
            table.insert(rawEntries, GetInstructionDetails(addrVal))
        end
    else
        table.insert(rawEntries, GetInstructionDetails(injectAddr))
    end
    table.insert(rawEntries, { isMarker = true, text = "// ---------- DONE INJECTING ----------" })
    
    -- Gather Lines After
    cAddr = injectAddr + hookSize
    for i = 1, cfg.LinesAfter do
        table.insert(rawEntries, GetInstructionDetails(cAddr))
        local sz = getInstructionSize(cAddr) or 1
        cAddr = cAddr + ((sz > 0) and sz or 1)
    end
    
    -- Dynamic Pass: Find max lengths across all instructions in this block
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

-- ============================================================================
-- [x86/x64] GENERATOR 1: Inline AOB Patcher
-- ============================================================================
function AIF_Templates.BuildProAobPatcher(injectAddr, symbolInput)
    local ctx = GetProcessContext()
    local moduleName = (getNameFromAddress(injectAddr) or ""):match("([^%+%:]+)")
    if not moduleName or moduleName == "" then moduleName = ctx.process end
    local patchSize = getInstructionSize(injectAddr)
    if not patchSize or patchSize <= 0 then patchSize = 1 end
    local origBytes = readBytes(injectAddr, patchSize, true) or {}
    local origHex = {}
    for _, b in ipairs(origBytes) do table.insert(origHex, string.format("%02X", b)) end
    local dbOriginal = table.concat(origHex, " ")
    
    local aobScanHex = _G.AIF.Scanner.GenerateWildcardAOB(injectAddr)
    if not aobScanHex then aobScanHex = table.concat(origHex, _G.AIF.Config.AobSpaces and " " or "") end
    
    local aobScanLine = string.format("aobscanmodule(%s, %s, %s)", symbolInput, moduleName, aobScanHex)
    local restoreSymbol = symbolInput .. "_Restore"
    local disableBlock = _G.AIF.Memory.GenerateExplicitDisableBlock({symbolInput, restoreSymbol}, {restoreSymbol})
    
    local header = GenerateHeader(ctx, aobScanHex, injectAddr)
    local footer = GenerateOriginalCodeContext(injectAddr, patchSize, nil)
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
-- [x86/x64] GENERATOR 2: Dynamic Detour Hook
-- ============================================================================
function AIF_Templates.BuildProDynamicDetour(injectAddr, symbolInput, useFarJump)
    local jumpSize = useFarJump and 14 or 5
    local validation = _G.AIF.Validator.ValidateInjectionSite(injectAddr, jumpSize)
    
    if not validation.isSafe then error("Validation Failed:\n" .. table.concat(validation.warnings, "\n")) end
    
    local ctx = GetProcessContext()
    local moduleName = (getNameFromAddress(injectAddr) or ""):match("([^%+%:]+)")
    if not moduleName or moduleName == "" then moduleName = ctx.process end
    
    local is64Bit = targetIs64Bit()
    local analysis = _G.AIF.ABI.AnalyzeHookRegisters(validation.stolenInstructions, is64Bit)
    local scratchRegs = _G.AIF.ABI.ChooseScratchRegisters(analysis, is64Bit, 2)
    
    local pushAsm, popAsm = _G.AIF.ABI.GenerateSaveRestoreBlock(is64Bit, scratchRegs, true, "  ", nil, nil, analysis.usesSIMD)
    local relocAsm = _G.AIF.Relocator.BuildRelocationBlock(injectAddr, validation.stolenInstructions, symbolInput, 0)
    
    local aobScanHex = _G.AIF.Scanner.GenerateWildcardAOB(injectAddr) or "AOB_GENERATION_FAILED"
    local aobScanLine = string.format("aobscanmodule(%s, %s, %s)", symbolInput, moduleName, aobScanHex)
    
    local restoreSymbol = symbolInput .. "_Restore"
    local allocStr = _G.AIF.Memory.GenerateAllocations({{name="newmem", size="$1000"}}, symbolInput, validation.requiresNearAlloc)
    local regStr = _G.AIF.Memory.GenerateRegisterBlock({symbolInput, restoreSymbol})
    local disableBlock = _G.AIF.Memory.GenerateExplicitDisableBlock({symbolInput, restoreSymbol}, {"newmem", restoreSymbol})
    
    local nopSize = validation.totalSize - jumpSize
    local nopLine = (nopSize > 0) and string.format("  nop %d", nopSize) or ""
    
    local header = GenerateHeader(ctx, aobScanHex, injectAddr)
    local footer = GenerateOriginalCodeContext(injectAddr, validation.totalSize, validation.stolenInstructions)
    
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
  // ---> WRITE YOUR CUSTOM CODE HERE <---
  
%s
%s
  jmp return

%s:
  jmp newmem
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
-- [x86/x64] GENERATOR 3: Pointer Registration Detour
-- ============================================================================
function AIF_Templates.BuildProBasePointer(injectAddr, symbolInput, baseInput, useFarJump)
    local jumpSize = useFarJump and 14 or 5
    local validation = _G.AIF.Validator.ValidateInjectionSite(injectAddr, jumpSize)
    
    if not validation.isSafe then error("Validation Failed:\n" .. table.concat(validation.warnings, "\n")) end
    
    local ctx = GetProcessContext()
    local moduleName = (getNameFromAddress(injectAddr) or ""):match("([^%+%:]+)")
    if not moduleName or moduleName == "" then moduleName = ctx.process end
    
    local is64Bit = targetIs64Bit()
    local firstInst = validation.stolenInstructions[1]
    
    local detectedBaseReg = nil
    for _, op in ipairs(firstInst.operands) do
        local memData = _G.AIF.Decoder.AnalyzeMemoryOperand(op, is64Bit)
        if memData.isMemory and memData.baseRegister then
            detectedBaseReg = memData.baseRegister
            break
        end
    end
    detectedBaseReg = detectedBaseReg or (is64Bit and "rbx" or "ebx")
    
    local relocAsm = _G.AIF.Relocator.BuildRelocationBlock(injectAddr, validation.stolenInstructions, symbolInput, 0)
    
    local aobScanHex = _G.AIF.Scanner.GenerateWildcardAOB(injectAddr) or "AOB_GENERATION_FAILED"
    local aobScanLine = string.format("aobscanmodule(%s, %s, %s)", symbolInput, moduleName, aobScanHex)
    
    local restoreSymbol = symbolInput .. "_Restore"
    local allocStr = _G.AIF.Memory.GenerateAllocations({{name="newmem", size="$1000"}}, symbolInput, validation.requiresNearAlloc)
    local regStr = _G.AIF.Memory.GenerateRegisterBlock({symbolInput, restoreSymbol, baseInput})
    local disableBlock = _G.AIF.Memory.GenerateExplicitDisableBlock({symbolInput, restoreSymbol, baseInput}, {"newmem", restoreSymbol})
    
    local nopSize = validation.totalSize - jumpSize
    local nopLine = (nopSize > 0) and string.format("  nop %d", nopSize) or ""
    local ptrDef = is64Bit and "dq 0" or "dd 0"
    
    local header = GenerateHeader(ctx, aobScanHex, injectAddr)
    local footer = GenerateOriginalCodeContext(injectAddr, validation.totalSize, validation.stolenInstructions)
    
    local ptrStore = firstInst.isRIPRelative and "  // RIP-Relative addressing detected. Base extraction skipped.\n" or string.format("  mov [%s], %s\n", baseInput, detectedBaseReg)
    
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
%s%s
  jmp return

%s:
  %s

%s:
  jmp newmem
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
-- [x86/x64] GENERATOR 4: Advanced Detour Hook (Data & Code Separation)
-- ============================================================================
function AIF_Templates.BuildProAdvancedHook(injectAddr, symbolInput, useFarJump)
    local jumpSize = useFarJump and 14 or 5
    local validation = _G.AIF.Validator.ValidateInjectionSite(injectAddr, jumpSize)
    
    if not validation.isSafe then error("Validation Failed:\n" .. table.concat(validation.warnings, "\n")) end
    
    local ctx = GetProcessContext()
    local moduleName = (getNameFromAddress(injectAddr) or ""):match("([^%+%:]+)")
    if not moduleName or moduleName == "" then moduleName = ctx.process end
    
    local is64Bit = targetIs64Bit()
    local analysis = _G.AIF.ABI.AnalyzeHookRegisters(validation.stolenInstructions, is64Bit)
    local scratchRegs = _G.AIF.ABI.ChooseScratchRegisters(analysis, is64Bit, 2)
    
    local pushAsm, popAsm = _G.AIF.ABI.GenerateSaveRestoreBlock(is64Bit, scratchRegs, true, "  ", nil, nil, analysis.usesSIMD)
    local relocAsm = _G.AIF.Relocator.BuildRelocationBlock(injectAddr, validation.stolenInstructions, symbolInput, 0)
    
    local aobScanHex = _G.AIF.Scanner.GenerateWildcardAOB(injectAddr) or "AOB_GENERATION_FAILED"
    local aobScanLine = string.format("aobscanmodule(%s, %s, %s)", symbolInput, moduleName, aobScanHex)
    
    local restoreSymbol = symbolInput .. "_Restore"
    local flagSymbol = "bEnableCheat_" .. symbolInput
    
    local allocStr = _G.AIF.Memory.GenerateAllocations({{name="newmem", size="$1000"}, {name="data", size="$100"}}, symbolInput, validation.requiresNearAlloc)
    local regStr = _G.AIF.Memory.GenerateRegisterBlock({symbolInput, restoreSymbol, flagSymbol})
    local disableBlock = _G.AIF.Memory.GenerateExplicitDisableBlock({symbolInput, restoreSymbol, flagSymbol}, {"newmem", "data", restoreSymbol})
    
    local nopSize = validation.totalSize - jumpSize
    local nopLine = (nopSize > 0) and string.format("  nop %d", nopSize) or ""
    
    local header = GenerateHeader(ctx, aobScanHex, injectAddr)
    local footer = GenerateOriginalCodeContext(injectAddr, validation.totalSize, validation.stolenInstructions)
    
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
  cmp byte ptr [%s], 01
  jne original_code

%s
  // ---> WRITE YOUR CUSTOM CODE HERE <---
  
%s
  jmp return

original_code:
%s
  jmp return

%s:
  jmp newmem
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

-- ============================================================================
-- Template Registration (Guarded against multiple registrations on reload)
-- ============================================================================
function AIF_Templates.RegisterAll()
    if _G.AIF_Templates_Registered then
        _G.AIF.DebugLog("Templates already registered. Skipping duplicate registration.")
        return
    end
    _G.AIF.DebugLog("Registering AIF Pro Templates into CE...")
    
    local function GetTargetAddress()
        local mv = getMemoryViewForm()
        local dv = mv and (mv.DisassemblerView or mv.Disassemblerview)
        local selAddr = dv and dv.SelectedAddress or 0
        if selAddr and selAddr ~= 0 then return selAddr end
        return nil
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

    registerAutoAssemblerTemplate("[x86/x64] Inline AOB Patcher", function(script, form)
        local addr = GetTargetAddress()
        if not addr then showMessage("No address selected."); return end
        
        local sym = GetSafeSymbol("x86/x64 AOB Patcher", "INJECT")
        if not sym then return end
        
        local success, result = pcall(AIF_Templates.BuildProAobPatcher, addr, sym)
        if success then script.addText(result) else showMessage("Engine Error: " .. tostring(result)) end
    end)

    registerAutoAssemblerTemplate("[x86/x64] Dynamic Detour Hook", function(script, form)
        local addr = GetTargetAddress()
        if not addr then showMessage("No address selected."); return end
        
        local sym = GetSafeSymbol("x86/x64 Dynamic Detour Hook", "INJECT")
        if not sym then return end
        
        local useFarJump = targetIs64Bit() and (messageDialog("Use 14-Byte Far Jump?", mtConfirmation, mbYes, mbNo) == mrYes)
        local success, result = pcall(AIF_Templates.BuildProDynamicDetour, addr, sym, useFarJump)
        if success then script.addText(result) else showMessage("Engine Error: " .. tostring(result)) end
    end)
    
    registerAutoAssemblerTemplate("[x86/x64] Pointer Registration Detour", function(script, form)
        local addr = GetTargetAddress()
        if not addr then showMessage("No address selected."); return end
        
        local sym = GetSafeSymbol("x86/x64 Pointer Registration", "INJECT")
        if not sym then return end
        
        local baseSym = GetSafeSymbol("x86/x64 Pointer Registration - Base Name", "base")
        if not baseSym then return end
        
        local useFarJump = targetIs64Bit() and (messageDialog("Use 14-Byte Far Jump?", mtConfirmation, mbYes, mbNo) == mrYes)
        local success, result = pcall(AIF_Templates.BuildProBasePointer, addr, sym, baseSym, useFarJump)
        if success then script.addText(result) else showMessage("Engine Error: " .. tostring(result)) end
    end)

    registerAutoAssemblerTemplate("[x86/x64] Advanced Detour Hook (Data/Code Sep)", function(script, form)
        local addr = GetTargetAddress()
        if not addr then showMessage("No address selected."); return end
        
        local sym = GetSafeSymbol("x86/x64 Advanced Hook", "INJECT")
        if not sym then return end
        
        local useFarJump = targetIs64Bit() and (messageDialog("Use 14-Byte Far Jump?", mtConfirmation, mbYes, mbNo) == mrYes)
        local success, result = pcall(AIF_Templates.BuildProAdvancedHook, addr, sym, useFarJump)
        if success then script.addText(result) else showMessage("Engine Error: " .. tostring(result)) end
    end)

    _G.AIF_Templates_Registered = true
end

-- Expose module and trigger registration
_G.AIF = _G.AIF or {}
_G.AIF.Templates = AIF_Templates
AIF_Templates.RegisterAll()

return AIF_Templates

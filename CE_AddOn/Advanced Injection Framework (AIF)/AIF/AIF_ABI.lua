-- ============================================================================
-- AIF Pro - Module: ABI (Application Binary Interface) & Register Management
-- File: AIF/AIF_ABI.lua
-- ============================================================================

local AIF_ABI = {}

-- Utility: Add unique elements to a collection
local function AddUnique(collection, set, item)
    if not item or item == '' or item == 'rsp' or item == 'esp' or item == 'sp' then return end
    if not set[item] then 
        set[item] = true
        collection[#collection + 1] = item 
    end
end

-- Analyzes the register usage across a block of decoded instructions
function AIF_ABI.AnalyzeHookRegisters(decodedInstructions, is64Bit, isARM)
    local analysis = {
        usedRegs = {},
        usedSet = {},
        usesSIMD = false,
        ripCount = 0,
        relocCount = 0
    }
    for i = 1, #decodedInstructions do
        local inst = decodedInstructions[i]
        
        -- Track SIMD usage for advanced state preservation (Checks any XMM/YMM/ZMM or ARM Q/V usage)
        local lowerText = inst.rawText:lower()
        if lowerText:find("xmm") or lowerText:find("ymm") or lowerText:find("zmm") or lowerText:match("v%d+") or lowerText:match("q%d+") then
            analysis.usesSIMD = true
        end

        -- Track relocation metrics
        if inst.isRIPRelative then analysis.ripCount = analysis.ripCount + 1 end
        if inst.isRelativeJump or inst.isRelativeCall then analysis.relocCount = analysis.relocCount + 1 end

        -- Analyze registers involved in memory addressing
        for _, op in ipairs(inst.operands) do
            local memData = _G.AIF.Decoder.AnalyzeMemoryOperand(op, is64Bit, isARM)
            if memData.isMemory and memData.baseRegister then
                AddUnique(analysis.usedRegs, analysis.usedSet, memData.baseRegister)
            end
            
            -- Basic tokenization for general register usage (reads/writes)
            local registerMap
            if isARM then
                registerMap = _G.AIF.Decoder.RegisterAliasesARM or {}
            else
                registerMap = is64Bit and _G.AIF.Decoder.RegisterAliases64 or _G.AIF.Decoder.RegisterAliases32
            end
            
            for tok in op:lower():gmatch("[_%a][_%w]*") do
                local reg = registerMap[tok]
                if reg then AddUnique(analysis.usedRegs, analysis.usedSet, reg) end
            end
        end
    end
    return analysis
end

-- Selects unused scratch registers required for dynamic calculations
function AIF_ABI.ChooseScratchRegisters(analysis, is64Bit, requiredCount, isARM)
    local pool = {}
    local extendedPool = {}
    
    if isARM then
        -- Standard safe scratch registers for ARM64
        pool = { 'x8', 'x9', 'x10', 'x11', 'x12', 'x13', 'x14', 'x15' }
        -- Extended risky pool for complex hooks
        extendedPool = { 'x16', 'x17', 'x18' }
    else
        -- Volatile registers prioritized for scratch usage in x86/x64
        pool = is64Bit and { 'r11', 'r10', 'r9', 'r8', 'rdi', 'rsi', 'rdx', 'rcx', 'rbx', 'rax' }
                       or { 'edi', 'esi', 'edx', 'ecx', 'ebx', 'eax' }
    end
    
    -- Combine pools if ARM
    local fullPool = {}
    for _, r in ipairs(pool) do table.insert(fullPool, r) end
    if isARM then
        for _, r in ipairs(extendedPool) do table.insert(fullPool, r) end
    end
    
    local allocated = {}
    local extendedUsed = false
    
    for _, reg in ipairs(fullPool) do
        if not analysis.usedSet[reg] then
            table.insert(allocated, reg)
            
            -- Check if we are tapping into the dangerous ARM registers
            if isARM and (reg == 'x16' or reg == 'x17' or reg == 'x18') then
                extendedUsed = true
            end
            
            if #allocated >= requiredCount then break end
        end
    end
    
    if extendedUsed and _G.AIF and _G.AIF.DebugLog then
        _G.AIF.DebugLog("=======================================================")
        _G.AIF.DebugLog("[WARNING] Extended ARM64 Scratch-Pool (x16-x18) ACTIVATED!")
        _G.AIF.DebugLog("[DANGER] x16 / x17 (Intra-Procedure-Call) & x18 (Platform Register)")
        _G.AIF.DebugLog("[DANGER] These registers can be used by OS routines.")
        _G.AIF.DebugLog("[DANGER] Expect potential system crashes during execution.")
        _G.AIF.DebugLog("=======================================================")
    end
    
    return allocated
end

-- Converts a 64-bit register to its 32-bit equivalent
function AIF_ABI.To32BitRegister(reg, isARM)
    if isARM then
        local map = { x0='w0', x1='w1', x2='w2', x3='w3', x4='w4', x5='w5', x6='w6', x7='w7', x8='w8', x9='w9' }
        return map[reg] or reg
    end
    local map = { 
        rax='eax', rbx='ebx', rcx='ecx', rdx='edx', 
        rsi='esi', rdi='edi', rbp='ebp', 
        r8='r8d', r9='r9d', r10='r10d', r11='r11d', 
        r12='r12d', r13='r13d', r14='r14d', r15='r15d' 
    }
    return map[reg] or reg
end

-- Generates ABI-compliant push/pop operations, stack alignment, and shadow space allocation
function AIF_ABI.GenerateSaveRestoreBlock(is64Bit, regsToSave, saveFlags, indent, detectedBaseReg, detectedDestReg, usesSIMD, isARM)
    indent = indent or "  "
    local pushLines = {}
    local popLines = {}
    
    local config = _G.AIF and _G.AIF.Config or { PushAll = false }

    if isARM then
        table.insert(pushLines, indent .. "// --- ARM64 ABI & Stack Safe Prep ---")
        
        local regsToPush = {}
        if config.PushAll then
            regsToPush = {"x0","x1","x2","x3","x4","x5","x6","x7","x8","x9","x10","x11","x12","x13","x14","x15","x16","x17","x18","x19","x20","x21","x22","x23","x24","x25","x26","x27","x28","fp","lr"}
        else
            regsToPush = regsToSave or {}
        end

        local filteredRegs = {}
        for _, reg in ipairs(regsToPush) do
            if reg ~= detectedBaseReg and reg ~= detectedDestReg then
                table.insert(filteredRegs, reg)
            end
        end

        if saveFlags then
            table.insert(pushLines, indent .. "mrs x0, nzcv // Backup CPU Flags")
            table.insert(pushLines, indent .. "stp x0, xzr, [sp, #-16]!")
            table.insert(popLines, 1, indent .. "ldp x0, xzr, [sp], #16\n" .. indent .. "msr nzcv, x0")
        end

        -- In ARM64, we push in pairs using STP to maintain 16-byte alignment
        for i = 1, #filteredRegs, 2 do
            local r1 = filteredRegs[i]
            local r2 = filteredRegs[i+1]
            if r2 then
                table.insert(pushLines, string.format("%sstp %s, %s, [sp, #-16]!", indent, r1, r2))
                table.insert(popLines, 1, string.format("%sldp %s, %s, [sp], #16", indent, r1, r2))
            else
                -- Odd register out: pad with xzr (Zero Register) to maintain 16-byte alignment
                table.insert(pushLines, string.format("%sstp %s, xzr, [sp, #-16]!", indent, r1))
                table.insert(popLines, 1, string.format("%sldp %s, xzr, [sp], #16", indent, r1))
            end
        end

        if usesSIMD then
            table.insert(pushLines, indent .. "// SIMD Save Space (q0-q7)")
            for i = 0, 7, 2 do
                table.insert(pushLines, string.format("%sstp q%d, q%d, [sp, #-32]!", indent, i, i+1))
                table.insert(popLines, 1, string.format("%sldp q%d, q%d, [sp], #32", indent, i, i+1))
            end
        end

        table.insert(pushLines, indent .. "// -----------------------------------")
        table.insert(popLines, 1, indent .. "// --- ARM64 ABI & Stack Restore ---")
        
        return table.concat(pushLines, "\n"), table.concat(popLines, "\n")
    end

    -- Setup standard ABI stack frame for x86/x64
    if is64Bit then
        table.insert(pushLines, indent .. "// --- ABI & Stack Safe Prep ---")
        table.insert(pushLines, indent .. "push rbp")
        table.insert(pushLines, indent .. "mov rbp, rsp")
        table.insert(pushLines, indent .. "and rsp, -20  // 16-Byte Stack Alignment (-10 hex = -16 dec)")
        
        if usesSIMD then
            table.insert(pushLines, indent .. "sub rsp, 100  // SIMD Save Space (All XMM0-XMM15 registers)")
            for i = 0, 15 do
                table.insert(pushLines, string.format("%smovdqu [rsp+%X], xmm%d", indent, i * 16, i))
            end
        end
        
        table.insert(pushLines, indent .. "sub rsp, 28   // 32-Byte Shadow Space + 8-Byte Padding")
        table.insert(pushLines, indent .. "// -----------------------------")
    end

    if saveFlags then 
        table.insert(pushLines, indent .. (is64Bit and "pushfq" or "pushfd")) 
    end

    -- Process register pushing
    if config.PushAll then
        local pushRegs = is64Bit and {"rax", "rbx", "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"}
                                   or {"eax", "ebx", "ecx", "edx", "esi", "edi"}
        local popRegs  = is64Bit and {"r15", "r14", "r13", "r12", "r11", "r10", "r9", "r8", "rdi", "rsi", "rdx", "rcx", "rbx", "rax"}
                                   or {"edi", "esi", "edx", "ecx", "ebx", "eax"}
        
        for _, reg in ipairs(pushRegs) do
            if reg ~= detectedBaseReg and reg ~= detectedDestReg then 
                table.insert(pushLines, indent .. "push " .. reg) 
            end
        end
        
        for _, reg in ipairs(popRegs) do
            if reg ~= detectedBaseReg and reg ~= detectedDestReg then 
                table.insert(popLines, indent .. "pop " .. reg) 
            end
        end
    else
        for _, reg in ipairs(regsToSave or {}) do 
            table.insert(pushLines, indent .. "push " .. reg) 
        end
        for i = #(regsToSave or {}), 1, -1 do 
            table.insert(popLines, indent .. "pop " .. regsToSave[i]) 
        end
    end

    if saveFlags then 
        table.insert(popLines, indent .. (is64Bit and "popfq" or "popfd")) 
    end

    -- Teardown ABI stack frame
    if is64Bit then
        table.insert(popLines, indent .. "// --- ABI & Stack Restore ---")
        table.insert(popLines, indent .. "add rsp, 28")
        
        if usesSIMD then
            for i = 15, 0, -1 do
                table.insert(popLines, string.format("%smovdqu xmm%d, [rsp+%X]", indent, i, i * 16))
            end
            table.insert(popLines, indent .. "add rsp, 100")
        end
        
        table.insert(popLines, indent .. "mov rsp, rbp")
        table.insert(popLines, indent .. "pop rbp")
        table.insert(popLines, indent .. "// ---------------------------")
    end

    return table.concat(pushLines, "\n"), table.concat(popLines, "\n")
end

-- Expose module to the global AIF namespace
_G.AIF.ABI = AIF_ABI
return AIF_ABI

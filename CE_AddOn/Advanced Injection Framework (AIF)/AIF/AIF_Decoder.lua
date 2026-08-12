-- ============================================================================
-- AIF Pro - Module: Decoder
-- File: AIF/AIF_Decoder.lua
-- ============================================================================

local AIF_Decoder = {}

-- Register map for architecture-specific analysis
AIF_Decoder.RegisterAliases64 = {
    rax='rax', eax='rax', ax='rax', al='rax', ah='rax',
    rbx='rbx', ebx='rbx', bx='rbx', bl='rbx', bh='rbx',
    rcx='rcx', ecx='rcx', cx='rcx', cl='rcx', ch='rcx',
    rdx='rdx', edx='rdx', dx='rdx', dl='rdx', dh='rdx',
    rsi='rsi', esi='rsi', si='rsi', sil='rsi',
    rdi='rdi', edi='rdi', di='rdi', dil='rdi',
    rbp='rbp', ebp='rbp', bp='rbp', bpl='rbp',
    rsp='rsp', esp='rsp', sp='rsp', spl='rsp',
    r8='r8', r8d='r8', r8w='r8', r8b='r8',
    r9='r9', r9d='r9', r9w='r9', r9b='r9',
    r10='r10', r10d='r10', r10w='r10', r10b='r10',
    r11='r11', r11d='r11', r11w='r11', r11b='r11',
    r12='r12', r12d='r12', r12w='r12', r12b='r12',
    r13='r13', r13d='r13', r13w='r13', r13b='r13',
    r14='r14', r14d='r14', r14w='r14', r14b='r14',
    r15='r15', r15d='r15', r15w='r15', r15b='r15'
}

AIF_Decoder.RegisterAliases32 = {
    eax='eax', ax='eax', al='eax', ah='eax',
    ebx='ebx', bx='ebx', bl='ebx', bh='ebx',
    ecx='ecx', cx='ecx', cl='ecx', ch='ecx',
    edx='edx', dx='edx', dl='edx', dh='edx',
    esi='esi', si='esi',
    edi='edi', di='edi',
    ebp='ebp', bp='ebp',
    esp='esp', sp='esp'
}

-- ARM64 Register Map
AIF_Decoder.RegisterAliasesARM = {
    x0='x0', w0='x0', x1='x1', w1='x1', x2='x2', w2='x2', x3='x3', w3='x3',
    x4='x4', w4='x4', x5='x5', w5='x5', x6='x6', w6='x6', x7='x7', w7='x7',
    x8='x8', w8='x8', x9='x9', w9='x9', x10='x10', w10='x10', x11='x11', w11='x11',
    x12='x12', w12='x12', x13='x13', w13='x13', x14='x14', w14='x14', x15='x15', w15='x15',
    x16='x16', w16='x16', x17='x17', w17='x17', x18='x18', w18='x18', x19='x19', w19='x19',
    x20='x20', w20='x20', x21='x21', w21='x21', x22='x22', w22='x22', x23='x23', w23='x23',
    x24='x24', w24='x24', x25='x25', w25='x25', x26='x26', w26='x26', x27='x27', w27='x27',
    x28='x28', w28='x28', fp='fp', x29='fp', w29='fp', lr='lr', x30='lr', w30='lr', sp='sp'
}

-- Extracts the clean assembly instruction string without memory addresses
function AIF_Decoder.CleanOpcode(address)
    local rawDisasm = disassemble(address)
    if not rawDisasm or rawDisasm == "" then return "" end
    
    local firstDash = rawDisasm:find("%s%-%s")
    if firstDash then
        local secondDash = rawDisasm:find("%s%-%s", firstDash + 3)
        if secondDash then
            local inst = rawDisasm:sub(secondDash + 3)
            return inst:match("^%s*(.-)%s*$") or inst
        end
    end
    return rawDisasm
end

-- Splits the operand string into an iterable table, preserving bracket enclosures
function AIF_Decoder.ParseOperands(operandString)
    local out = {}
    local current = ""
    local depth = 0
    
    for i = 1, #operandString do
        local ch = operandString:sub(i, i)
        if ch == '[' then depth = depth + 1 end
        if ch == ']' and depth > 0 then depth = depth - 1 end
        
        if ch == ',' and depth == 0 then
            table.insert(out, current:match("^%s*(.-)%s*$"))
            current = ""
        else
            current = current .. ch
        end
    end
    
    current = current:match("^%s*(.-)%s*$")
    if current ~= "" then table.insert(out, current) end
    
    return out
end

-- Extracts structural data from a memory operand (Scale, Index, Base, Displacement)
function AIF_Decoder.AnalyzeMemoryOperand(operandStr, is64Bit, isARM)
    local memData = {
        isMemory = false,
        baseRegister = nil,
        indexRegister = nil,
        scale = 1,
        displacement = 0,
        isRIP = false
    }
    
    local bracketContent = operandStr:match("%[(.-)%]")
    if not bracketContent then return memData end
    
    memData.isMemory = true
    bracketContent = bracketContent:lower()
    
    if bracketContent:find("rip") or bracketContent:find("eip") then
        memData.isRIP = true
        return memData
    end
    
    -- Extract potential base registers for scratch allocation routines
    local registerMap
    if isARM then
        registerMap = AIF_Decoder.RegisterAliasesARM
    else
        registerMap = is64Bit and AIF_Decoder.RegisterAliases64 or AIF_Decoder.RegisterAliases32
    end
    
    for tok in bracketContent:gmatch("[_%a][_%w]*") do
        local reg = registerMap[tok]
        if reg and not memData.baseRegister then
            memData.baseRegister = reg
        end
    end
    
    return memData
end

-- Performs a full structural decode of an instruction at a given memory address
function AIF_Decoder.DecodeInstruction(address, is64Bit, isARM)
    local size = getInstructionSize(address)
    if not size or size == 0 then size = 1 end
    local instData = {
        address = address,
        size = size,
        bytes = readBytes(address, size, true) or {},
        rawText = "",
        mnemonic = "",
        operands = {},
        isRelativeJump = false,
        isRelativeCall = false,
        isRIPRelative = false,
        readsMemory = false,
        writesMemory = false
    }
    
    instData.rawText = AIF_Decoder.CleanOpcode(address)
    if instData.rawText == "" then return instData end
    
    local mnemonic, operandStr = instData.rawText:match("^(%S+)%s*(.*)$")
    instData.mnemonic = (mnemonic or ""):lower()
    instData.operands = AIF_Decoder.ParseOperands(operandStr or "")
    
    -- Identify control flow properties (JMP für x86 / B für ARM)
    if instData.mnemonic:match("^j") or instData.mnemonic:match("^b") then instData.isRelativeJump = true end
    if instData.mnemonic == "call" or instData.mnemonic:match("^bl") then instData.isRelativeCall = true end
    if instData.mnemonic:match("^loop") then instData.isRelativeJump = true end
    
    -- Analyze operand memory interactions
    for _, op in ipairs(instData.operands) do
        local memAnalysis = AIF_Decoder.AnalyzeMemoryOperand(op, is64Bit, isARM)
        if memAnalysis.isMemory then
            if memAnalysis.isRIP then instData.isRIPRelative = true end
            
            -- Basic instruction intent heuristics
            if op == instData.operands[1] and instData.mnemonic ~= "cmp" and instData.mnemonic ~= "test" then
                instData.writesMemory = true
            else
                instData.readsMemory = true
            end
        end
    end
    
    return instData
end

-- Expose module to the global AIF namespace
_G.AIF = _G.AIF or {}
_G.AIF.Decoder = AIF_Decoder
return AIF_Decoder

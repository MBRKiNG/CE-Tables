-- ============================================================================
-- AIF Pro - Module: PE Cave Injector & PE Analyzer
-- File: AIF/AIF_FilePatcher.lua
-- ============================================================================

local AIF_FilePatcher = {}

-- Helper: Read 32-bit integer (DWORD) from file
local function ReadDWORD(f)
    local s = f:read(4)
    if not s or #s < 4 then return 0 end
    local b1, b2, b3, b4 = s:byte(1, 4)
    return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

-- Helper: Read 16-bit integer (WORD) from file
local function ReadWORD(f)
    local s = f:read(2)
    if not s or #s < 2 then return 0 end
    local b1, b2 = s:byte(1, 2)
    return b1 + (b2 * 256)
end

-- Parses the PE Header to get Section Information
local function ParsePEHeaders(filePath)
    local f = io.open(filePath, "rb")
    if not f then return nil, "Failed to open file for reading." end

    -- Check DOS MZ signature
    local mz = f:read(2)
    if mz ~= "MZ" then
        f:close()
        return nil, "Invalid PE file (No MZ signature)."
    end

    -- Get PE header offset
    f:seek("set", 0x3C)
    local peOffset = ReadDWORD(f)

    -- Check PE signature
    f:seek("set", peOffset)
    local peSig = f:read(4)
    if peSig ~= "PE\0\0" then
        f:close()
        return nil, "Invalid PE file (No PE signature)."
    end

    -- Read File Header
    local machine = ReadWORD(f)
    local numberOfSections = ReadWORD(f)
    f:seek("cur", 12) -- Skip TimeDateStamp, PointerToSymbolTable, NumberOfSymbols
    local sizeOfOptionalHeader = ReadWORD(f)
    f:seek("cur", 2) -- Skip Characteristics

    local optionalHeaderOffset = f:seek()
    
    -- Read Optional Header Magic to determine 32/64 bit
    local magic = ReadWORD(f)
    local imageBase = 0
    
    if magic == 0x10B then -- PE32
        f:seek("set", optionalHeaderOffset + 28)
        imageBase = ReadDWORD(f)
    elseif magic == 0x20B then -- PE32+ (64-bit)
        f:seek("set", optionalHeaderOffset + 24)
        local baseLow = ReadDWORD(f)
        local baseHigh = ReadDWORD(f)
        imageBase = baseLow + (baseHigh * 4294967296)
    else
        f:close()
        return nil, "Unknown PE Optional Header magic."
    end

    local sectionsOffset = optionalHeaderOffset + sizeOfOptionalHeader
    f:seek("set", sectionsOffset)

    local sections = {}
    for i = 1, numberOfSections do
        local nameRaw = f:read(8)
        local name = nameRaw:match("^([%w%.]+)") or "UNKNOWN"
        local virtualSize = ReadDWORD(f)
        local virtualAddress = ReadDWORD(f)
        local sizeOfRawData = ReadDWORD(f)
        local pointerToRawData = ReadDWORD(f)
        f:seek("cur", 16) -- Skip rest of section header

        table.insert(sections, {
            Name = name,
            VirtualSize = virtualSize,
            VirtualAddress = virtualAddress,
            SizeOfRawData = sizeOfRawData,
            PointerToRawData = pointerToRawData
        })
    end

    f:close()
    return { ImageBase = imageBase, Sections = sections }, nil
end

-- Converts a Virtual Address (RAM) to a Raw File Offset
local function RvaToOffset(rva, sections)
    for _, sec in ipairs(sections) do
        if rva >= sec.VirtualAddress and rva < (sec.VirtualAddress + sec.VirtualSize) then
            return sec.PointerToRawData + (rva - sec.VirtualAddress), sec
        end
    end
    return nil, nil
end

-- Scans the raw file for a code cave (00 or CC)
local function FindCodeCaveInFile(filePath, section, paddingByte, requiredSize)
    local f = io.open(filePath, "rb")
    if not f then return nil end

    f:seek("set", section.PointerToRawData)
    local sectionData = f:read(section.SizeOfRawData)
    f:close()

    if not sectionData then return nil end

    local targetPattern = string.char(paddingByte):rep(requiredSize)
    local foundOffset = sectionData:find(targetPattern, 1, true)

    if foundOffset then
        -- Return absolute raw offset
        return section.PointerToRawData + (foundOffset - 1)
    end

    return nil
end

-- Core Generation Function
function AIF_FilePatcher.GenerateStandaloneScript(injectAddressStr, caveSize, paddingByte, targetFile)
    -- 1. Evaluate Address in RAM safely using pcall
    local successInject, injectAddressRAM = pcall(getAddress, injectAddressStr)
    if not successInject or injectAddressRAM == 0 then
        return nil, "Could not resolve injection address in RAM.\nAre you attached to the game?\nAddress: " .. tostring(injectAddressStr)
    end

    -- 2. Smart Disassembler: Calculate required hook size (>= 5 bytes) & fetch original opcodes
    local hookSize = 0
    local originalInstructions = {}
    local currentAddr = injectAddressRAM
    
    while hookSize < 5 do
        local instSize = getInstructionSize(currentAddr)
        if instSize == 0 then
            return nil, "Failed to disassemble instruction at: " .. string.format("0x%X", currentAddr)
        end
        local disasmStr = disassemble(currentAddr)
        local cleanDisasm = disasmStr:match("%- (.*)") or disasmStr
        
        local bytesTable = readBytes(currentAddr, instSize, true)
        local hexBytes = {}
        local luaBytes = {}
        for i=1, #bytesTable do 
            table.insert(hexBytes, string.format("%02X", bytesTable[i]))
            table.insert(luaBytes, string.format("0x%02X", bytesTable[i]))
        end
        local byteStr = table.concat(hexBytes, " ")
        local luaByteStr = table.concat(luaBytes, ", ")
        
        table.insert(originalInstructions, { size = instSize, disasm = cleanDisasm, bytes = byteStr, luaBytes = luaByteStr })
        
        hookSize = hookSize + instSize
        currentAddr = currentAddr + instSize
    end
    
    local nopCount = hookSize - 5

    -- 3. Parse PE Header
    local peData, err = ParsePEHeaders(targetFile)
    if not peData then return nil, "PE Parse Error: " .. err end

    -- 4. Calculate RVA (Relative Virtual Address) based on running module
    local moduleName = injectAddressStr:match('^"([^"]+)"')
    if not moduleName then
        moduleName = injectAddressStr:match('^([^%+]+)')
    end
    
    local successBase, moduleBaseRAM = pcall(getAddress, moduleName)
    if not successBase or moduleBaseRAM == 0 then
        return nil, "Could not find module base in RAM.\nAre you attached to the process?\nModule: " .. tostring(moduleName)
    end

    local rva = injectAddressRAM - moduleBaseRAM

    -- 5. Find Section & Raw Offset of Injection Point
    local injectRawOffset, injectSection = RvaToOffset(rva, peData.Sections)
    if not injectRawOffset then
        return nil, "Injection address does not map to a valid PE section."
    end

    -- 6. Scan for Code Cave in the SAME section
    local caveRawOffset = FindCodeCaveInFile(targetFile, injectSection, paddingByte, caveSize)
    if not caveRawOffset then
        return nil, string.format("Could not find a code cave of size %d in section %s.", caveSize, injectSection.Name)
    end

    -- 7. Calculate Jumps based on Virtual Addresses (RVA)
    local caveRva = injectSection.VirtualAddress + (caveRawOffset - injectSection.PointerToRawData)
    
    -- JMP from Inject to Cave
    local jmpToCaveDist = caveRva - rva - 5
    -- JMP from Cave back to Inject (+ hookSize)
    local jmpBackDist = (rva + hookSize) - (caveRva + caveSize - 5) - 5 

    -- Format distances directly into safe Lua string arguments: "0xAA, 0xBB, 0xCC, 0xDD"
    local function toHexLE_LuaArgs(num)
        if num < 0 then num = 0x100000000 + num end
        local b1 = math.floor(num % 256)
        local b2 = math.floor((num / 256) % 256)
        local b3 = math.floor((num / 65536) % 256)
        local b4 = math.floor((num / 16777216) % 256)
        return string.format("0x%02X, 0x%02X, 0x%02X, 0x%02X", b1, b2, b3, b4)
    end

    -- Format distances for clean comments: "AA BB CC DD"
    local function toHexLE_Comment(num)
        if num < 0 then num = 0x100000000 + num end
        local b1 = math.floor(num % 256)
        local b2 = math.floor((num / 256) % 256)
        local b3 = math.floor((num / 65536) % 256)
        local b4 = math.floor((num / 16777216) % 256)
        return string.format("%02X %02X %02X %02X", b1, b2, b3, b4)
    end

    -- 8. Generate Standalone Script
    local script = {}
    table.insert(script, "-- ============================================================================")
    table.insert(script, "-- Standalone PE Cave Injector")
    table.insert(script, "-- Target: " .. targetFile:match("([^/\\]+)$"))
    table.insert(script, "-- Section: " .. injectSection.Name)
    table.insert(script, "-- ============================================================================")
    table.insert(script, "-- Memory / RAM Offsets (For Cheat Engine Live-Debugging)")
    table.insert(script, string.format("-- Injection Point : \"%s\"+%X", moduleName, rva))
    table.insert(script, string.format("-- Code Cave Start : \"%s\"+%X", moduleName, caveRva))
    table.insert(script, string.format("-- Return Address  : \"%s\"+%X", moduleName, rva + hookSize))
    table.insert(script, "--")
    table.insert(script, "-- Control Flow:")
    table.insert(script, string.format("-- \"%s\"+%X : jmp \"%s\"+%X", moduleName, rva, moduleName, caveRva))
    table.insert(script, string.format("-- \"%s\"+%X : jmp \"%s\"+%X", moduleName, caveRva + caveSize - 5, moduleName, rva + hookSize))
    table.insert(script, "-- ============================================================================")
    table.insert(script, "")
    table.insert(script, "local targetFile = [[Put_Your_File_Path_Here]]")
    table.insert(script, "")
    table.insert(script, "local function PatchFile()")
    table.insert(script, "    local file = io.open(targetFile, 'r+b')")
    table.insert(script, "    if not file then")
    table.insert(script, "        print('Error: Could not open file for writing.')")
    table.insert(script, "        return")
    table.insert(script, "    end")
    table.insert(script, "")
    
    table.insert(script, string.format("    -- [1] Write Hook JMP at Injection Point (Raw Offset: 0x%X)", injectRawOffset))
    table.insert(script, string.format("    file:seek('set', 0x%X)", injectRawOffset))
    
    local jmpWriteStr = "    file:write(string.char(0xE9, " .. toHexLE_LuaArgs(jmpToCaveDist)
    if nopCount > 0 then
        -- Add NOPs (0x90) if hook size is greater than 5
        jmpWriteStr = jmpWriteStr .. ", " .. string.rep("0x90, ", nopCount):sub(1, -3)
        table.insert(script, string.format("    -- JMP Distance: %s (Padded with %d NOP(s) for a %d byte hook)", toHexLE_Comment(jmpToCaveDist), nopCount, hookSize))
    else
        table.insert(script, string.format("    -- JMP Distance: %s", toHexLE_Comment(jmpToCaveDist)))
    end
    jmpWriteStr = jmpWriteStr .. "))"
    table.insert(script, jmpWriteStr)
    table.insert(script, "")
    
    table.insert(script, string.format("    -- [2] Write Code Cave & Return JMP (Raw Offset: 0x%X)", caveRawOffset))
    table.insert(script, string.format("    file:seek('set', 0x%X)", caveRawOffset))
    table.insert(script, "    ")
    
    -- Write Original Code Block
    table.insert(script, "    -- --- Original Code ---")
    local allLuaBytes = {}
    for _, inst in ipairs(originalInstructions) do
        table.insert(script, string.format("    -- %-20s - %s", inst.bytes, inst.disasm))
        table.insert(allLuaBytes, inst.luaBytes)
    end
    table.insert(script, "    -- ")
    table.insert(script, "    -- Restore Original Bytes (Uncomment to execute original instructions):")
    table.insert(script, "    -- file:write(string.char(" .. table.concat(allLuaBytes, ", ") .. "))")
    table.insert(script, "    -- ---------------------")
    table.insert(script, "    ")
    
    table.insert(script, "    -- TODO: Add your custom Hex opcodes here via file:write(string.char(...))")
    table.insert(script, "    -- Example: file:write(string.char(0x90, 0x90, 0x90))")
    table.insert(script, "    ")
    table.insert(script, string.format("    -- Return JMP (Place this exactly at the end of your custom code)"))
    table.insert(script, string.format("    -- Note: This distance is calculated from the END of the allocated %d bytes.", caveSize))
    table.insert(script, string.format("    -- If your custom code is shorter, the return JMP distance must be recalculated."))
    table.insert(script, string.format("    -- file:seek('set', 0x%X) -- Go to end of cave for return JMP", caveRawOffset + caveSize - 5))
    table.insert(script, string.format("    -- file:write(string.char(0xE9, %s))", toHexLE_LuaArgs(jmpBackDist)))
    table.insert(script, "")
    table.insert(script, "    file:close()")
    table.insert(script, "    print('File patching completed successfully.')")
    table.insert(script, "end")
    table.insert(script, "")
    table.insert(script, "PatchFile()")

    return table.concat(script, "\n")
end

-- GUI for the File Patcher
function AIF_FilePatcher.ShowGUI()
    -- ABSOLUTER GLOBALER SINGLETON CHECK: Fest verankert im _G.AIF Namespace
    if _G.AIF.PECaveForm then
        _G.AIF.PECaveForm.show()
        _G.AIF.PECaveForm.bringToFront()
        return
    end

    local frm = createForm(true)
    _G.AIF.PECaveForm = frm -- Global registrieren
    
    -- ECHTER SINGLETON: 1 = caHide. Fenster bleibt sicher im RAM und wird nur versteckt!
    frm.OnClose = function(sender)
        return 1 -- caHide
    end

    frm.Caption = "AIF Pro - PE Cave Injector"
    frm.Width = 400
    frm.Height = 250
    frm.Position = poScreenCenter
    frm.BorderStyle = bsSingle

    local lblInject = createLabel(frm)
    lblInject.Caption = "Injection Address (e.g. \"Game.exe\"+ABC4):"
    lblInject.Left = 15; lblInject.Top = 15; lblInject.Width = 350

    local edtInject = createEdit(frm)
    edtInject.Text = ""
    edtInject.Left = 15; edtInject.Top = 35; edtInject.Width = 370

    local lblSize = createLabel(frm)
    lblSize.Caption = "Code Cave Size (Bytes):"
    lblSize.Left = 15; lblSize.Top = 70

    local edtSize = createEdit(frm)
    edtSize.Text = "128"
    edtSize.Left = 150; edtSize.Top = 67; edtSize.Width = 80

    local lblPadding = createLabel(frm)
    lblPadding.Caption = "Padding Scan Type:"
    lblPadding.Left = 15; lblPadding.Top = 105

    local cbPadding = createComboBox(frm)
    cbPadding.Items.add("Scan for 00 Padding")
    cbPadding.Items.add("Scan for CC (INT 3) Padding")
    cbPadding.ItemIndex = 0
    cbPadding.Left = 150; cbPadding.Top = 102; cbPadding.Width = 200

    local btnGenerate = createButton(frm)
    btnGenerate.Caption = "Select Target File & Generate Injector"
    btnGenerate.Left = 15; btnGenerate.Top = 150; btnGenerate.Width = 370
    btnGenerate.Height = 40

    btnGenerate.OnClick = function()
        if edtInject.Text == "" then
            showMessage("Please enter an injection address.")
            return
        end

        local size = tonumber(edtSize.Text)
        if not size or size < 5 then
            showMessage("Please enter a valid cave size (min 5 bytes).")
            return
        end

        local padding = (cbPadding.ItemIndex == 0) and 0x00 or 0xCC

        local ok, result = pcall(function()
            local dlg = createOpenDialog()
            dlg.Title = "Select the raw executable or DLL to patch"
            dlg.Filter = "Executables (*.exe;*.dll)|*.exe;*.dll|All Files (*.*)|*.*"
            
            if dlg.Execute() then
                local targetFile = dlg.FileName
                local script, err = AIF_FilePatcher.GenerateStandaloneScript(edtInject.Text, size, padding, targetFile)
                
                if not script then
                    showMessage("Generation Failed:\n\n" .. tostring(err))
                else
                    local outFrm = createForm(false)
                    outFrm.Caption = "Generated PE Cave Injector"
                    outFrm.Width = 600
                    outFrm.Height = 400
                    outFrm.Position = poScreenCenter
                    
                    local memo = createMemo(outFrm)
                    memo.Align = alClient
                    memo.ScrollBars = ssBoth
                    memo.Lines.Text = script
                    
                    frm.hide() -- SICHER: Fenster nur verstecken, niemals zerstören!
                    outFrm.showModal()
                end
            end
            dlg.destroy()
        end)
        
        if not ok then
            showMessage("A critical error occurred:\n" .. tostring(result))
        end
    end
end

-- Expose to global namespace
_G.AIF = _G.AIF or {}
_G.AIF.FilePatcher = AIF_FilePatcher
return AIF_FilePatcher

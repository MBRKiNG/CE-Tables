================================================================================
                AIF PRO v2.0 - OFFICIAL DOCUMENTATION WiP
              Advanced Injection Framework for Cheat Engine
================================================================================

MIT License

Copyright (c) 2026 MBRKiNG

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
============================================================================


Repository: https://github.com/MBRKiNG/CE-Tables
Forum: https://opencheattables.com/


================================================================================
TABLE OF CONTENTS
================================================================================

1. OVERVIEW & INTRODUCTION
2. INSTALLATION & SETUP
3. CORE FEATURES
4. MODULE REFERENCE
5. CONFIGURATION GUIDE
6. TEMPLATES REFERENCE
7. ADVANCED USAGE
8. TROUBLESHOOTING
9. API REFERENCE
10. LICENSE & CREDITS

================================================================================
1. OVERVIEW & INTRODUCTION
================================================================================

AIF Pro v2.0 is a comprehensive Auto-Assembler code generation and injection
framework designed for Cheat Engine. It provides professional-grade templates,
validators, and utilities for creating complex memory patches with minimal
manual coding.

KEY FEATURES:
- Automatic AOB (Array of Bytes) signature generation with Smart Scanning
- Multiple injection templates (Patcher, Detour, Pointer Registration, Advanced)
- Support for x86, x64, ARM, and ARM64 architectures
- Lua-to-AutoAssembler transpiler with wildcard protection
- PE Cave Injector for standalone file patching
- Mono/IL2CPP integration for Unity games
- Comprehensive register analysis and ABI compliance
- Professional script generation with customizable headers
- Full validation system with preflight analysis

SUPPORTED PLATFORMS:
- Windows x86/x64 (via x86/x64 templates)
- ARM/ARM64 (iOS, Android via ARM templates)
- Mono/.NET (via Mono/IL2CPP integration)
- Unity Engine games

================================================================================
2. INSTALLATION & SETUP
================================================================================

INSTALLATION STEPS:

1. Download the AIF Pro Framework files:
   - ADDON_AIF_v2_0.lua (Main bootstrapper)
   - AIF/ folder (All module files)

2. Copy files to your Cheat Engine autorun directory:
   Windows: C:\Program Files\Cheat Engine\autorun\
   Or: %APPDATA%\Cheat Engine\autorun\

3. Restart Cheat Engine or reload the framework using the menu

4. Access AIF Pro from the main menu:
   Menu Bar → "AIF Pro"

DIRECTORY STRUCTURE:

Cheat Engine/
├── autorun/
│   ├── ADDON_AIF_v2_0.lua          (Main bootstrapper)
│   └── AIF/                        (Module directory)
│       ├── AIF_Utilities.lua       (Helper functions)
│       ├── AIF_Memory.lua          (Memory management)
│       ├── AIF_Decoder.lua         (Instruction decoder)
│       ├── AIF_Relocator.lua       (Instruction relocation)
│       ├── AIF_ABI.lua             (Register management)
│       ├── AIF_Scanner.lua         (x86/x64 AOB scanner)
│       ├── AIF_ScannerARM.lua      (ARM/ARM64 AOB scanner)
│       ├── AIF_Validator.lua       (Injection validation)
│       ├── AIF_Templates.lua       (x86/x64 templates)
│       ├── AIF_TemplatesARM.lua    (ARM/ARM64 templates)
│       ├── AIF_MonoIL2CPP.lua      (Mono/.NET support)
│       ├── AIF_LuaTranspiler.lua   (AA to Lua converter)
│       ├── AIF_FilePatcher.lua     (PE Cave Injector)
│       └── AIF_Tests.lua           (Test suite)

================================================================================
3. CORE FEATURES
================================================================================

3.1 AUTOMATIC AOB GENERATION
----------------------------
The Smart AOB Scanner automatically generates unique signatures from code
patterns, eliminating manual pattern creation.

Features:
- Configurable minimum/maximum scan length
- Wildcard placement for relative instructions
- Module bounds and memory region scanning
- Uniqueness verification
- RIP-relative address handling (x86/x64)
- ARM/ARM64 instruction handling

Configuration Options:
- SmartAob: Enable/disable smart scanning mode
- AobMinScan: Minimum bytes for scanning (default: 8)
- AobMaxScan: Maximum bytes for scanning (default: 48)
- AobSpaces: Include spaces in generated AOB string
- UseModuleNamesInContext: Display addresses as Module+Offset

3.2 CODE TEMPLATES
------------------
AIF Pro provides four professional injection templates for each architecture:

TEMPLATE 1: Inline AOB Patcher
  Purpose: Simple inline code replacement
  Use Case: Changing opcodes without calling external code
  Features: Minimal footprint, inline modifications

TEMPLATE 2: Dynamic Detour Hook
  Purpose: Execute custom code with automatic register preservation
  Use Case: Complex logic, multiple operations
  Features: Stack alignment, flag preservation, SIMD support

TEMPLATE 3: Pointer Registration Detour
  Purpose: Extract and register base pointers from memory operations
  Use Case: Dynamic pointer tracking, data structure navigation
  Features: Automatic base register detection, pointer storage

TEMPLATE 4: Advanced Detour Hook (Data/Code Separation)
  Purpose: Separation of control logic and data structures
  Use Case: Toggleable features, complex state management
  Features: Flag-based activation, isolated data sections

3.3 ARCHITECTURE SUPPORT
------------------------

X86/X64 ARCHITECTURE:
- 32-bit (x86) and 64-bit (x64) support
- 5-byte or 14-byte jump options
- REX prefix detection
- Shadow space allocation (x64)
- Stack alignment (16-byte for x64)

ARM/ARM64 ARCHITECTURE:
- 32-bit and 64-bit ARM support
- Fixed 4-byte instruction size
- STP/LDP instruction pairs for alignment
- Platform register awareness (x16-x18)
- NEON SIMD register support

3.4 VALIDATION SYSTEM
---------------------
Pre-flight analysis ensures safe injection:
- Instruction size verification
- Return instruction detection
- Relative addressing identification
- Near-allocation requirement analysis
- Hook size overflow warnings

3.5 REGISTER & ABI MANAGEMENT
------------------------------
Automatic register state preservation:
- Volatile register analysis
- Scratch register allocation
- Architecture-specific calling conventions
- SIMD register detection and handling
- Flag preservation (CPU flags, NZCV)

3.6 LUA TRANSPILER
------------------
Convert Auto-Assembler code to native Lua scripts:
- Wildcard (*) protection mechanism
- Automatic registersymbol/dealloc expansion
- Time-hash isolation for multiple scripts
- Native CE Table compatibility
- Symbol and allocation tracking

3.7 PE CAVE INJECTOR
--------------------
Standalone file patching without runtime attachment:
- PE header parsing
- Section analysis
- Code cave discovery
- RVA calculation
- Standalone patch generation

3.8 MONO/IL2CPP INTEGRATION
----------------------------
Unity game support:
- Mono/IL2CPP data collector initialization
- Method symbol resolution
- JIT-compiled method information retrieval

================================================================================
4. MODULE REFERENCE
================================================================================

4.1 AIF_Utilities.lua
---------------------
Helper functions for common operations

Functions:
  SafeGetName(addr)
    Returns: Symbol name or hex string
    Purpose: Safely retrieve symbol names from addresses

  SanitizeSymbol(name)
    Returns: Valid symbol name or nil
    Purpose: Clean user input for symbol safety

  GetSymbolicDisasm(addr)
    Returns: Disassembly with replaced hex addresses
    Purpose: Display symbolic references in disassembly

4.2 AIF_Memory.lua
------------------
Memory allocation and resource cleanup management

Functions:
  GenerateExplicitDisableBlock(registeredSymbols, allocatedMemory)
    Returns: String containing unregister/dealloc commands

  GenerateAllocations(allocations, targetAddress, forceNear)
    Returns: String containing alloc commands

  GenerateRegisterBlock(symbols)
    Returns: String containing registersymbol commands

4.3 AIF_Decoder.lua
-------------------
Instruction decoding and analysis

Functions:
  DecodeInstruction(address, is64Bit, isARM)
    Returns: Table with decoded instruction data
    Fields: address, size, bytes, mnemonic, operands, isRelativeJump,
            isRelativeCall, isRIPRelative, readsMemory, writesMemory

  AnalyzeMemoryOperand(operandStr, is64Bit, isARM)
    Returns: Table with memory addressing details

  ParseOperands(operandString)
    Returns: Table of individual operands

  CleanOpcode(address)
    Returns: Clean assembly instruction without addresses

4.4 AIF_Relocator.lua
---------------------
Instruction relocation for stolen instructions

Functions:
  BuildRelocationBlock(baseAddress, decodedInstructions, symbolInput, skipCount)
    Returns: String with reassemble commands

  RequiresNearAllocation(decodedInstructions)
    Returns: Boolean indicating near-allocation requirement

4.5 AIF_ABI.lua
---------------
Application Binary Interface and register management

Functions:
  AnalyzeHookRegisters(decodedInstructions, is64Bit, isARM)
    Returns: Analysis table with used registers and SIMD usage

  ChooseScratchRegisters(analysis, is64Bit, requiredCount, isARM)
    Returns: Table of available scratch registers

  GenerateSaveRestoreBlock(is64Bit, regsToSave, saveFlags, indent, ...)
    Returns: Push and pop assembly sequences

  To32BitRegister(reg, isARM)
    Returns: 32-bit equivalent register name

4.6 AIF_Scanner.lua (x86/x64)
------------------------------
AOB signature generation for x86/x64 architecture

Functions:
  GenerateWildcardAOB(base)
    Returns: AOB string with wildcards for relative instructions

  GetModuleBounds(address)
    Returns: Module base and size

  FindRegionByAddress(addr)
    Returns: Memory region details

  CheckAOB(bytes, curModule)
    Returns: Boolean indicating unique match

4.7 AIF_ScannerARM.lua
----------------------
AOB signature generation for ARM/ARM64 architecture

Functions:
  GenerateWildcardAOB(base)
    Returns: AOB string optimized for ARM instructions

  GetModuleBounds(address)
    Returns: Module base and size

  FindRegionByAddress(addr)
    Returns: Memory region details

4.8 AIF_Validator.lua
---------------------
Injection site validation and safety analysis

Functions:
  ValidateInjectionSite(baseAddress, requiredBytes)
    Returns: Validation result table
    Fields: isSafe, warnings, stolenInstructions, totalSize, requiresNearAlloc

4.9 AIF_Templates.lua (x86/x64)
--------------------------------
Code generation templates for x86/x64 architecture

Functions:
  BuildProAobPatcher(injectAddr, symbolInput)
    Returns: Complete AOB Patcher script

  BuildProDynamicDetour(injectAddr, symbolInput, useFarJump)
    Returns: Complete Dynamic Detour Hook script

  BuildProBasePointer(injectAddr, symbolInput, baseInput, useFarJump)
    Returns: Complete Pointer Registration script

  BuildProAdvancedHook(injectAddr, symbolInput, useFarJump)
    Returns: Complete Advanced Detour Hook script

4.10 AIF_TemplatesARM.lua
--------------------------
Code generation templates for ARM/ARM64 architecture

Functions:
  BuildARMAobPatcher(injectAddr, symbolInput)
    Returns: Complete ARM AOB Patcher script

  BuildARMDynamicDetour(injectAddr, symbolInput)
    Returns: Complete ARM Dynamic Detour Hook script

  BuildARMBasePointer(injectAddr, symbolInput, baseInput)
    Returns: Complete ARM Pointer Registration script

  BuildARMAdvancedHook(injectAddr, symbolInput)
    Returns: Complete ARM Advanced Detour Hook script

4.11 AIF_LuaTranspiler.lua
---------------------------
Automatic conversion of Auto-Assembler to Lua

Functions:
  ConvertAAToLua(aaCode, baseTitle)
    Returns: Lua script with embedded Auto-Assembler code
    Features: Wildcard protection, unique hashing, error handling

4.12 AIF_FilePatcher.lua
------------------------
Standalone PE file patching

Functions:
  GenerateStandaloneScript(injectAddressStr, caveSize, paddingByte, targetFile)
    Returns: Complete standalone patcher script

  ShowGUI()
    Displays: PE Cave Injector GUI form

4.13 AIF_MonoIL2CPP.lua
-----------------------
Mono and IL2CPP integration for Unity games

Functions:
  Initialize()
    Returns: Boolean indicating success

  ResolveMethod(symbolString)
    Returns: Method address or error message

  GetMethodInfoFromAddress(address)
    Returns: Method information table

4.14 AIF_Tests.lua
------------------
Test suite and diagnostics

Functions:
  RunTestSuite()
    Returns: Boolean indicating all tests passed
    Tests: Decoder, ABI allocation, Validator exposure

================================================================================
5. CONFIGURATION GUIDE
================================================================================

5.1 ACCESSING SETTINGS
----------------------
Menu: AIF Pro → Configuration Settings

5.2 CONFIGURATION OPTIONS
--------------------------

AUTHOR (Default: "MBRKiNG")
  Type: String
  Purpose: Author name in generated script headers

GITHUB (Default: "https://github.com/MBRKiNG/CE-Tables")
  Type: String
  Purpose: GitHub repository link in headers

FORUM (Default: "https://opencheattables.com/")
  Type: String
  Purpose: Forum link in headers

DEBUG (Default: true)
  Type: Boolean
  Purpose: Enable/disable debug logging to console

PUSHALL (Default: false)
  Type: Boolean
  Purpose: Push/pop ALL registers instead of only used ones

USE_WILDCARDS (Default: true)
  Type: Boolean
  Purpose: Auto-expand unregistersymbol(*) and dealloc(*) wildcards

USE_COMMENTS (Default: true)
  Type: Boolean
  Purpose: Include inline comments in generated scripts

INCLUDE_HEADER (Default: true)
  Type: Boolean
  Purpose: Include author/date header in generated scripts

INCLUDE_ORIGINAL_CODE (Default: true)
  Type: Boolean
  Purpose: Append original code context at end of script

USE_MODULE_NAMES (Default: true)
  Type: Boolean
  Purpose: Display addresses as Module+Offset instead of hex

AOB_SPACES (Default: true)
  Type: Boolean
  Purpose: Include spaces in generated AOB strings

SMART_AOB (Default: true)
  Type: Boolean
  Purpose: Use smart AOB scanner vs. legacy mode

AOB_MIN_SCAN (Default: 8)
  Type: Integer
  Purpose: Minimum bytes for AOB scanning

AOB_MAX_SCAN (Default: 48)
  Type: Integer
  Purpose: Maximum bytes for AOB scanning

LINES_BEFORE (Default: 50)
  Type: Integer
  Purpose: Context lines before injection point

LINES_AFTER (Default: 50)
  Type: Integer
  Purpose: Context lines after injection point

5.3 SAVING CONFIGURATION
------------------------
Click "Save Settings" button. Configuration is stored in:
  Windows: %APPDATA%/MBRKiNG_CE_Settings.txt

5.4 RECOMMENDED SETTINGS FOR DIFFERENT USE CASES
-------------------------------------------------

GAME MODDING (Stable, Published Mods):
  - PUSHALL: false (Reduced compatibility issues)
  - USE_WILDCARDS: true (Cleaner uninstall)
  - INCLUDE_HEADER: true (Professionalism)
  - SMART_AOB: true (Better stability)
  - LINES_BEFORE/AFTER: 30 (Compact output)

DEBUGGING & DEVELOPMENT:
  - DEBUG: true (Full diagnostics)
  - USE_COMMENTS: true (Understanding)
  - INCLUDE_ORIGINAL_CODE: true (Verification)
  - AOB_MIN_SCAN: 12 (Longer signatures)
  - LINES_BEFORE/AFTER: 100 (Full context)

MINIMAL PAYLOAD (Code Golf):
  - USE_COMMENTS: false (Reduced size)
  - INCLUDE_HEADER: false (No metadata)
  - INCLUDE_ORIGINAL_CODE: false (No context)
  - AOB_SPACES: false (Compact AOB)

================================================================================
6. TEMPLATES REFERENCE
================================================================================

6.1 SELECTING A TEMPLATE
------------------------
1. Right-click address in Disassembler
2. Select from: "[x86/x64]" or "[ARM]" menu options
3. Choose template type
4. Enter symbol name when prompted
5. Script is generated into Auto-Assembler editor

6.2 TEMPLATE 1: INLINE AOB PATCHER
-----------------------------------

WHEN TO USE:
- Replacing a few bytes with simple patch
- No need to call external code
- Minimal memory overhead

EXAMPLE USES:
- NOP out an instruction
- Change conditional jump to unconditional
- Replace with immediate value assignment

GENERATED STRUCTURE:
[ENABLE]
  aobscanmodule(SYMBOL, ModuleName, AA BB CC DD)
  alloc(SYMBOL_Restore, size)
  SYMBOL_Restore: readmem(SYMBOL, size)
  SYMBOL: db NEW_BYTES
  registersymbol(SYMBOL SYMBOL_Restore)
[DISABLE]
  SYMBOL: readmem(SYMBOL_Restore, size)
  unregistersymbol(SYMBOL SYMBOL_Restore)
  dealloc(SYMBOL_Restore)

6.3 TEMPLATE 2: DYNAMIC DETOUR HOOK
------------------------------------

WHEN TO USE:
- Execute custom assembly code at injection point
- Need automatic register preservation
- Complex multi-instruction operations
- Need to call internal functions

EXAMPLE USES:
- Apply mathematical modifications to values
- Call game engine functions
- Complex pointer chasing
- Conditional logic

GENERATED STRUCTURE:
[ENABLE]
  aobscanmodule(SYMBOL, ModuleName, AA BB CC DD)
  alloc(newmem, size)
  alloc(SYMBOL_Restore, size)
  label(code)
  label(return)
  newmem:
  code:
    <save registers>
    <custom code here>
    <restore registers>
    <relocated original instructions>
    jmp return
  SYMBOL: jmp newmem
  <NOPs for remaining space>
  return: <target location>
  registersymbol(SYMBOL SYMBOL_Restore)
[DISABLE]
  ... restoration code ...

6.4 TEMPLATE 3: POINTER REGISTRATION DETOUR
--------------------------------------------

WHEN TO USE:
- Extract dynamic pointers from memory operations
- Store pointer addresses for later use
- Track data structure bases
- Manual debugging and exploration

EXAMPLE USES:
- Extract base pointer from instruction: "mov rax, [rbx+10]"
- Track player object address
- Follow linked lists
- Dump data structures

GENERATED STRUCTURE:
[ENABLE]
  aobscanmodule(SYMBOL, ModuleName, AA BB CC DD)
  alloc(newmem, size)
  alloc(SYMBOL_Restore, size)
  label(basePointer)
  label(code)
  label(return)
  newmem:
  code:
    <save registers>
    <custom code>
    mov [basePointer], <detected_register>
    <restore registers>
    <relocated instructions>
    jmp return
  basePointer: dd 0
  SYMBOL: jmp newmem
  return:
  registersymbol(SYMBOL basePointer)
[DISABLE]
  ... restoration code ...

ACCESSING EXTRACTED POINTER:
In other scripts, reference as: basePointer

6.5 TEMPLATE 4: ADVANCED DETOUR HOOK
-------------------------------------

WHEN TO USE:
- Toggleable features with on/off logic
- Separate code from control flow
- Complex feature management
- Performance-critical sections

EXAMPLE USES:
- Toggleable god mode (separate flag check)
- Multiple conditional patches
- Feature enable/disable without re-assembly

GENERATED STRUCTURE:
[ENABLE]
  aobscanmodule(SYMBOL, ModuleName, AA BB CC DD)
  alloc(newmem, size)
  alloc(data, size)
  alloc(SYMBOL_Restore, size)
  label(bEnableCheat_SYMBOL)
  label(code)
  label(original_code)
  label(return)
  data: db 01
  newmem:
  code:
    cmp byte ptr [bEnableCheat_SYMBOL], 01
    jne original_code
    <custom code here>
    jmp return
  original_code:
    <relocated original instructions>
    jmp return
  SYMBOL: jmp newmem
  return:
  registersymbol(SYMBOL bEnableCheat_SYMBOL)
[DISABLE]
  ... restoration code ...

TOGGLING BEHAVIOR:
To enable: Memory[bEnableCheat_SYMBOL] = 1
To disable: Memory[bEnableCheat_SYMBOL] = 0

================================================================================
7. ADVANCED USAGE
================================================================================

7.1 CUSTOM SCRIPT MODIFICATION
-------------------------------
Generated scripts can be customized:

1. Locate "YOUR CUSTOM CODE HERE" comment
2. Add your assembly between markers
3. Respect register state (saved/restored automatically)
4. Use registered symbols for addressing
5. Test thoroughly before distribution

7.2 COMBINING MULTIPLE TEMPLATES
---------------------------------
Create complex patches by combining templates:

Example: Pointer + Detour
- Use Pointer Registration to extract base
- Use Dynamic Detour to process extracted value
- Reference extracted pointer in second hook

7.3 MANUAL AOB REFINEMENT
--------------------------
If auto-generated AOB has false positives:

1. Open generated script in Auto-Assembler
2. Find "aobscanmodule" line
3. Manually replace wildcards with specific bytes
4. Test uniqueness with memory scanner
5. Use more context (longer AOB) if needed

7.4 WORKING WITH RELATIVE ADDRESSES
------------------------------------

RIP-RELATIVE (x64):
- Automatically detected by validator
- Generates near-allocation warning
- Use "14-byte Far Jump" option for safety
- Auto-relocated in newmem block

RELATIVE JUMPS/CALLS:
- Automatically relocated by Relocator module
- Recalculated based on newmem position
- Comments indicate relocated instructions

ARM RELATIVE:
- Fixed 4-byte instruction size simplifies analysis
- Branch offsets recalculated automatically
- Platform register constraints handled

7.5 DEBUGGING GENERATED SCRIPTS
-------------------------------

ENABLE DEBUG MODE:
1. Menu: AIF Pro → Configuration Settings
2. Check "Enable Debug Logs"
3. Monitor Cheat Engine console for output

DEBUG INFORMATION INCLUDES:
- AOB scanning details
- Register analysis
- Validation warnings
- Module resolution
- Relocation calculations

7.6 WORKING WITH DIFFERENT ARCHITECTURES
------------------------------------------

SELECTING ARCHITECTURE:
- AIF Pro automatically detects target process
- x86/x64 templates appear for Windows processes
- ARM templates available for iOS/Android targets
- Correct architecture guard prevents misuse

CROSS-ARCHITECTURE CONSIDERATIONS:
- Don't mix x86 and ARM templates
- Register names differ (rax vs. x0)
- Calling conventions differ
- Stack layout differs (alignment requirements)

7.7 MONO/IL2CPP GAME SUPPORT
----------------------------

INITIALIZE MONO COLLECTOR:
1. Attach to Unity game process
2. Window → Mono/IL2CPP → Data Collector
3. AIF Pro auto-initializes on template use

RESOLVING MONO METHODS:
Use format: "ClassName:MethodName"
Example: "PlayerManager:TakeDamage"

ACCESSING MONO FROM SCRIPTS:
Symbol format: "[IL2CPP].UnityEngine.Transform:get_position"
Works in "Injection Address" field of any template

7.8 USING PE CAVE INJECTOR
---------------------------

WHEN TO USE:
- Standalone executables without Cheat Engine
- Pre-patching game files
- Distribution-friendly mods

WORKFLOW:
1. Menu: AIF Pro → PE Cave Injector
2. Enter injection address (e.g., "game.exe"+0x12345)
3. Select cave size and padding type
4. Select target executable file
5. Review generated script
6. Customize payload section
7. Execute script to patch file

CAVE SCANNING:
- Automatically finds code caves (00 or CC padding)
- In same section as injection point
- Calculates all RVA/offset values
- Generates standalone Lua script

7.9 LUA TRANSPILER USAGE
------------------------

CONVERTING AA TO LUA:
1. Write Auto-Assembler code in editor
2. Menu: File → "Convert current AA Code to Lua"
3. Script automatically converts
4. Lua version maintains all functionality

WILDCARD PROTECTION:
Automatically expands:
  unregistersymbol(*) → unregistersymbol(SYM1 SYM2 ...)
  dealloc(*) → dealloc(MEM1 MEM2 ...)

SCRIPT ISOLATION:
Each converted script gets unique time-hash:
  aa_script_on_XXXXXXXX
  aa_script_off_XXXXXXXX
Prevents conflicts when multiple scripts run

7.10 BATCH OPERATIONS
---------------------

APPLYING MULTIPLE PATCHES:
1. Generate each script separately
2. Create master cheat table entry
3. Enable/disable child entries for sub-patches
4. Or: Combine scripts into single [ENABLE]/[DISABLE]

ORGANIZATION:
- Group related symbols with naming convention
- Use common prefixes: PATCH_PlayerHP, PATCH_Shield
- Comment complex sections
- Include version numbers in descriptions

================================================================================
8. TROUBLESHOOTING
================================================================================

8.1 COMMON ISSUES
-----------------

ISSUE: "No address selected"
SOLUTION:
  - Right-click address in Disassembler view
  - Ensure DisassemblerView is active
  - Select address before opening template menu

ISSUE: AOB not generating
SOLUTION:
  - Process might not be attached
  - Address might be in invalid memory region
  - Try enabling "Smart AOB" in settings
  - Increase AOB_MAX_SCAN value
  - Check Debug logs for details

ISSUE: Script fails to enable
SOLUTION:
  - AOB might not find unique match
  - Memory might have changed since generation
  - Process architecture might differ from template
  - Try different injection point nearby
  - Manually verify AOB with memory scanner

ISSUE: Injection crashes game
SOLUTION:
  - Validation might have missed issues
  - Hook might overlap critical code
  - Register preservation might be incorrect
  - Try using PUSHALL option for safety
  - Verify stolen instructions relocate correctly

ISSUE: Lua conversion fails
SOLUTION:
  - Script might already be Lua (safeguard active)
  - Check for syntax errors in Auto-Assembler
  - Ensure proper [ENABLE]/[DISABLE] markers
  - Check Debug logs for conversion issues

ISSUE: PE Cave Injector can't find cave
SOLUTION:
  - Section might not have enough free space
  - Try increasing cave size requirement
  - Section might be read-only (check PE header)
  - Try different padding scan type (00 vs CC)
  - Select different section if available

8.2 VALIDATION WARNINGS
-----------------------

WARNING: "Return instruction found inside stolen bytes"
CRITICAL - Script will not work
ACTION: Select different injection point before instructions

WARNING: "Relative addressing detected... Near-allocation required"
INFO - Script needs specific memory positioning
ACTION: Automatically handled; use 14-byte jump option if needed

WARNING: "Hook size exceeds 32 bytes"
WARNING - Might exceed function bounds
ACTION: Verify stolen instructions don't overlap next function

WARNING: "No memory region found"
CRITICAL - Address not in valid memory
ACTION: Verify process is attached; check address validity

8.3 DEBUG LOGGING
-----------------

ENABLING DEBUG OUTPUT:
1. Settings → Enable Debug Logs
2. Open Cheat Engine console (Ctrl+Alt+L)
3. Check output for detailed diagnostics

DEBUG LOG SECTIONS:
[AIF-PRO] - Main framework logs
[AIF-PRO Scanner] - x86/x64 AOB generation
[AIF-PRO ARM Scanner] - ARM/ARM64 AOB generation
[AIF-PRO Decoder] - Instruction analysis
[AIF-Lua] - Transpiler operations

8.4 PERFORMANCE OPTIMIZATION
-----------------------------

SLOW AOB GENERATION:
- Reduce AOB_MAX_SCAN value
- Disable SMART_AOB if very slow
- Try shorter context (LINES_BEFORE/AFTER)
- Check if process is frozen/unresponsive

LARGE SCRIPT OUTPUT:
- Disable INCLUDE_ORIGINAL_CODE
- Disable USE_COMMENTS
- Reduce LINES_BEFORE/AFTER
- Use AOB_SPACES: false

8.5 GETTING HELP
----------------

DEBUGGING CHECKLIST:
1. Enable Debug logs
2. Check Cheat Engine console output
3. Verify process attachment
4. Confirm correct architecture selected
5. Try alternative injection points
6. Test with different settings combinations

REPORTING ISSUES:
Include in bug report:
- Exact error message
- Debug log output
- Game/application name and version
- Windows version
- Cheat Engine version
- Configuration settings used

================================================================================
9. API REFERENCE
================================================================================

9.1 GLOBAL NAMESPACE
--------------------

_G.AIF
Main global table containing all AIF modules and configuration

_G.AIF.Config
Configuration table with all user settings

_G.AIF.DebugLog(msg)
Output debug message to console (if Debug enabled)

_G.reload_aif()
Reload entire AIF Pro framework (destroys all form instances)

9.2 MODULE ACCESS
-----------------

All modules accessible via _G.AIF.ModuleName:

_G.AIF.Utilities          - Helper functions
_G.AIF.Memory             - Memory management
_G.AIF.Decoder            - Instruction decoding
_G.AIF.Relocator          - Instruction relocation
_G.AIF.ABI                - Register management
_G.AIF.Scanner            - x86/x64 AOB scanning
_G.AIF.ScannerARM         - ARM/ARM64 AOB scanning
_G.AIF.Validator          - Injection validation
_G.AIF.Templates          - x86/x64 templates
_G.AIF.TemplatesARM       - ARM/ARM64 templates
_G.AIF.LuaTranspiler      - AA to Lua conversion
_G.AIF.FilePatcher        - PE patching
_G.AIF.Mono               - Mono/IL2CPP support
_G.AIF.Tests              - Test suite

9.3 COMMON USAGE PATTERNS
-------------------------

GENERATING SCRIPT MANUALLY:
local script = _G.AIF.Templates.BuildProDynamicDetour(
  0x140001234,  -- Injection address
  "MyPatch"     -- Symbol name
)
script.addText(script)

VALIDATING INJECTION:
local result = _G.AIF.Validator.ValidateInjectionSite(addr, 5)
if result.isSafe then
  -- Safe to inject
else
  print(table.concat(result.warnings, "\n"))
end

ANALYZING INSTRUCTIONS:
local inst = _G.AIF.Decoder.DecodeInstruction(addr, true, false)
if inst.isRIPRelative then
  -- Near allocation required
end

FINDING SCRATCH REGISTERS:
local analysis = _G.AIF.ABI.AnalyzeHookRegisters(instructions, true, false)
local scratch = _G.AIF.ABI.ChooseScratchRegisters(analysis, true, 2, false)

================================================================================
10. LICENSE & CREDITS
================================================================================

10.1 LICENSE
------------

MIT License

Copyright (c) 2026 MBRKiNG

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

10.2 CREDITS
------------

AUTHOR: MBRKiNG
VERSION: 2.0 Pro
RELEASE DATE: 2026
REPOSITORY: https://github.com/MBRKiNG/CE-Tables
FORUM: https://opencheattables.com/

10.3 THIRD-PARTY TOOLS
----------------------

Cheat Engine
  Developer: Dark Byte
  Website: https://www.cheatengine.org/
  License: GNU General Public License v3.0

Lua Programming Language
  Website: https://www.lua.org/
  License: MIT License

10.4 VERSION HISTORY
--------------------

v2.0 PRO (2026)
  - Complete rewrite with modular architecture
  - Added ARM/ARM64 support
  - Implemented Smart AOB Scanner
  - Added Lua Transpiler with wildcard protection
  - Added PE Cave Injector
  - Mono/IL2CPP integration
  - Advanced Detour Hook template
  - Comprehensive documentation
  - Full API reference

v1.0 (Earlier)
  - Initial release
  - Basic template generation
  - x86/x64 support

10.5 COMPATIBILITY
------------------

CHEAT ENGINE VERSIONS:
  Minimum: 7.0
  Recommended: 7.4+
  Latest: 7.5+

OPERATING SYSTEMS:
  Windows XP SP3+
  Windows Vista+
  Windows 7+
  Windows 8/8.1+
  Windows 10+
  Windows 11+

LUA VERSION:
  Minimum: Lua 5.1
  Optimized for: LuaJIT 2.0+

10.6 CONTACT & SUPPORT
----------------------

GitHub Issues: https://github.com/MBRKiNG/CE-Tables/issues
Forum: https://opencheattables.com/
Documentation: Included (this file)

================================================================================
END OF DOCUMENTATION
================================================================================

Last Updated: 2026
For the latest version and updates, visit:
https://github.com/MBRKiNG/CE-Tables

This documentation is part of the AIF Pro v2.0 Framework.

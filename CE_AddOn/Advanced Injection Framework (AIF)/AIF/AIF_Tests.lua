-- ============================================================================
-- AIF Pro - Module: Test Suite & Diagnostics
-- File: AIF/AIF_Tests.lua
-- ============================================================================

local AIF_Tests = {}

-- Internal assertion helper
local function Assert(condition, message)
    if not condition then
        error("Test Failed: " .. (message or "Unknown Error"))
    end
end

-- Runs all registered unit tests for the AIF Pro framework
function AIF_Tests.RunTestSuite()
    local log = _G.AIF and _G.AIF.DebugLog or print
    log("=========================================")
    log(" AIF Pro - Diagnostic Test Suite Started ")
    log("=========================================")

    local passed = 0
    local failed = 0

    -- Array of test cases to execute
    local tests = {
        AIF_Tests.TestDecoderBasic,
        AIF_Tests.TestABIScratchAllocation,
        AIF_Tests.TestValidatorExposure
    }

    for i, testFunc in ipairs(tests) do
        local status, err = pcall(testFunc)
        if status then
            passed = passed + 1
            log(string.format("[PASS] Test %d", i))
        else
            failed = failed + 1
            log(string.format("[FAIL] Test %d: %s", i, tostring(err)))
        end
    end

    log("=========================================")
    log(string.format(" Results: %d Passed | %d Failed", passed, failed))
    log("=========================================")
    
    return failed == 0
end

-- Test 1: Verify string parsing and operand splitting in the Decoder
function AIF_Tests.TestDecoderBasic()
    local decoder = _G.AIF.Decoder
    Assert(decoder ~= nil, "Decoder module not loaded.")
    
    local ops = decoder.ParseOperands("rax, [rbx+rcx*4+10]")
    Assert(#ops == 2, "Failed to parse correct number of operands.")
    Assert(ops[1] == "rax", "First operand mismatch.")
    Assert(ops[2] == "[rbx+rcx*4+10]", "Second operand mismatch.")
end

-- Test 2: Verify register state analysis and scratch allocation in the ABI module
function AIF_Tests.TestABIScratchAllocation()
    local abi = _G.AIF.ABI
    Assert(abi ~= nil, "ABI module not loaded.")
    
    -- Mock analysis data simulating locked registers
    local mockAnalysis = {
        usedSet = { rax = true, rbx = true, rcx = true }
    }
    
    local scratchRegs = abi.ChooseScratchRegisters(mockAnalysis, true, 2)
    Assert(#scratchRegs == 2, "Failed to allocate 2 scratch registers.")
    Assert(scratchRegs[1] ~= "rax" and scratchRegs[1] ~= "rbx" and scratchRegs[1] ~= "rcx", "Allocated a register currently in use.")
end

-- Test 3: Verify Validator module exposure and function signature
function AIF_Tests.TestValidatorExposure()
    local validator = _G.AIF.Validator
    Assert(validator ~= nil, "Validator module not loaded.")
    Assert(type(validator.ValidateInjectionSite) == "function", "ValidateInjectionSite function is missing.")
end

-- Expose module to the global AIF namespace
_G.AIF = _G.AIF or {}
_G.AIF.Tests = AIF_Tests
return AIF_Tests

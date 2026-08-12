-- ============================================================================
-- AIF Pro - Module: Mono & IL2CPP Integration
-- File: AIF/AIF_MonoIL2CPP.lua
-- ============================================================================

local AIF_Mono = {
    isActive = false
}

-- Initializes the Mono or IL2CPP Data Collector in Cheat Engine
function AIF_Mono.Initialize()
    if AIF_Mono.isActive then return true end

    -- LaunchMonoDataCollector automatically detects Mono and IL2CPP targets in modern CE versions
    if LaunchMonoDataCollector() ~= 0 then
        AIF_Mono.isActive = true
        if _G.AIF and _G.AIF.DebugLog then
            _G.AIF.DebugLog("Mono/IL2CPP Data Collector successfully initialized.")
        end
        return true
    end

    if _G.AIF and _G.AIF.DebugLog then
        _G.AIF.DebugLog("Failed to initialize Mono/IL2CPP Data Collector. Target may not be a Unity engine.")
    end
    
    return false
end

-- Resolves a Mono/IL2CPP method string to a memory address
-- Expected symbolString format: "ClassName:MethodName" or "Namespace.ClassName:MethodName"
function AIF_Mono.ResolveMethod(symbolString)
    if not AIF_Mono.isActive then
        AIF_Mono.Initialize()
    end

    if not AIF_Mono.isActive then
        return nil, "Mono/IL2CPP features are not available or not attached to the process."
    end

    local address = getAddressSafe(symbolString)
    if address and address ~= 0 then
        return address, nil
    end

    return nil, string.format("Could not resolve Mono/IL2CPP symbol: %s", tostring(symbolString))
end

-- Dissects a memory address to retrieve JIT compiled Mono method information
function AIF_Mono.GetMethodInfoFromAddress(address)
    if not AIF_Mono.isActive or not address or address == 0 then 
        return nil 
    end

    -- Utilize CE's internal mono_getJitInfo if available
    if type(mono_getJitInfo) == "function" then
        local methodInfo = mono_getJitInfo(address)
        if methodInfo and methodInfo.method then
            local className = mono_class_getName(methodInfo.class)
            local methodName = mono_method_getName(methodInfo.method)
            return {
                className = className,
                methodName = methodName,
                fullName = string.format("%s:%s", className, methodName)
            }
        end
    end
    
    return nil
end

-- Expose module to the global AIF namespace
_G.AIF = _G.AIF or {}
_G.AIF.Mono = AIF_Mono
return AIF_Mono

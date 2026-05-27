--[[
    NightFall Keyless Loader (TEST ONLY)
    Fetches homelandertest.lua — no key required.

    Share this file OR the one-liner below. Do NOT share improved_script.lua.
]]

local CONFIG = {
    REQUIRED_PLACE_ID = 134225461562780,
    SCRIPT_URL = "https://raw.githubusercontent.com/quarter67/NightFall/main/homelandertest.lua",
}

local LOADER_VERSION = "1.3-keyless"
print("[NightFall] Keyless loader v" .. LOADER_VERSION)

if game.PlaceId ~= CONFIG.REQUIRED_PLACE_ID then
    warn(string.format(
        "[NightFall] Wrong game. Required PlaceId %s, current PlaceId %s.",
        tostring(CONFIG.REQUIRED_PLACE_ID),
        tostring(game.PlaceId)
    ))
    return
end

local HttpService = game:GetService("HttpService")

local DEFAULT_HEADERS = {
    ["Accept"] = "text/plain, application/json, */*",
    ["User-Agent"] = "NightFallKeyless/1.1",
}

local function getRequestFn()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    return nil
end

local REQUEST_FN = getRequestFn()

local function httpGet(url)
    local strategies = {}

    if REQUEST_FN then
        table.insert(strategies, function()
            local res = REQUEST_FN({
                Url = url,
                Method = "GET",
                Headers = DEFAULT_HEADERS,
            })
            if type(res) == "table" and res.Body and res.Body ~= "" then
                return res.Body
            end
            if type(res) == "string" and res ~= "" then
                return res
            end
            return nil
        end)
    end

    table.insert(strategies, function()
        local res = HttpService:RequestAsync({
            Url = url,
            Method = "GET",
            Headers = DEFAULT_HEADERS,
        })
        if res and res.Body and res.Body ~= "" then
            return res.Body
        end
        return nil
    end)

    table.insert(strategies, function()
        return HttpService:GetAsync(url, true, DEFAULT_HEADERS)
    end)

    table.insert(strategies, function()
        return game:HttpGet(url, true)
    end)

    for attempt = 1, 4 do
        for _, strategy in ipairs(strategies) do
            local ok, body = pcall(strategy)
            if ok and body and body ~= "" and not body:find("<!DOCTYPE") then
                return body
            end
        end
        if attempt < 4 then
            task.wait(2)
        end
    end

    return nil
end

local function getCompileFn()
    if type(loadstring) == "function" then return loadstring end
    if type(load) == "function" then return load end
    if getgenv then
        local env = getgenv()
        if env and type(env.loadstring) == "function" then return env.loadstring end
        if env and type(env.load) == "function" then return env.load end
    end
    if getrenv then
        local env = getrenv()
        if env and type(env.loadstring) == "function" then return env.loadstring end
        if env and type(env.load) == "function" then return env.load end
    end
    return nil
end

local function compileAndRun(source, label)
    local compile = getCompileFn()
    if type(compile) ~= "function" then
        warn("[NightFall] Your executor does not support loadstring/load — cannot run the script.")
        return false
    end

    local runScript, compileErr = compile(source, label or "NightFall")
    if type(runScript) ~= "function" then
        warn("[NightFall] Failed to compile script: " .. tostring(compileErr or "unknown compile error"))
        return false
    end

    local ok, runErr = pcall(runScript)
    if not ok then
        warn("[NightFall] Script runtime error: " .. tostring(runErr))
        return false
    end

    return true
end

print("[NightFall] Downloading test script...")
local source = httpGet(CONFIG.SCRIPT_URL)

if not source or source == "" then
    warn("[NightFall] Failed to download homelandertest.lua — check GitHub URL or executor HTTP settings.")
    return
end

if source:sub(1, 1) == "{" then
    warn("[NightFall] Got invalid response from script host.")
    return
end

if not source:find("2026-05-27-FULL-FIX") and not source:find("GUI-PAGES-FIX") and not source:find("REG-FIX-v3") and not source:find("REG-FIX") then
    warn("[NightFall] homelandertest.lua on GitHub looks outdated — push the latest file from your PC.")
end

print("[NightFall] Loaded test build (keyless).")
compileAndRun(source, "NightFallHomelanderTest")

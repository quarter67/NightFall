--[[
    NightFall Keyless Loader (TEST ONLY)
    Loads homelandertest.lua locally when possible, otherwise from URL — no key required.

    Share this file OR the one-liner below. Do NOT share improved_script.lua.
]]

local CONFIG = {
    REQUIRED_PLACE_ID = 134225461562780,
    SCRIPT_URL = "https://raw.githubusercontent.com/quarter67/NightFall/main/homelandertest.lua",
}

local LOCAL_PATHS = {
    "homelandertest.lua",
    "ScriptHub/homelandertest.lua",
    "nightfall/homelandertest.lua",
    "workspace/homelandertest.lua",
}

local LOADER_VERSION = "1.7-keyless"
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
    ["User-Agent"] = "NightFallKeyless/1.5",
}

local function getRequestFn()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    return nil
end

local REQUEST_FN = getRequestFn()

local function fsRead(path)
    local ok, result = pcall(function()
        if isfile and readfile and isfile(path) then
            return readfile(path)
        end
    end)
    return ok and result or nil
end

local function loadLocalScript()
    for _, path in ipairs(LOCAL_PATHS) do
        local content = fsRead(path)
        if content and content ~= "" then
            return content, path
        end
    end
    return nil, nil
end

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

local function getExecutorEnv()
    if typeof(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            return env
        end
    end
    if typeof(shared) == "table" then
        return shared
    end
    return _G
end

local function compileNightFallSource(source, chunkName)
    chunkName = chunkName or "NightFallHomelanderTest"
    local env = getExecutorEnv()

    if type(load) == "function" then
        local fn, err = load(source, chunkName, "t", env)
        if type(fn) == "function" then
            return fn, nil
        end
        if err then
            warn("[NightFall] load() compile failed: " .. tostring(err))
        end
    end

    local compile = loadstring
    if type(compile) ~= "function" and env then
        compile = env.loadstring or env.load
    end
    if type(compile) ~= "function" then
        return nil, "No loadstring/load available"
    end

    local fn, err = compile(source, chunkName)
    if type(fn) ~= "function" then
        return nil, err or "compile returned nil (check script for Luau errors)"
    end

    pcall(function()
        if setfenv then
            setfenv(fn, env)
        end
    end)

    return fn, nil
end

local function compileAndRun(source, label)
    local runScript, compileErr = compileNightFallSource(source, label or "NightFallHomelanderTest")
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

local source, localPath = loadLocalScript()

if source then
    print("[NightFall] Loading local homelandertest.lua")
else
    print("[NightFall] Downloading from URL")
    local url = CONFIG.SCRIPT_URL .. "?t=" .. tostring(os.time())
    source = httpGet(url)

    if not source or source == "" then
        warn("[NightFall] Failed to load homelandertest.lua — place it in your executor workspace or check HTTP settings.")
        return
    end

    if source:sub(1, 1) == "{" then
        warn("[NightFall] Got invalid response from script host.")
        return
    end
end

print("[NightFall] Loaded test build (keyless).")
compileAndRun(source, "NightFallHomelanderTest")

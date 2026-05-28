--[[
    NightFall bootstrap — paste THIS into your executor.
    Fetches the latest loader.lua and bypasses executor HTTP cache.
]]

loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/quarter67/NightFall/main/loader.lua?t="
        .. tostring(os.time())
        .. "&r="
        .. tostring(math.random(100000, 999999))
))()

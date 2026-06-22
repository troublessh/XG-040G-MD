module("luci.controller.cputemp_json", package.seeall)

function index()
    entry({"admin", "status", "cputemp", "json"}, call("action_json"), nil).leaf = true
end

function action_json()
    local temp = "N/A"
    local f = io.open("/sys/class/thermal/thermal_zone0/temp", "r")
    if f then
        local val = f:read("*l")
        f:close()
        if val then
            temp = string.format("%.1f", tonumber(val) / 1000) .. " °C"
        end
    end
    luci.http.prepare_content("application/json")
    luci.http.write('{"temperature":"' .. temp .. '"}')
end

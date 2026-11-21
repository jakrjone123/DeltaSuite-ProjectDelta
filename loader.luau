-- DeltaSuite Loader for Project Delta (PlaceId: 7336302630)
local RAW_URL = "https://raw.githubusercontent.com/jakrjone123/DeltaSuite-ProjectDelta/main/DeltaSuite.luau"

local ok, source = pcall(function()
    return game:HttpGet(RAW_URL)
end)

if not ok or type(source) ~= "string" or #source == 0 then
    warn("[DeltaSuite] No se pudo descargar el script: " .. tostring(source))
    return
end

local fn, err = loadstring(source)
if not fn then
    warn("[DeltaSuite] Error de compilación: " .. tostring(err))
    return
end

fn()

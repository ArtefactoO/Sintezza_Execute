local addon, ns = ...
local api = _G.Sintezza_PerfAPI
if type(api) ~= "table" or api.version ~= 1 then return end
local module = api:RegisterModule(addon, "execute", { title = "Execute indicators", titleRu = "Индикаторы добивания" })
if not module then return end
local call = api:RegisterPoint(module, "ability", { title = "Find learned ability", titleRu = "Поиск способности", memory = true })
local counter = api:RegisterPoint(module, "refresh", { kind = "counter", title = "Nameplate refreshes", titleRu = "Обновления неймплейтов" })
local bridge = {}
ns.PerfBridge = bridge
function bridge.Count(key)
    if key == "refresh" and counter then api:Count(counter) end
end
local owner = ns
if call and owner and type(owner.FindExecute) == "function" then
    local original = owner.FindExecute
    owner.FindExecute = function(...)
        if not api:IsActive(call) then return original(...) end
        if issecretvalue then
            for i = 1, select("#", ...) do
                if issecretvalue(select(i, ...)) then return original(...) end
            end
        end
        return api:Call(call, original, ...)
    end
end

local addon, ns = ...
local L = ns.L
local launcher

function ns.SetMinimapShown(show)
    local settings = ns.db.minimap
    settings.hide = not show
    if launcher then launcher:Refresh(settings) end
end

function ns.InitializeMinimap()
    if launcher then return end
    launcher = Sintezza_Theme:CreateMinimapButton(addon, ns.Media .. "Icon", ns.db.minimap,
        function(_, button)
            if button == "LeftButton" then ns.OpenSettings() end
        end,
        function(tooltip)
            local accent = ns.Theme.accent
            tooltip:AddLine(L.TITLE, accent[1], accent[2], accent[3])
            tooltip:AddLine(L.MINIMAP_OPEN, 1, 1, 1)
        end)
end

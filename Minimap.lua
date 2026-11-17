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
        { window = ns.GetSettingsWindow, open = ns.OpenSettings },
        function(tooltip)
            local accent = ns.Theme.accent
            tooltip:AddLine(L.TITLE, accent[1], accent[2], accent[3])
            Sintezza_Theme:AddMinimapToggleHint(tooltip)
        end)
end

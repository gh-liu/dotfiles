-- theme: nord
-- rex do client.theme.import path='/Applications/Ghostty.app/Contents/Resources/ghostty/themes/Nord' --json
-- rex do client.theme.import path='/Applications/Ghostty.app/Contents/Resources/ghostty/themes/Nord Light' --json

local directions = { h = "left", j = "down", k = "up", l = "right" }
for key, direction in pairs(directions) do
        rex.bind("cmd+shift+" .. key, "pane.focus", { direction = direction })
end
rex.bind("cmd+shift+m", "pane.zoom")

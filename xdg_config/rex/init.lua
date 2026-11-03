-- theme: nord
-- rex do client.theme.import path='/Applications/Ghostty.app/Contents/Resources/ghostty/themes/Nord' --json
-- rex do client.theme.import path='/Applications/Ghostty.app/Contents/Resources/ghostty/themes/Nord Light' --json

local directions = { h = "left", j = "down", k = "up", l = "right" }
for key, direction in pairs(directions) do
        rex.bind("cmd+shift+" .. key, "pane.focus", { direction = direction })
end
-- rex.unbind("shift+cmd+enter")
rex.bind("cmd+shift+z", "pane.zoom")
-- rex.unbind("alt+cmd+enter")
rex.bind("cmd+shift+f", "pane.float")
-- rex.unbind("alt+cmd+m")
rex.bind("cmd+shift+m", "pane.minimize_floating")

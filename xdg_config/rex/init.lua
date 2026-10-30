local directions = { h = "left", j = "down", k = "up", l = "right" }
for key, direction in pairs(directions) do
        rex.bind("cmd+ctrl+" .. key, "pane.focus", { direction = direction })
end

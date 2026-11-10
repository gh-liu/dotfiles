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

local minimized_zoom = {}
rex.bind("cmd+shift+m", function (ctx)
        local function layer_has_block(layer, block_id)
                for _, block in ipairs(layer.blocks) do
                        if block.block_id == block_id then
                                return true
                        end
                end
                return false
        end

        local view = assert(rex.session.view({ session_id = ctx.session_id }))
        local window
        for _, candidate in ipairs(view.windows or {}) do
                if candidate.window_id == view.active_window_id then
                        window = candidate
                        break
                end
        end
        if not window then
                return true
        end

        local target
        for _, layer in ipairs(window.layers) do
                if layer.kind == "floating" and layer.state == "minimized" then
                        target = layer
                elseif layer.kind == "floating" and layer_has_block(layer, window.focused_block_id) then
                        target = layer
                        break
                end
        end
        if not target then
                return true
        end

        local minimizing = target.state ~= "minimized"
        assert(rex.session.set_layer_state({
                        session_id = ctx.session_id,
                        layer_id = target.layer_id,
                        state = minimizing and "minimized" or "normal",
                        focus = not minimizing
                }))
        if minimizing then
                minimized_zoom[target.layer_id] = window.zoomed_block_id
                return true
        end

        local zoom = minimized_zoom[target.layer_id]
        if zoom and layer_has_block(target, zoom) then
                assert(rex.session.zoom_block({
                                session_id = ctx.session_id,
                                block_id = zoom,
                                zoom = true
                        }))
        end
        minimized_zoom[target.layer_id] = nil
        return true
end)

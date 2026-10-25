-- Click the language label (OSC 8), or use gx, to open the rendered diagram.
-- Rendering happens on mermaid.ink only when the mermlink is opened.
local api = vim.api
local namespace = api.nvim_create_namespace("liu/mermaid")

local function refresh(buf)
	api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	local block
	for i, line in ipairs(api.nvim_buf_get_lines(buf, 0, -1, false)) do
		local indent, fence, info = line:match("^( *)(`+)(.*)$")
		if not fence then
			indent, fence, info = line:match("^( *)(~+)(.*)$")
		end

		if block then
			if fence and fence:sub(1, 1) == block.marker and #fence >= block.length and info:match("^%s*$") then
				if block.col and #block.lines > 0 then
					local payload =
						vim.json.encode({ code = table.concat(block.lines, "\n"), mermaid = { theme = "default" } })
					local encoded = vim.base64.encode(payload):gsub("+", "-"):gsub("/", "_"):gsub("=+$", "")
					api.nvim_buf_set_extmark(buf, namespace, block.row, block.col, {
						end_col = block.col + #"mermaid",
						hl_group = "Underlined",
						url = "https://mermaid.ink/svg/base64:" .. encoded,
					})
				end
				block = nil
			else
				-- Markdown strips up to the opening fence's indentation.
				local spaces = #(line:match("^ *") or "")
				block.lines[#block.lines + 1] = line:sub(math.min(spaces, block.indent) + 1)
			end
		elseif fence and #fence >= 3 and (fence:sub(1, 1) ~= "`" or not info:find("`", 1, true)) then
			local whitespace, language = info:match("^(%s*)(%S+)")
			block = {
				row = i - 1,
				col = language == "mermaid" and (#indent + #fence + #whitespace) or nil,
				marker = fence:sub(1, 1),
				length = #fence,
				indent = #indent,
				lines = {},
			}
		end
	end
end

api.nvim_set_decoration_provider(namespace, {
	on_win = function(_, _, buf)
		local tick = api.nvim_buf_get_changedtick(buf)
		if vim.bo[buf].filetype ~= "markdown" then
			if vim.b[buf].mermaid_changedtick then
				api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
				vim.b[buf].mermaid_changedtick = nil
			end
		elseif vim.b[buf].mermaid_changedtick ~= tick then
			refresh(buf)
			vim.b[buf].mermaid_changedtick = tick
		end
		-- Persistent marks also let the built-in gx discover URLs between redraws.
		return false
	end,
})

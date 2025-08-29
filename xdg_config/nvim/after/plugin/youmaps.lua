vim.keymap.set("n", "yuq", function()
	local get = function()
		for _, win in pairs(vim.fn.getwininfo()) do
			if win["quickfix"] == 1 then
				return true
			end
		end
		return false
	end

	if get() then
		vim.cmd("cclose")
	else
		vim.cmd("copen")
	end
end)
vim.keymap.set("n", "yoz", function()
	local option_name = "foldmethod"
	local option_values = { "manual", "indent", "expr", "marker", "syntax", "diff" }

	local option_value = vim.api.nvim_get_option_value(option_name, { scope = "local" })
	local idx = 0
	for i, value in ipairs(option_values) do
		if option_value == value then
			idx = i
		end
	end
	local idx1 = idx % #option_values + 1
	vim.api.nvim_set_option_value(option_name, option_values[idx1], { scope = "local" })
	vim.cmd([[setlocal ]] .. option_name .. "?")
end)

local toggle = function(key, option)
	vim.keymap.set("n", "yo" .. key, string.format("<cmd>setlocal %s! | setlocal %s? <cr>", option, option))
end
toggle("s", "spell")
toggle("w", "wrap")
toggle("d", "diff")
toggle("h", "hlsearch")
toggle("l", "list")
toggle("p", "previewwindow")
toggle("i", "ignorecase")
toggle("f", "winfixbuf")

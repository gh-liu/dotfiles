vim.cmd([[
iabbr ni@ @need-install:
]])

vim.api.nvim_create_autocmd("BufReadPost", {
	pattern = { "*/plugins/*.lua" },
	callback = function(args)
		vim.api.nvim_buf_create_user_command(
			args.buf,
			"Plugins",
			[[vimgrep /\t\{2}"[a-zA-Z0-9-._]\+\/[a-zA-Z0-9-._]\+",/g % | copen]],
			{}
		)
		vim.wo[0][0].foldmethod = "expr"
		vim.wo[0][0].foldtext = "getline(v:foldstart+1)"
		vim.wo[0][0].foldexpr = "getline(v:lnum+1)=~'^\t\\{2}\"[a-zA-Z0-9-]\\+/[a-zA-Z0-9-]\\+'?'>1':'='"
	end,
})

vim.api.nvim_create_user_command("LazyPlugins", function()
	local obj = vim.system({ "rg", '^\t{2}".*/.*",', vim.fn.stdpath("config") .. "/lua/liu/plugins", "--json" }):wait()
	local lines = vim.split(obj.stdout, "\n", { trimempty = true })
	local result = vim.iter(lines)
		:map(function(line)
			return vim.json.decode(line)
		end)
		:filter(function(res)
			return res["type"] and res["type"] == "match"
		end)
		:map(function(res)
			local data = res.data
			return {
				path = data.path.text,
				line = data.line_number,
				text = vim.trim(data.lines.text),
			}
		end)
		:totable()

	table.sort(result, function(a, b)
		return a.text < b.text
	end)

	vim.ui.select(result, {
		format_item = function(item)
			return item.text
		end,
	}, function(choice)
		if not choice then
			return
		end
		local match = vim.iter(result):find(function(item)
			return item.text == choice.text
		end)
		if match then
			vim.cmd("e" .. " +" .. match.line .. " " .. match.path)
		end
	end)
end, {})

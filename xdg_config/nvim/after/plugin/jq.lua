vim.api.nvim_create_user_command("FromJsonText", function(_)
	vim.cmd("setlocal ft=json")
	vim.cmd("%!jq -c '. | fromjson'")
end, { nargs = 0 })

vim.api.nvim_create_user_command("ToJsonText", function(_)
	vim.cmd("setlocal ft=json")
	vim.cmd("%!jq -c '. | tojson'")
end, { nargs = 0 })

vim.cmd([[command! -bang FormatJsonText setlocal ft=json | execute '%!jq ' . (<bang>0 ? '-c ' : '') . '.']])

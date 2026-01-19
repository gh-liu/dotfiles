vim.api.nvim_create_user_command("FromJsonText", function(_)
	vim.cmd("setlocal ft=json")
	vim.cmd("%!jq -c '. | fromjson'")
end, { nargs = 0 })

vim.api.nvim_create_user_command("ToJsonText", function(_)
	vim.cmd("setlocal ft=json")
	vim.cmd("%!jq -c '. | tojson'")
end, { nargs = 0 })

vim.api.nvim_create_user_command("CompactJsonText", function(_)
	vim.cmd("setlocal ft=json")
	vim.cmd("%!jq -c .")
end, { nargs = 0 })

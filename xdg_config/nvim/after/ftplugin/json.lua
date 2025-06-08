local create_command = vim.api.nvim_buf_create_user_command

create_command(0, "ToJsonText", function(_)
	vim.cmd("%!jq -c '. | tojson'")
end, { nargs = 0 })

create_command(0, "FromJsonText", function(_)
	vim.cmd("%!jq -c '. | fromjson'")
end, { nargs = 0 })

create_command(0, "CompactJsonText", function(_)
	vim.cmd("%!jq -c .")
end, { nargs = 0 })

-- @need-install: go install github.com/fatih/gomodifytags@latest
-- https://github.com/fatih/gomodifytags
vim.api.nvim_create_user_command("Gomodifytags", function(args)
	if not (vim.bo.ft == "go") then
		return
	end
	local cmd = { "gomodifytags", "-file", vim.api.nvim_buf_get_name(0), "-format", "json" }
	table.insert(cmd, "-line")
	table.insert(cmd, args.line1 .. "," .. args.line2)

	for _, arg in ipairs(args.fargs) do
		table.insert(cmd, arg)
	end
	--TODO: -modified
	-- https://github.com/fatih/gomodifytags?tab=readme-ov-file#unsaved-files
	local is_add_tag = string.match(args.args, "%-add%-tags")
	if is_add_tag and args.bang then
		-- Override current tags when adding tags
		table.insert(cmd, "-override")
	end
	-- vim.print(cmd)

	local handle = function(result)
		local start_line = result.start or 1
		local end_line = result["end"]
		local lines = result.lines
		vim.schedule(function()
			vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
		end)
	end
	vim.system(cmd, { text = true }, function(out)
		if out.code == 1 and out.stderr then
			print(out.stderr)
		end
		if out.code == 0 and out.stdout then
			local result = vim.json.decode(out.stdout)
			-- TODO: handle error
			-- https://github.com/fatih/vim-go/blob/e6788d124a564b049f3d80bef984e8bd5281286d/autoload/go/tags.vim#L98
			if result then
				handle(result)
			end
		end
	end)
end, {
	range = true,
	bang = true,
	nargs = "*",
	complete = function(argLead, cmdLine, cursorPos)
		local ops
		local is_add_tag = string.match(cmdLine, "%-add%-tags=")
		-- local is_remove_tag = string.match(cmdLine, "%-remove%-tags")

		if is_add_tag then
			ops = {
				"-add-options=",
				"-transform=",
				"-template=",
			}
		end

		local add_del_tags_comp = function(op, tags)
			local pat = string.gsub(op, "-", "%%-") .. "(.*),"
			local match_tags_str = string.match(argLead, pat)
			if match_tags_str then
				local match_tags = vim.split(match_tags_str, ",")
				return vim.iter(tags)
					:filter(function(tag)
						return not vim.tbl_contains(match_tags, tag)
					end)
					:map(function(tag)
						return argLead .. tag
					end)
					:totable()
			end

			return vim.iter(tags)
				:map(function(tag)
					return op .. tag
				end)
				:totable()
		end

		local add_tags_op_str = "-add-tags="
		if vim.startswith(argLead, add_tags_op_str) then
			local tags = vim.fn.get(vim.b, "gomodifytags", vim.fn.get(vim.g, "gomodifytags", { "json", "xml" }))
			return add_del_tags_comp(add_tags_op_str, tags)
		end

		local start_line = vim.fn.line(".")
		local end_line = vim.fn.line(".")
		local cur_mode = vim.fn.mode()
		if cur_mode == "v" or cur_mode == "V" or cur_mode == "\22" then -- <C-V>
			start_line = vim.fn.line("'<")
			end_line = vim.fn.line("'>")
		end

		local get_added_tags_from_code = function()
			local tags_map = {}
			for linenr = start_line, end_line do
				local line = vim.fn.getline(linenr)
				local gotagstr = string.match(line, "`(.*)`")
				if not gotagstr then
					return {}
				end
				local gotags = vim.split(gotagstr, "%s", {})
				for _, gotag in ipairs(gotags) do
					local tag = vim.split(gotag, ":")[1]
					tags_map[tag] = true
				end
			end
			return vim.tbl_keys(tags_map)
		end

		local get_added_tags_from_cmdline = function()
			local tags_str = string.match(cmdLine, "%s%-add%-tags=(.*)%s")
			if not tags_str then
				return {}
			end
			return vim.split(tags_str, ",")
		end

		local remove_tags_op_str = "-remove-tags="
		if vim.startswith(argLead, remove_tags_op_str) then
			local added_tags = get_added_tags_from_code()
			return add_del_tags_comp(remove_tags_op_str, added_tags)
		end

		local get_added_options_from_code = function()
			local options_map = {}
			for linenr = start_line, end_line do
				local line = vim.fn.getline(linenr)
				local gotagstr = string.match(line, "`(.*)`")
				if not gotagstr then
					return {}
				end
				local gotags = vim.split(gotagstr, "%s", {})
				for _, gotag in ipairs(gotags) do
					local res = vim.split(gotag, ":")
					local tag = res[1]
					local options_str = string.match(res[2], [["(.*)"]])
					local options = vim.split(options_str, ",")
					vim.iter(options):skip(1):each(function(option)
						options_map[tag .. "=" .. option] = true
					end)
				end
			end
			return vim.tbl_keys(options_map)
		end

		local remove_options_op_str = "-remove-options="
		if vim.startswith(argLead, remove_options_op_str) then
			local options = get_added_options_from_code()
			return vim.iter(options)
				:map(function(option)
					return remove_options_op_str .. option
				end)
				:totable()
		end

		local add_options_op_str = "-add-options="
		if vim.startswith(argLead, add_options_op_str) then
			-- NOTE: two sources: 1.cmdline, 2. added tags
			local tags = get_added_tags_from_code()
			vim.iter(get_added_tags_from_cmdline()):each(function(tag)
				table.insert(tags, tag)
			end)
			local options =
				vim.fn.get(vim.b, "gomodifytags_options", vim.fn.get(vim.g, "gomodifytags_options", { "omitempty" }))
			local match_options_str = string.match(argLead, "%-add%-options=(.*),")
			if match_options_str then
				local match_tags = {}
				for _, option_str in ipairs(vim.split(match_options_str, ",")) do
					local tag = vim.split(option_str, "=")[1]
					table.insert(match_tags, tag)
				end
				return vim.iter(tags)
					:filter(function(tag)
						return not vim.tbl_contains(match_tags, tag)
					end)
					:map(function(tag)
						return tag .. "="
					end)
					:map(function(item)
						return vim.iter(options)
							:map(function(option)
								return argLead .. item .. option
							end)
							:totable()
					end)
					:flatten()
					:totable()
			end

			return vim.iter(tags)
				:map(function(tag)
					return add_options_op_str .. tag .. "="
				end)
				:map(function(item)
					return vim.iter(options)
						:map(function(option)
							return item .. option
						end)
						:totable()
				end)
				:flatten()
				:totable()
		end

		if vim.startswith(argLead, "-transform=") then
			local transforms = { "snakecase", "camelcase", "lispcase", "pascalcase", "titlecase", "keep" }
			return vim.iter(transforms)
				:map(function(transform)
					return "-transform=" .. transform
				end)
				:totable()
		end

		if not ops then
			ops = {
				add_tags_op_str,
				remove_tags_op_str,
				"-clear-tags",
				add_options_op_str,
				remove_options_op_str,
				"-clear-options",
			}
		end

		return ops
	end,
})

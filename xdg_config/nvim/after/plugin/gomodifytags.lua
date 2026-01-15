-- @need-install: go install github.com/fatih/gomodifytags@latest
-- https://github.com/fatih/gomodifytags
vim.api.nvim_create_user_command("Gomodifytags", function(args)
	if not (vim.bo.ft == "go") then
		return
	end

	local config = vim.g.gomodifytags_config or {}
	local default_tags = config.default_tags or vim.g.gomodifytags or { "json", "xml" }
	local default_options = config.default_options or vim.g.gomodifytags_options or { "omitempty" }
	local skip_unexported = config.skip_unexported ~= nil and config.skip_unexported or true
	local transform = config.transform or "snakecase"

	local has_target_option = false
	for _, arg in ipairs(args.fargs) do
		if arg == "-struct" or arg == "-offset" or arg == "-all" or arg:find("^-struct=") or arg:find("^-offset=") then
			has_target_option = true
			break
		end
	end

	local cmd = { "gomodifytags", "-file", vim.api.nvim_buf_get_name(0), "-format", "json" }

	if not has_target_option then
		table.insert(cmd, "-line")
		table.insert(cmd, args.line1 .. "," .. args.line2)
	end

	if skip_unexported then
		table.insert(cmd, "--skip-unexported")
	end

	if transform ~= "snakecase" then
		table.insert(cmd, "-transform")
		table.insert(cmd, transform)
	end

	for _, arg in ipairs(args.fargs) do
		table.insert(cmd, arg)
	end

	local is_add_tag = string.match(args.args, "%-add%-tags")
	if is_add_tag and args.bang then
		table.insert(cmd, "-override")
	end

	local handle = function(result)
		local start_line = result.start or 1
		local end_line = result["end"]
		local lines = result.lines
		vim.schedule(function()
			vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
		end)
	end

	local execute_command = function(stdin_content)
		local final_cmd = vim.deepcopy(cmd)
		if stdin_content then
			table.insert(final_cmd, "-modified")
		end

		vim.system(final_cmd, { text = true, stdin = stdin_content }, function(out)
			if out.code == 1 and out.stderr then
				vim.schedule(function()
					vim.notify("gomodifytags: " .. out.stderr, vim.log.levels.ERROR)
				end)
				return
			end
			if out.code == 0 and out.stdout then
				local success, result = pcall(vim.json.decode, out.stdout)
				if not success then
					vim.schedule(function()
						vim.notify("gomodifytags: JSON parse error - " .. tostring(result), vim.log.levels.ERROR)
					end)
					return
				end
				if result and result.lines then
					handle(result)
				end
			end
		end)
	end

	if vim.bo.modified then
		local filename = vim.api.nvim_buf_get_name(0)
		local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
		local size = #content
		local archive = string.format("%s\n%d\n%s\n", filename, size, content)
		execute_command(archive)
	else
		execute_command(nil)
	end
end, {
	range = true,
	bang = true,
	nargs = "*",
	complete = function(argLead, cmdLine, cursorPos)
		local config = vim.g.gomodifytags_config or {}
		local default_tags = config.default_tags or vim.g.gomodifytags or { "json", "xml" }
		local default_options = config.default_options or vim.g.gomodifytags_options or { "omitempty" }

		local ops
		local is_add_tag = string.match(cmdLine, "%-add%-tags=")

		if is_add_tag then
			ops = {
				"-add-options=",
				"-transform=",
				"-template=",
				"-skip-unexported",
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
			return add_del_tags_comp(add_tags_op_str, default_tags)
		end

		local static_tags_with_values = {
			"validate:required",
			"validate:omitempty",
			"validate:gt=0",
			"validate:gte=0",
			"validate:lt=0",
			"validate:lte=0",
			"validate:min=",
			"validate:max=",
			"validate:len=",
			"validate:email",
			"validate:uuid",
			"validate:url",
			"scope:read-only",
			"scope:write",
			"scope:admin",
		}

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
					local options_str = res[2] and string.match(res[2], [["(.*)"]])
					if options_str then
						local options = vim.split(options_str, ",")
						vim.iter(options):skip(1):each(function(option)
							options_map[tag .. "=" .. option] = true
						end)
					end
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
			local tags = get_added_tags_from_code()
			vim.iter(get_added_tags_from_cmdline()):each(function(tag)
				table.insert(tags, tag)
			end)
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
						return vim.iter(default_options)
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
					return vim.iter(default_options)
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

		if vim.startswith(argLead, "-template=") then
			local templates = {
				"-template={field}",
				"-template=field_name={field}",
				"-template={field}={value}",
				"-template={name}:{type}",
			}
			return vim.iter(templates)
				:map(function(tmpl)
					return argLead:sub(1, -#"-template=") .. tmpl:sub(11)
				end)
				:totable()
		end

		if vim.startswith(argLead, "-skip-unexported") then
			return { "-skip-unexported" }
		end

		if not ops then
			ops = {
				add_tags_op_str,
				remove_tags_op_str,
				"-clear-tags",
				add_options_op_str,
				remove_options_op_str,
				"-clear-options",
				"-transform=",
				"-template=",
				"-skip-unexported",
			}
		end

		return ops
	end,
})

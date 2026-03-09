-- @need-install: go install github.com/fatih/gomodifytags@latest
-- https://github.com/fatih/gomodifytags
--
-- :Gomodifytags [ARGS]  - Modify struct tags for Go struct fields
--   Range support: line selection, tag selection
--   Bang (!): Override existing tags when adding
--
-- Examples:
--   :'<,'>Gomodifytags -add-tags=json
--   :'<,'>Gomodifytags -add-tags=json,xml -transform=camelcase
--   :'<,'>Gomodifytags -add-options=json=omitempty
--   :'<,'>Gomodifytags -add-options=all=omitempty
--   :'<,'>Gomodifytags -remove-tags=json

local function get_config()
	local function get_var(name, default)
		-- Buffer-local takes priority
		if vim.b[name] ~= nil then return vim.b[name] end
		-- Then global
		if vim.g[name] ~= nil then return vim.g[name] end
		-- Then default
		return default
	end

	return {
		default_tags = get_var("gomodifytags_tags", { "json", "xml" }),
		default_options = get_var("gomodifytags_options", { "omitempty" }),
		skip_unexported = get_var("gomodifytags_skip_unexported", true),
		transform = get_var("gomodifytags_transform", "snakecase"),
		sort = get_var("gomodifytags_sort", false),
	}
end

local function extract_tags_from_lines(start_line, end_line)
	local tags_set = {}
	for linenr = start_line, end_line do
		local line = vim.fn.getline(linenr)
		local gotagstr = string.match(line, "`(.*)`")
		if gotagstr then
			for gotag in gotagstr:gmatch("%S+") do
				-- Skip tags with "-" value (ignored fields)
				if not string.match(gotag, ':"-"$') then
					local tag = gotag:match("^([^:]+)")
					if tag then
						tags_set[tag] = true
					end
				end
			end
		end
	end
	return vim.tbl_keys(tags_set)
end

local function split_csv(value)
	return vim.split(value, ",", { plain = true, trimempty = true })
end

local function transform_embedded_name(field_expr, transform)
	local name = field_expr:gsub("^%s+", ""):gsub("%s+$", "")
	name = name:gsub("^%*", "")
	name = name:gsub("%b[]", "")
	name = name:match("([%w_]+)$")
	if not name then
		return nil
	end
	if transform == "keep" then
		return name
	end

	local words = {}
	local current = ""
	local source = name
	for i = 1, #source do
		local ch = source:sub(i, i)
		local next_ch = i < #source and source:sub(i + 1, i + 1) or nil
		if ch:match("[%l%d]") then
			current = current .. ch
		elseif ch:match("%u") then
			if current ~= "" and (current:match("%l$") or (next_ch and next_ch:match("%l"))) then
				table.insert(words, current:lower())
				current = ch:lower()
			else
				current = current .. ch:lower()
			end
		else
			if current ~= "" then
				table.insert(words, current:lower())
				current = ""
			end
		end
	end
	if current ~= "" then
		table.insert(words, current:lower())
	end
	if transform == "snakecase" then
		return table.concat(words, "_")
	end
	if transform == "lispcase" then
		return table.concat(words, "-")
	end
	if transform == "camelcase" then
		local out = { words[1] or "" }
		for i = 2, #words do
			table.insert(out, words[i]:sub(1, 1):upper() .. words[i]:sub(2))
		end
		return table.concat(out)
	end
	if transform == "pascalcase" then
		local out = {}
		for _, word in ipairs(words) do
			table.insert(out, word:sub(1, 1):upper() .. word:sub(2))
		end
		return table.concat(out)
	end
	if transform == "titlecase" then
		local out = {}
		for _, word in ipairs(words) do
			table.insert(out, word:sub(1, 1):upper() .. word:sub(2))
		end
		return table.concat(out, " ")
	end
	return table.concat(words, "_")
end

local function parse_embedded_add_tags(fargs, cfg, bang)
	local transform = cfg.transform
	local sort = cfg.sort
	local add_tags = nil

	for _, arg in ipairs(fargs) do
		local value = arg:match("^%-transform=(.+)$")
		if value then
			transform = value
		end

		value = arg:match("^%-add%-tags=(.+)$")
		if value then
			add_tags = split_csv(value)
		end

		if arg == "-sort" then
			sort = true
		end
	end

	if not add_tags or #add_tags == 0 then
		return nil
	end

	return {
		transform = transform,
		sort = sort,
		override = bang,
		add_tags = add_tags,
	}
end

local function apply_embedded_add_tags(line, actions)
	local indent, body = line:match("^(%s*)(.*)$")
	if not body or body == "" or body:match("^//") then
		return line
	end

	local prefix, tag_string, suffix = body:match("^(.-)%s*`([^`]*)`(.*)$")
	if not prefix then
		prefix, suffix = body:match("^(.-)(%s*//.*)$")
		prefix = prefix or body
		suffix = suffix or ""
		tag_string = nil
	else
		suffix = suffix or ""
	end

	local field_expr = prefix:gsub("^%s+", ""):gsub("%s+$", "")
	if field_expr == "" or field_expr == "}" or field_expr:find("%s") then
		return line
	end

	local transformed_name = transform_embedded_name(field_expr, actions.transform)
	if not transformed_name then
		return line
	end

	local order, tags = {}, {}
	for item in (tag_string or ""):gmatch("%S+") do
		local key, value = item:match('^([^:]+):"(.*)"$')
		if key then
			table.insert(order, key)
			tags[key] = value
		end
	end
	local seen = {}
	for _, key in ipairs(order) do
		seen[key] = true
	end

	for _, key in ipairs(actions.add_tags) do
		if tags[key] == nil then
			table.insert(order, key)
			seen[key] = true
		end
		if actions.override or tags[key] == nil then
			tags[key] = transformed_name
		end
	end

	local keys = {}
	for _, key in ipairs(order) do
		if tags[key] ~= nil then
			table.insert(keys, key)
		end
	end
	if actions.sort then
		table.sort(keys)
	end
	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, string.format('%s:"%s"', key, tags[key]))
	end
	local formatted = table.concat(parts, " ")
	if formatted == "" then
		return indent .. field_expr .. suffix
	end
	return indent .. field_expr .. " `" .. formatted .. "`" .. suffix
end

local function apply_embedded_field_fallback(lines, fargs, cfg, bang)
	local actions = parse_embedded_add_tags(fargs, cfg, bang)
	if not actions then
		return lines
	end
	return vim.iter(lines):map(function(line)
		return apply_embedded_add_tags(line, actions)
	end):totable()
end

vim.api.nvim_create_user_command("Gomodifytags", function(args)
	if vim.bo.ft ~= "go" then
		vim.notify("Gomodifytags: requires Go filetype", vim.log.levels.WARN)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local changedtick = vim.b[bufnr].changedtick
	local cfg = get_config()
	local cmd = { "gomodifytags", "-file", vim.api.nvim_buf_get_name(bufnr), "-format", "json" }

	-- Check if user provided target selector (-struct, -offset, -field, -all)
	local has_target = false
	local target_prefixes = { "-struct", "-offset", "-field", "-all" }
	for _, arg in ipairs(args.fargs) do
		for _, prefix in ipairs(target_prefixes) do
			if vim.startswith(arg, prefix) then
				has_target = true
				break
			end
		end
		if has_target then
			break
		end
	end

	-- Add line range if no target selector provided
	if not has_target then
		table.insert(cmd, "-line")
		table.insert(cmd, args.line1 .. "," .. args.line2)
	end

	-- Add default options
	if cfg.skip_unexported then
		table.insert(cmd, "-skip-unexported")
	end
	if cfg.transform ~= "snakecase" then
		table.insert(cmd, "-transform")
		table.insert(cmd, cfg.transform)
	end
	if cfg.sort then
		table.insert(cmd, "-sort")
	end

	-- Process user arguments, handle special all= syntax
	for _, arg in ipairs(args.fargs) do
		if arg:match("^%-add%-options=all=") then
			local option = arg:sub(18)
			local tags_list = extract_tags_from_lines(args.line1, args.line2)
			if #tags_list > 0 then
				local parts = {}
				for _, tag in ipairs(tags_list) do
					table.insert(parts, tag .. "=" .. option)
				end
				table.insert(cmd, "-add-options=" .. table.concat(parts, ","))
			end
		elseif arg:match("^%-remove%-options=all=") then
			local option = arg:sub(21)
			local tags_list = extract_tags_from_lines(args.line1, args.line2)
			if #tags_list > 0 then
				local parts = {}
				for _, tag in ipairs(tags_list) do
					table.insert(parts, tag .. "=" .. option)
				end
				table.insert(cmd, "-remove-options=" .. table.concat(parts, ","))
			end
		elseif arg:match("^%-remove%-tags=all$") then
			local tags_list = extract_tags_from_lines(args.line1, args.line2)
			if #tags_list > 0 then
				table.insert(cmd, "-remove-tags=" .. table.concat(tags_list, ","))
			end
		else
			table.insert(cmd, arg)
		end
	end

	-- Handle -override flag for -add-tags
	if args.bang and args.args:match("%-add%-tags") then
		table.insert(cmd, "-override")
	end

	-- Prepare stdin if buffer is modified
	local stdin_data = nil
	if vim.bo[bufnr].modified then
		local filename = vim.api.nvim_buf_get_name(bufnr)
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local content = table.concat(lines, "\n")
		if #lines > 0 and lines[#lines] ~= "" then
			content = content .. "\n"
		end
		stdin_data = filename .. "\n" .. #content .. "\n" .. content
		table.insert(cmd, "-modified")
	end

	-- Execute command
	vim.system(cmd, { text = true, stdin = stdin_data }, function(out)
		if out.code ~= 0 then
			vim.schedule(function()
				local msg = out.stderr or "unknown error"
				vim.notify("Gomodifytags: " .. msg, vim.log.levels.ERROR)
			end)
			return
		end

		if out.stdout == "" then
			return
		end

		local ok, result = pcall(vim.json.decode, out.stdout)
		if not ok then
			vim.schedule(function()
				vim.notify("Gomodifytags: JSON parse error", vim.log.levels.ERROR)
			end)
			return
		end

		if result and result.lines then
			vim.schedule(function()
				if not vim.api.nvim_buf_is_valid(bufnr) then
					return
				end
				if vim.b[bufnr].changedtick ~= changedtick then
					vim.notify("Gomodifytags: buffer changed during command, skip applying result", vim.log.levels.WARN)
					return
				end
				local start = result.start or 1
				local finish = result["end"] or start
				local lines = apply_embedded_field_fallback(result.lines, args.fargs, cfg, args.bang)
				vim.api.nvim_buf_set_lines(bufnr, start - 1, finish, false, lines)
			end)
		end
	end)
end, {
	range = true,
	bang = true,
	nargs = "*",
	complete = function(argLead, cmdLine, _)
		local cfg = get_config()
		local start_line = vim.fn.line(".")
		local end_line = vim.fn.line(".")
		local mode = vim.fn.mode()
		if mode == "v" or mode == "V" or mode == "\22" then
			start_line = vim.fn.line("'<")
			end_line = vim.fn.line("'>")
		end

		-- Extract existing tags and options from code
		local function get_tags_in_selection()
			local tags = {}
			for linenr = start_line, end_line do
				local line = vim.fn.getline(linenr)
				local gotagstr = line:match("`([^`]*)`")
				if gotagstr then
					for gotag in gotagstr:gmatch("%S+") do
						if not string.match(gotag, ':"-"$') then
							local tag = gotag:match("^([^:]+)")
							if tag and not vim.tbl_contains(tags, tag) then
								table.insert(tags, tag)
							end
						end
					end
				end
			end
			return tags
		end

		local function get_options_in_selection()
			local opts = {}
			for linenr = start_line, end_line do
				local line = vim.fn.getline(linenr)
				local gotagstr = line:match("`([^`]*)`")
				if gotagstr then
					for gotag in gotagstr:gmatch("%S+") do
						local tag, optstr = gotag:match("^([^:]+):([^:]+)$")
						if optstr then
							local clean_opts = optstr:match('^"(.*)"$') or optstr
							for opt in clean_opts:gmatch("[^,]+") do
								local key = tag .. "=" .. opt
								if not vim.tbl_contains(opts, key) then
									table.insert(opts, key)
								end
							end
						end
					end
				end
			end
			return opts
		end

		-- Completion for -add-tags=
			if argLead:match("^%-add%-tags=") then
				local tags_in_code = get_tags_in_selection()
				local existing_str = argLead:match("%-add%-tags=(.*)$")
				local existing_tags = vim.split(existing_str:gsub(",$", ""), ",", { plain = true, trimempty = true })

				local candidates = {}
			for _, tag in ipairs(cfg.default_tags) do
				if not vim.tbl_contains(existing_tags, tag) then
					table.insert(candidates, "-add-tags=" .. tag)
				end
			end
			return candidates
		end

		-- Completion for -remove-tags=
		if argLead:match("^%-remove%-tags=") then
			local tags = get_tags_in_selection()
			if argLead == "-remove-tags=" or argLead == "-remove-tags=" then
				local result = {}
				for _, tag in ipairs(tags) do
					table.insert(result, "-remove-tags=" .. tag)
				end
				table.insert(result, "-remove-tags=all")
				return result
			end
		end

		-- Completion for -add-options=
		if argLead:match("^%-add%-options=") then
			if argLead:match("^%-add%-options=all=") then
				local candidates = {}
				for _, opt in ipairs(cfg.default_options) do
					table.insert(candidates, "-add-options=all=" .. opt)
				end
				return candidates
			end

			local tags = get_tags_in_selection()
			local result = {}
			for _, tag in ipairs(tags) do
				for _, opt in ipairs(cfg.default_options) do
					table.insert(result, "-add-options=" .. tag .. "=" .. opt)
				end
			end
			table.insert(result, "-add-options=all=")
			return result
		end

		-- Completion for -remove-options=
		if argLead:match("^%-remove%-options=") then
			if argLead:match("^%-remove%-options=all=") then
				local candidates = {}
				for _, opt in ipairs(cfg.default_options) do
					table.insert(candidates, "-remove-options=all=" .. opt)
				end
				return candidates
			end

			local opts = get_options_in_selection()
			local result = {}
			for _, opt in ipairs(opts) do
				table.insert(result, "-remove-options=" .. opt)
			end
			table.insert(result, "-remove-options=all=")
			return result
		end

		-- Completion for -transform=
		if argLead:match("^%-transform=") then
			local transforms = {
				"snakecase", "camelcase", "lispcase", "pascalcase", "titlecase", "keep"
			}
			local candidates = {}
			for _, t in ipairs(transforms) do
				table.insert(candidates, "-transform=" .. t)
			end
			return candidates
		end

		-- Completion for -template=
		if argLead:match("^%-template=") then
			local templates = {
				"{field}", "field_name={field}", "{field}={value}", "{name}:{type}"
			}
			local candidates = {}
			for _, tmpl in ipairs(templates) do
				table.insert(candidates, "-template=" .. tmpl)
			end
			return candidates
		end

		-- Default completion
		return {
			"-add-tags=",
			"-remove-tags=",
			"-clear-tags",
			"-add-options=",
			"-remove-options=",
			"-clear-options",
			"-transform=",
			"-template=",
			"-skip-unexported",
			"-sort",
			"-all",
		}
	end,
})

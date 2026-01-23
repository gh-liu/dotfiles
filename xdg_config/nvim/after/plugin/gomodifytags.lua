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

vim.api.nvim_create_user_command("Gomodifytags", function(args)
	if vim.bo.ft ~= "go" then
		vim.notify("Gomodifytags: requires Go filetype", vim.log.levels.WARN)
		return
	end

	local cfg = get_config()
	local cmd = { "gomodifytags", "-file", vim.api.nvim_buf_get_name(0), "-format", "json" }

	-- Check if user provided target selector (-struct, -offset, -field, -all)
	local has_target = false
	for _, arg in ipairs(args.fargs) do
		if arg:match("^%-%(struct|offset|field|all%)") then
			has_target = true
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
	if vim.bo.modified then
		local filename = vim.api.nvim_buf_get_name(0)
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
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
				local start = result.start or 1
				local finish = result["end"] or start
				vim.api.nvim_buf_set_lines(0, start - 1, finish, false, result.lines)
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
			local existing_tags = existing_str:gsub(",$", ""):split(",")

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

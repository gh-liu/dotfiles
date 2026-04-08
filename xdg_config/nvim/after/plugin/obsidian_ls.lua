local CMD = {
	new = "obsidian.new",
	new_from_template = "obsidian.newFromTemplate",
	list_templates = "obsidian.listTemplates",
}

local TemplatePrefix = ":"
local HELPER = {
	frontmatter = {},
	rename = {},
}

function HELPER.rename.normalize_string_list(value)
	if type(value) == "string" then
		value = value ~= "" and { value } or {}
	elseif type(value) ~= "table" then
		value = {}
	end

	local out = {}
	for _, item in ipairs(value) do
		if type(item) == "string" then
			local trimmed = vim.trim(item)
			if trimmed ~= "" then
				out[#out + 1] = trimmed
			end
		end
	end
	return out
end

function HELPER.frontmatter.merge_tags(existing, parsed)
	local seen = {}
	return vim.iter(vim.list_extend(HELPER.rename.normalize_string_list(existing), HELPER.rename.normalize_string_list(parsed)))
		:filter(function(tag)
			if seen[tag] then
				return false
			end
			seen[tag] = true
			return true
		end)
		:totable()
end

function HELPER.frontmatter.read(bufnr)
	if vim.fn.executable("yq") ~= 1 then
		return nil
	end

	local result = vim.system({
		"yq",
		"--front-matter=extract",
		"-o=json",
		"-",
	}, {
		text = true,
		stdin = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n"),
		timeout = 5000,
	}):wait()

	if result.code ~= 0 then
		return nil
	end

	local payload = vim.trim(result.stdout or "")
	if payload == "" or payload == "null" then
		return nil
	end

	local ok, meta = pcall(vim.json.decode, payload)
	if not ok or type(meta) ~= "table" then
		return nil
	end

	return { meta = meta }
end

function HELPER.frontmatter.parse_title_pattern(title)
	local tag_part, doc_title = title:match("^(.-)%+%+(.+)$")
	if not doc_title then
		return nil, nil
	end
	doc_title = vim.trim(doc_title)
	if doc_title == "" then
		return nil, nil
	end
	local tags = vim.iter(vim.split(tag_part or "", "_", { plain = true, trimempty = true }))
		:map(vim.trim)
		:filter(function(tag)
			return tag ~= ""
		end)
		:totable()
	return tags, doc_title
end

function HELPER.frontmatter.build_context(meta)
	local title_value = type(meta.title) == "string" and meta.title or ""
	local parsed_tags, doc_title = HELPER.frontmatter.parse_title_pattern(title_value)
	return {
		parsed_tags = parsed_tags or {},
		doc_title = doc_title,
	}
end

function HELPER.frontmatter.default_transform(meta, ctx)
	if not ctx.doc_title then
		return nil
	end

	local next_meta = vim.deepcopy(meta)
	next_meta.title = ctx.doc_title
	next_meta.tags = HELPER.frontmatter.merge_tags(meta.tags, ctx.parsed_tags)
	return next_meta
end

function HELPER.frontmatter.build_yq_operations(current_meta, next_meta)
	local ops = {}
	local env = {}
	local current = current_meta
	local next_copy = next_meta

	local keys = {}
	for key in pairs(current) do
		keys[key] = true
	end
	for key in pairs(next_copy) do
		keys[key] = true
	end

	for key in vim.spairs(keys) do
		local next_value = next_copy[key]
		if next_value == nil then
			if current[key] ~= nil then
				ops[#ops + 1] = string.format("del(.%s)", key)
			end
		elseif not vim.deep_equal(current[key], next_value) then
			local env_name = "FRONTMATTER_" .. key:upper():gsub("[^A-Z0-9_]", "_")
			env[env_name] = vim.json.encode(next_value)
			ops[#ops + 1] = string.format(".%s = (strenv(%s) | from_json)", key, env_name)
		end
	end

	return ops, env
end

function HELPER.frontmatter.run_yq_update(lines, current_meta, next_meta)
	if vim.fn.executable("yq") ~= 1 then
		return nil, "yq not found"
	end

	local ops, env = HELPER.frontmatter.build_yq_operations(current_meta, next_meta)
	if #ops == 0 then
		return lines, nil
	end

	local result = vim.system({
		"yq",
		"--front-matter=process",
		table.concat(ops, " | "),
		"-",
	}, {
		text = true,
		stdin = table.concat(lines, "\n"),
		env = env,
		timeout = 5000,
	}):wait()

	if result.code ~= 0 then
		local err = vim.trim(result.stderr or "")
		return nil, err ~= "" and err or ("yq failed with exit code " .. result.code)
	end

	local output = result.stdout or ""
	local new_lines = vim.split(output, "\n", { plain = true })
	if new_lines[#new_lines] == "" then
		table.remove(new_lines, #new_lines)
	end
	return new_lines, nil
end

function HELPER.frontmatter.sync(bufnr, transform)
	local doc = HELPER.frontmatter.read(bufnr)
	if not doc then
		return false
	end

	local fn = transform or HELPER.frontmatter.default_transform
	local next_meta = fn(doc.meta, HELPER.frontmatter.build_context(doc.meta))
	if not next_meta or vim.deep_equal(doc.meta, next_meta) then
		return false
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local new_lines, err = HELPER.frontmatter.run_yq_update(lines, doc.meta, next_meta)
	if not new_lines then
		vim.notify("frontmatter sync failed: " .. err, vim.log.levels.WARN)
		return false
	end
	if vim.deep_equal(new_lines, lines) then
		return false
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
	return true
end

function HELPER.rename.build_basename(meta)
	local tags = HELPER.rename.normalize_string_list(meta.tags)
	if #tags == 0 then
		return nil, "请填写 frontmatter 中的 tags"
	end

	local aliases = HELPER.rename.normalize_string_list(meta.aliases)
	local doc_name = aliases[1] or ""
	if doc_name == "" then
		return nil, "请填写 frontmatter 中的 aliases"
	end
	doc_name = doc_name:gsub("%s+", "-")

	local name = table.concat(tags, "_") .. "++" .. doc_name
	return (name:gsub('[\\/%*%?%:"<>|]', "_"))
end

function HELPER.rename.build_target_path(path, meta)
	local basename, err = HELPER.rename.build_basename(meta)
	if not basename then
		return nil, err
	end

	local dir = vim.fn.fnamemodify(path, ":h")
	local ext = vim.fn.fnamemodify(path, ":e")
	return dir .. "/" .. basename .. (ext ~= "" and ("." .. ext) or "")
end

function HELPER.rename.from_frontmatter(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" or vim.bo[bufnr].buftype ~= "" then
		return nil, "not a file buffer"
	end

	local doc = HELPER.frontmatter.read(bufnr)
	if not doc then
		return nil, "no frontmatter found"
	end

	local new_path, err = HELPER.rename.build_target_path(path, doc.meta)
	if not new_path then
		return nil, err
	end

	if path == new_path then
		return new_path, "filename unchanged"
	end

	if vim.fn.filereadable(new_path) == 1 then
		return nil, "target already exists: " .. new_path
	end

	vim.cmd("saveas! " .. vim.fn.fnameescape(new_path))
	if vim.fn.delete(path) ~= 0 then
		return nil, "rename failed"
	end

	return new_path, nil
end

local function get_obsidian_client(bufnr, client_id)
	if client_id then
		local client = vim.lsp.get_client_by_id(client_id)
		if client and client.name == "obsidian_ls" then
			return client
		end
	end

	local clients = vim.lsp.get_clients({ name = "obsidian_ls", bufnr = bufnr })
	if #clients == 0 then
		clients = vim.lsp.get_clients({ name = "obsidian_ls" })
	end
	if #clients == 0 then
		return nil
	end
	return clients[1]
end

local function obsidian_exec(bufnr, cmd, args, callback)
	local client = get_obsidian_client(bufnr)
	if not client then
		vim.notify("obsidian-lsp not attached", vim.log.levels.WARN)
		return
	end
	local command = { command = cmd, arguments = args or {} }
	client:exec_cmd(command, nil, function(err, result)
		if err then
			vim.notify("obsidian: " .. (err.message or tostring(err)), vim.log.levels.ERROR)
			return
		end
		if callback then
			callback(result)
		end
	end)
end

local function list_templates(bufnr)
	local command = { command = CMD.list_templates, arguments = {} }
	local result = vim.lsp.buf_request_sync(bufnr, "workspace/executeCommand", command, 1000)
	if not result then
		return {}
	end
	for _, item in pairs(result) do
		if item.result and item.result.templates then
			return item.result.templates
		end
	end
	return {}
end

local function complete_template_names(bufnr, arg)
	local query = arg:sub(#TemplatePrefix + 1):lower()
	return vim.iter(list_templates(bufnr))
		:filter(function(template)
			return query == "" or template:lower():find(query, 1, true) ~= nil
		end)
		:map(function(template)
			return TemplatePrefix .. template
		end)
		:totable()
end

local edit_uri = function(uri)
	local fname = vim.uri_to_fname(uri)
	vim.cmd("edit " .. vim.fn.fnameescape(fname))
end

vim.api.nvim_create_user_command("ObsidianNew", function(opts)
	local bufnr = vim.api.nvim_get_current_buf()
	local args = opts.fargs
	if #args > 0 and args[1]:match("^" .. TemplatePrefix) then
		local template_name = args[1]:sub(#TemplatePrefix + 1)
		local path = table.concat(args, " ", 2)
		obsidian_exec(bufnr, CMD.new_from_template, { template_name, path }, function(result)
			if result and result.uri then
				edit_uri(result.uri)
			end
		end)
		return
	end

	obsidian_exec(bufnr, CMD.new, { opts.args }, function(result)
		if result and result.uri then
			edit_uri(result.uri)
		end
	end)
end, {
	nargs = "*",
	desc = "Create new note (default template) or from template",
	complete = function(_, cmdline, _)
		local bufnr = vim.api.nvim_get_current_buf()
		local arg = vim.fn.matchstr(cmdline, [[\v\S+$]])
		if not arg or arg == "" or arg == "ObsidianNew" then
			return complete_template_names(bufnr, TemplatePrefix)
		end
		if arg:match("^" .. TemplatePrefix) then
			return complete_template_names(bufnr, arg)
		end
		return {}
	end,
})

vim.api.nvim_create_user_command("ObsidianRename", function()
	local bufnr = vim.api.nvim_get_current_buf()
	local new_path, err = HELPER.rename.from_frontmatter(bufnr)
	if not new_path then
		local level = err and err:match("^target already exists:") and vim.log.levels.ERROR or vim.log.levels.WARN
		vim.notify("ObsidianRename: " .. (err or "rename failed"), level)
		return
	end

	if err == "filename unchanged" then
		vim.notify("ObsidianRename: filename unchanged", vim.log.levels.INFO)
		return
	end

	local new_basename = vim.fn.fnamemodify(new_path, ":t:r")
	vim.notify("Renamed to " .. new_basename, vim.log.levels.INFO)
end, {
	desc = "Rename file from frontmatter: tag1_tag2++aliases[1]",
})

-- auto formatting
local format_group = vim.api.nvim_create_augroup("liu/obsidian_ls/format", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local buf = ev.buf
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if not client or client.name ~= "obsidian_ls" then
			return
		end

		vim.keymap.set("n", "grN", "<Cmd>ObsidianRename<CR>", {
			buffer = buf,
			desc = "Rename note from frontmatter",
		})

		local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
		if filename == "README.md" then
			return
		end

		vim.api.nvim_create_autocmd("BufWritePre", {
			group = format_group,
			buffer = buf,
			callback = function()
				if not vim.api.nvim_buf_is_valid(buf) then
					return
				end
				pcall(vim.cmd, "undojoin")
				local frontmatter_changed = HELPER.frontmatter.sync(buf)
				if frontmatter_changed then
					pcall(vim.cmd, "undojoin")
				end
				vim.lsp.buf.format({ bufnr = buf, id = client.id })
			end,
		})
	end,
})

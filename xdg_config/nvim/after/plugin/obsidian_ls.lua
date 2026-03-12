local CMD = {
	new = "obsidian.new",
	new_from_template = "obsidian.newFromTemplate",
	list_templates = "obsidian.listTemplates",
}

local TemplatePrefix = ":"

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

local edit_uri = function(uri)
	local fname = vim.uri_to_fname(uri)
	vim.cmd("edit " .. vim.fn.fnameescape(fname))
end

vim.api.nvim_create_user_command("ObsidianNew", function(opts)
	local bufnr = vim.api.nvim_get_current_buf()
	local args = opts.fargs
	if #args > 0 and args[1]:match("^" .. TemplatePrefix) then
		local template_name = args[1]:sub(#TemplatePrefix + 1)
		local path = args[2] or ""
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
		local arg = vim.fn.matchstr(cmdline, [[\v\S+$]])
		if not arg or arg == "" or arg == "ObsidianNew" then
			return vim.iter(list_templates(vim.api.nvim_get_current_buf()))
				:map(function(t)
					return TemplatePrefix .. t
				end)
				:totable()
		end
		if arg:match("^" .. TemplatePrefix) then
			return vim.iter(list_templates(vim.api.nvim_get_current_buf()))
				:map(function(t)
					return TemplatePrefix .. t
				end)
				:totable()
		end
		return {}
	end,
})

local FRONTMATTER = {}

function FRONTMATTER.unquote(s)
	local q = s:sub(1, 1)
	if (q == '"' or q == "'") and s:sub(-1) == q then
		return s:sub(2, -2)
	end
	return s
end

function FRONTMATTER.get_frontmatter(bufnr)
	local tree = vim.treesitter.get_parser(bufnr, "markdown"):parse()[1]
	if not tree then
		return nil, nil, nil
	end

	local query = vim.treesitter.query.parse("markdown", [[ (minus_metadata) @fm ]])
	for _, match, _ in query:iter_matches(tree:root(), bufnr, 0, -1) do
		for id, nodes in pairs(match) do
			if query.captures[id] == "fm" and nodes[1] then
				local node = nodes[1]
				local sr, _, er, _ = node:range()
				local fm_text = vim.treesitter.get_node_text(node, bufnr) or ""
				local yaml_text = fm_text:gsub("^%-%-%-%s*\n", ""):gsub("\n%-%-%-%s*$", "")
				return sr + 1, er, yaml_text
			end
		end
	end
	return nil, nil, nil
end

function FRONTMATTER.parse_title_pattern(title)
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

function FRONTMATTER.collect_scalar_values(node, source, out)
	if node:type() == "string_scalar" then
		local text = vim.trim(FRONTMATTER.unquote(vim.treesitter.get_node_text(node, source) or ""))
		if text ~= "" then
			out[#out + 1] = text
		end
		return
	end

	local count = node:named_child_count()
	for i = 0, count - 1 do
		FRONTMATTER.collect_scalar_values(node:named_child(i), source, out)
	end
end

---@param yaml_text string
---@return table meta Parsed field table; key = field name, value = string or string[]
function FRONTMATTER.parse_frontmatter_yaml(yaml_text)
	local tree = vim.treesitter.get_string_parser(yaml_text, "yaml"):parse()[1]
	if not tree then
		return {}
	end

	local query = vim.treesitter.query.parse(
		"yaml",
		[[ (block_mapping_pair key: (flow_node (plain_scalar (string_scalar) @key)) value: (_) @value) @pair ]]
	)

	local out = {}
	local key_order = {}
	for _, match, _ in query:iter_matches(tree:root(), yaml_text, 0, -1) do
		local key_node, value_node
		for id, nodes in pairs(match) do
			local cap = query.captures[id]
			if cap == "key" then
				key_node = nodes[1]
			elseif cap == "value" then
				value_node = nodes[1]
			end
		end
		if key_node and value_node then
			local key_text = vim.trim(FRONTMATTER.unquote(vim.treesitter.get_node_text(key_node, yaml_text) or ""))
			if key_text == "" then
				goto continue
			end
			local values = {}
			FRONTMATTER.collect_scalar_values(value_node, yaml_text, values)
			local vt = value_node:type()
			local is_array = vt == "flow_sequence" or vt == "block_sequence"
			if is_array or #values > 1 then
				out[key_text] = values
			else
				out[key_text] = values[1]
					or vim.trim(FRONTMATTER.unquote(vim.treesitter.get_node_text(value_node, yaml_text) or ""))
			end
			key_order[#key_order + 1] = key_text
			::continue::
		end
	end
	out._key_order = key_order
	return out
end

---@param meta table Field table; value = string or string[]
---@return string yaml_text
function FRONTMATTER.dump_frontmatter_yaml(meta)
	local key_order = meta._key_order or {}
	meta._key_order = nil
	local seen = {}
	for _, k in ipairs(key_order) do
		seen[k] = true
	end
	for k in pairs(meta) do
		if not seen[k] and k ~= "_key_order" then
			key_order[#key_order + 1] = k
		end
	end

	local lines = {}
	local function yaml_scalar(v)
		local ty = type(v)
		if ty == "string" then
			return vim.json.encode(v)
		end
		if ty == "number" or ty == "boolean" then
			return tostring(v)
		end
		return vim.json.encode(tostring(v))
	end
	for _, key in ipairs(key_order) do
		local v = meta[key]
		if v == nil then
			goto next
		end
		if type(v) == "table" and not vim.tbl_islist(v) then
			goto next
		end
		local line
		if type(v) == "table" then
			line = key .. ": [" .. table.concat(vim.tbl_map(yaml_scalar, v), ", ") .. "]"
		else
			line = key .. ": " .. yaml_scalar(v)
		end
		lines[#lines + 1] = line
		::next::
	end
	meta._key_order = nil
	return table.concat(lines, "\n")
end

---@param bufnr number
---@param meta table
---@return table ctx { bufnr, meta, parsed_tags, doc_title }
function FRONTMATTER.build_context(bufnr, meta)
	local title_value = type(meta.title) == "string" and meta.title or ""
	local parsed_tags, doc_title = FRONTMATTER.parse_title_pattern(title_value)
	return {
		bufnr = bufnr,
		meta = meta,
		parsed_tags = parsed_tags or {},
		doc_title = doc_title,
	}
end

local function merge_tags(existing, parsed)
	local seen = {}
	return vim.iter(vim.list_extend(existing or {}, parsed or {}))
		:map(function(tag)
			return vim.trim(tag)
		end)
		:filter(function(tag)
			if tag == "" or seen[tag] then
				return false
			end
			seen[tag] = true
			return true
		end)
		:totable()
end

---@param meta table Current frontmatter parse result
---@param ctx table Return value of build_context
---@return table|nil New meta, or nil to skip modification
function FRONTMATTER.default_transform(meta, ctx)
	if not ctx.doc_title then
		return nil
	end
	local next_meta = vim.deepcopy(meta)
	next_meta.title = ctx.doc_title
	next_meta.tags = merge_tags(meta.tags, ctx.parsed_tags)
	return next_meta
end

---@param bufnr number
---@param transform? fun(meta: table, ctx: table): table|nil Receives meta and ctx, returns new meta or nil to skip modification
---@return boolean changed
function FRONTMATTER.sync(bufnr, transform)
	local fm_start, fm_end, yaml_text = FRONTMATTER.get_frontmatter(bufnr)
	if not fm_start or not fm_end or yaml_text == "" then
		return false
	end

	local meta = FRONTMATTER.parse_frontmatter_yaml(yaml_text)
	local ctx = FRONTMATTER.build_context(bufnr, meta)
	local fn = transform or FRONTMATTER.default_transform
	local next_meta = fn(meta, ctx)
	if not next_meta then
		return false
	end

	local new_yaml_text = FRONTMATTER.dump_frontmatter_yaml(next_meta)
	if new_yaml_text == yaml_text then
		return false
	end

	local new_lines = vim.split("---\n" .. new_yaml_text .. "\n---", "\n", { plain = true })
	vim.api.nvim_buf_set_lines(bufnr, fm_start - 1, fm_end, false, new_lines)
	return true
end

-- auto formatting
local format_group = vim.api.nvim_create_augroup("liu/obsidian_ls/format", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local buf = ev.buf
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if not client or client.name ~= "obsidian_ls" then
			return
		end

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
				local frontmatter_changed = FRONTMATTER.sync(buf)
				if frontmatter_changed then
					pcall(vim.cmd, "undojoin")
				end
				vim.lsp.buf.format({ bufnr = buf, id = client.id })
			end,
		})
	end,
})

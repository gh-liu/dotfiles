local CMD = {
	new = "obsidian.new",
	new_from_template = "obsidian.newFromTemplate",
	list_templates = "obsidian.listTemplates",
}

local TemplatePrefix = ":"

local function obsidian_exec(cmd, args, callback)
	local clients = vim.lsp.get_clients({ name = "obsidian_ls" })
	if #clients == 0 then
		vim.notify("obsidian-lsp not attached", vim.log.levels.WARN)
		return
	end
	local client = clients[1]
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

local function list_templates()
	local command = { command = CMD.list_templates, arguments = {} }
	local result = vim.lsp.buf_request_sync(0, "workspace/executeCommand", command)
	if not result or not result[1] or not result[1].result or not result[1].result.templates then
		return {}
	end
	return result[1].result.templates
end

local edit_uri = function(uri)
	local fname = vim.uri_to_fname(uri)
	vim.cmd("edit " .. vim.fn.fnameescape(fname))
end

vim.api.nvim_create_user_command("ObsidianNew", function(opts)
	local args = opts.fargs
	if #args > 0 and args[1]:match("^" .. TemplatePrefix) then
		local template_name = args[1]:sub(3)
		local path = args[2] or ""
		obsidian_exec(CMD.new_from_template, { template_name, path }, function(result)
			if result and result.uri then
				edit_uri(result.uri)
			end
		end)
		return
	end

	obsidian_exec(CMD.new, { opts.args }, function(result)
		if result and result.uri then
			edit_uri(result.uri)
		end
	end)
end, {
	nargs = "*",
	desc = "Create new note (default template) or from template",
	complete = function(_, cmdline, _)
		local arg = vim.fn.matchstr(cmdline, [[\v\S+$]])
		if not arg or arg == "" then
			return {}
		end
		if arg:match("^" .. TemplatePrefix) then
			return vim.iter(list_templates())
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

function FRONTMATTER.yaml_pair_lines(node)
	local sr, _, er, ec = node:range()
	return sr + 1, (ec == 0) and er or (er + 1)
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
	for _, match, _ in query:iter_matches(tree:root(), yaml_text, 0, -1) do
		local key_node, value_node, pair_node
		for id, nodes in pairs(match) do
			local cap = query.captures[id]
			if cap == "key" then
				key_node = nodes[1]
			elseif cap == "value" then
				value_node = nodes[1]
			elseif cap == "pair" then
				pair_node = nodes[1]
			end
		end
		if key_node and value_node and pair_node then
			local key_text = vim.trim(FRONTMATTER.unquote(vim.treesitter.get_node_text(key_node, yaml_text) or ""))
			local line_start, line_end = FRONTMATTER.yaml_pair_lines(pair_node)
			if key_text == "title" then
				local title_values = {}
				FRONTMATTER.collect_scalar_values(value_node, yaml_text, title_values)
				out.title = {
					line_start = line_start,
					value = title_values[1]
						or vim.trim(FRONTMATTER.unquote(vim.treesitter.get_node_text(value_node, yaml_text) or "")),
				}
			elseif key_text == "tags" then
				local tags = {}
				FRONTMATTER.collect_scalar_values(value_node, yaml_text, tags)
				out.tags = {
					line_start = line_start,
					line_end = line_end,
					values = tags,
				}
			end
		end
	end

	return out
end

function FRONTMATTER.sync(bufnr)
	local fm_start, fm_end, yaml_text = FRONTMATTER.get_frontmatter(bufnr)
	if not fm_start or not fm_end then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, fm_start - 1, fm_end, false)
	if #lines < 3 then
		return
	end

	if yaml_text == "" then
		return
	end

	local meta = FRONTMATTER.parse_frontmatter_yaml(yaml_text)
	local title_meta = meta.title
	local title_line_idx = title_meta and (title_meta.line_start + 1) or nil
	local title_value = title_meta and title_meta.value or nil

	if not title_line_idx or not title_value or title_value == "" then
		return
	end

	local parsed_tags, doc_title = FRONTMATTER.parse_title_pattern(title_value)
	if not parsed_tags then
		return
	end

	local tags_meta = meta.tags
	local tags_start_idx = tags_meta and (tags_meta.line_start + 1) or nil
	local tags_end_idx = tags_meta and (tags_meta.line_end + 1) or nil
	local existing_tags = tags_meta and tags_meta.values or {}

	local seen = {}
	local merged_tags = vim.iter(vim.list_extend(existing_tags, parsed_tags))
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
	local new_tags_line = "tags: [" .. table.concat(merged_tags, ", ") .. "]"
	local changed = false

	if lines[title_line_idx] ~= ("title: " .. doc_title) then
		lines[title_line_idx] = "title: " .. doc_title
		changed = true
	end

	if tags_start_idx then
		if tags_start_idx == tags_end_idx then
			if lines[tags_start_idx] ~= new_tags_line then
				lines[tags_start_idx] = new_tags_line
				changed = true
			end
		else
			for _ = tags_start_idx, tags_end_idx do
				table.remove(lines, tags_start_idx)
			end
			table.insert(lines, tags_start_idx, new_tags_line)
			changed = true
		end
	else
		table.insert(lines, title_line_idx + 1, new_tags_line)
		changed = true
	end

	if changed then
		vim.api.nvim_buf_set_lines(bufnr, fm_start - 1, fm_end, false, lines)
	end
end

-- auto formatting
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local buf = ev.buf

		local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
		if filename == "README.md" then
			return
		end

		local clients = vim.lsp.get_clients({ name = "obsidian_ls" })
		---@type vim.lsp.Client|nil
		local client = #clients > 0 and clients[1] or nil
		if client then
			vim.api.nvim_create_autocmd("BufWritePre", {
				buffer = buf,
				callback = function()
					FRONTMATTER.sync(buf)
					vim.lsp.buf.format({ bufnr = buf, id = client.id })
				end,
			})
		end
	end,
})

local M = {}
local is_list = vim.islist or vim.tbl_islist

local markdown_frontmatter_query = vim.treesitter.query.parse("markdown", [[ (minus_metadata) @fm ]])
local yaml_pairs_query = vim.treesitter.query.parse(
	"yaml",
	[[ (block_mapping_pair key: (flow_node (plain_scalar (string_scalar) @key)) value: (_) @value) @pair ]]
)

local function unquote(s)
	local q = s:sub(1, 1)
	if (q == '"' or q == "'") and s:sub(-1) == q then
		return s:sub(2, -2)
	end
	return s
end

local function trim_node_text(node, source)
	return vim.trim(unquote(vim.treesitter.get_node_text(node, source) or ""))
end

local function collect_scalar_values(node, source, out)
	local ntype = node:type()
	if ntype == "string_scalar" or ntype == "double_quote_scalar" or ntype == "single_quote_scalar" then
		local text = trim_node_text(node, source)
		if text ~= "" then
			out[#out + 1] = text
		end
		return
	end

	for i = 0, node:named_child_count() - 1 do
		collect_scalar_values(node:named_child(i), source, out)
	end
end

local function unwrap_value_node(node)
	local current = node
	while current and current:named_child_count() == 1 do
		local child = current:named_child(0)
		local ctype = child:type()
		if ctype == "block_sequence" or ctype == "flow_sequence" or ctype == "flow_node" or ctype == "block_node" then
			current = child
		else
			break
		end
	end
	return current or node
end

local function normalize_string_list(value)
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

local function merge_tags(existing, parsed)
	local seen = {}
	return vim.iter(vim.list_extend(normalize_string_list(existing), normalize_string_list(parsed)))
		:filter(function(tag)
			if seen[tag] then
				return false
			end
			seen[tag] = true
			return true
		end)
		:totable()
end

---@param bufnr number
---@return table|nil
function M.read(bufnr)
	local tree = vim.treesitter.get_parser(bufnr, "markdown"):parse()[1]
	if not tree then
		return nil
	end

	for _, match, _ in markdown_frontmatter_query:iter_matches(tree:root(), bufnr, 0, -1) do
		for id, nodes in pairs(match) do
			if markdown_frontmatter_query.captures[id] == "fm" and nodes[1] then
				local node = nodes[1]
				local sr, _, er, _ = node:range()
				local text = vim.treesitter.get_node_text(node, bufnr) or ""
				local yaml_text = text:gsub("^%-%-%-%s*\n", ""):gsub("\n%-%-%-%s*$", "")
				return {
					start_row = sr + 1,
					end_row = er,
					yaml_text = yaml_text,
					meta = M.parse_yaml(yaml_text),
				}
			end
		end
	end

	return nil
end

---@param yaml_text string
---@return table
function M.parse_yaml(yaml_text)
	local tree = vim.treesitter.get_string_parser(yaml_text, "yaml"):parse()[1]
	if not tree then
		return {}
	end

	local out = {}
	local key_order = {}
	for _, match, _ in yaml_pairs_query:iter_matches(tree:root(), yaml_text, 0, -1) do
		local key_node, value_node
		for id, nodes in pairs(match) do
			local cap = yaml_pairs_query.captures[id]
			if cap == "key" then
				key_node = nodes[1]
			elseif cap == "value" then
				value_node = nodes[1]
			end
		end

		if key_node and value_node then
			local key = trim_node_text(key_node, yaml_text)
			if key ~= "" then
				local values = {}
				collect_scalar_values(value_node, yaml_text, values)
				local normalized_value_node = unwrap_value_node(value_node)
				local value_type = normalized_value_node:type()
				local is_array = value_type == "flow_sequence" or value_type == "block_sequence"
				if is_array or #values > 1 then
					out[key] = values
				else
					out[key] = values[1] or trim_node_text(value_node, yaml_text)
				end
				key_order[#key_order + 1] = key
			end
		end
	end

	out._key_order = key_order
	return out
end

---@param meta table
---@return string
function M.dump_yaml(meta)
	local copy = vim.deepcopy(meta)
	local key_order = copy._key_order or {}
	copy._key_order = nil

	local seen = {}
	for _, key in ipairs(key_order) do
		seen[key] = true
	end
	for key in pairs(copy) do
		if not seen[key] then
			key_order[#key_order + 1] = key
		end
	end

	local function yaml_scalar(value)
		local ty = type(value)
		if ty == "string" then
			return vim.json.encode(value)
		end
		if ty == "number" or ty == "boolean" then
			return tostring(value)
		end
		return vim.json.encode(tostring(value))
	end

	local lines = {}
	for _, key in ipairs(key_order) do
		local value = copy[key]
		if value ~= nil and not (type(value) == "table" and not is_list(value)) then
			if type(value) == "table" then
				lines[#lines + 1] = key .. ": [" .. table.concat(vim.tbl_map(yaml_scalar, value), ", ") .. "]"
			else
				lines[#lines + 1] = key .. ": " .. yaml_scalar(value)
			end
		end
	end

	return table.concat(lines, "\n")
end

function M.parse_title_pattern(title)
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

---@param bufnr number
---@param meta table
---@return table
function M.build_context(bufnr, meta)
	local title_value = type(meta.title) == "string" and meta.title or ""
	local parsed_tags, doc_title = M.parse_title_pattern(title_value)
	return {
		bufnr = bufnr,
		meta = meta,
		parsed_tags = parsed_tags or {},
		doc_title = doc_title,
	}
end

---@param meta table
---@param ctx table
---@return table|nil
function M.default_transform(meta, ctx)
	if not ctx.doc_title then
		return nil
	end

	local next_meta = vim.deepcopy(meta)
	next_meta.title = ctx.doc_title
	next_meta.tags = merge_tags(meta.tags, ctx.parsed_tags)
	return next_meta
end

---@param bufnr number
---@param transform? fun(meta: table, ctx: table): table|nil
---@return boolean
function M.sync(bufnr, transform)
	local doc = M.read(bufnr)
	if not doc or doc.yaml_text == "" then
		return false
	end

	local fn = transform or M.default_transform
	local next_meta = fn(doc.meta, M.build_context(bufnr, doc.meta))
	if not next_meta then
		return false
	end

	local new_yaml_text = M.dump_yaml(next_meta)
	if new_yaml_text == doc.yaml_text then
		return false
	end

	local new_lines = vim.split("---\n" .. new_yaml_text .. "\n---", "\n", { plain = true })
	vim.api.nvim_buf_set_lines(bufnr, doc.start_row - 1, doc.end_row, false, new_lines)
	return true
end

---@param meta table
---@return string|nil
---@return string|nil
function M.build_rename_basename(meta)
	local tags = normalize_string_list(meta.tags)
	if #tags == 0 then
		return nil, "请填写 frontmatter 中的 tags"
	end

	local aliases = normalize_string_list(meta.aliases)
	local doc_name = aliases[1] or ""
	if doc_name == "" then
		return nil, "请填写 frontmatter 中的 aliases"
	end

	local name = table.concat(tags, "_") .. "++" .. doc_name
	return (name:gsub('[\\/%*%?%:"<>|]', "_"))
end

---@param path string
---@param meta table
---@return string|nil
---@return string|nil
function M.build_rename_target_path(path, meta)
	local basename, err = M.build_rename_basename(meta)
	if not basename then
		return nil, err
	end

	local dir = vim.fn.fnamemodify(path, ":h")
	local ext = vim.fn.fnamemodify(path, ":e")
	return dir .. "/" .. basename .. (ext ~= "" and ("." .. ext) or "")
end

---@param bufnr number
---@return string|nil
---@return string|nil
function M.rename_buffer_from_frontmatter(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" or vim.bo[bufnr].buftype ~= "" then
		return nil, "not a file buffer"
	end

	local doc = M.read(bufnr)
	if not doc or doc.yaml_text == "" then
		return nil, "no frontmatter found"
	end

	local new_path, err = M.build_rename_target_path(path, doc.meta)
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

return M

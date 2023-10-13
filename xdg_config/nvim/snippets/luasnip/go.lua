local ls = require("luasnip")
local s = ls.s
local i = ls.insert_node
local t = ls.text_node
local d = ls.dynamic_node
local c = ls.choice_node
local f = ls.function_node
local sn = ls.sn

local ts = vim.treesitter
local get_node_text = ts.get_node_text

-- return error
do
	local query_name = "LuaSnip_Go_Func_Result"

	ts.query.set(
		"go",
		query_name,
		[[ [
    (function_declaration result: (_) @id)
    (method_declaration result: (_) @id)
    (func_literal result: (_) @id)
  ] ]]
	)

	local default_val = function(text, info)
		if text == "error" then
			info.index = info.index + 1
			return c(info.index, {
				t(info.err_name),
				t(string.format('fmt.Errorf("%s: %%v", %s)', info.func_name, info.err_name)),
				t(string.format('fmt.Errorf("%s: %%w", %s)', info.func_name, info.err_name)),
				t(string.format('errors.Wrap(%s, "%s")', info.err_name, info.func_name)),
			})
		-- elseif text == "int" then
		elseif text == "bool" then
			return t("false")
		elseif text == "string" then
			return t('""')
		elseif string.find(text, "int", 1, true) then
			return t("0")
		elseif string.find(text, "*", 1, true) then
			return t("nil")
		end

		info.index = info.index + 1
		return i(info.index, text)
	end

	local handlers = {
		["parameter_list"] = function(node, info)
			local sns = {}
			local count = node:named_child_count()
			for idx = 0, count - 1 do
				local child = node:named_child(idx)
				if child:named_child_count() == 1 then
					table.insert(sns, default_val(get_node_text(child, 0), info))
				else
					table.insert(sns, t({ get_node_text(child:named_child(0), 0) }))
				end
				if idx ~= count - 1 then
					table.insert(sns, t({ ", " }))
				end
			end

			return sns
		end,
		["type_identifier"] = function(node, info)
			return { default_val(get_node_text(node, 0), info) }
		end,
	}

	local function is_func(node)
		if
			node:type() == "function_declaration"
			or node:type() == "method_declaration"
			or node:type() == "func_literal"
		then
			return true
		end
		return false
	end

	local function get_result_node()
		local cur_node = ts.get_node()
		if not cur_node then
			return
		end
		local func_node
		local parent = cur_node:parent()
		while parent do
			if is_func(parent) then
				func_node = parent
				break
			end
			parent = parent:parent()
		end
		if not func_node then
			return
		end
		local query = ts.query.get("go", query_name)
		for _, node in query:iter_captures(func_node, 0) do
			local handler = handlers[node:type()]
			if handler then
				return node
			end
		end
	end

	local function ret_val_sns(info)
		local node = get_result_node()
		if node then
			return handlers[node:type()](node, info)
		end
		return { t("nil") }
	end

	local ret_vals_sn = function(args)
		return sn(
			nil,
			ret_val_sns({
				index = 0,
				err_name = args[1][1],
				func_name = args[2][1],
			})
		)
	end

	local function same_as(index)
		return f(function(args)
			return args[1]
		end, { index })
	end

	return {
		s("efi", {
			i(1, { "val" }),
			t(", "),
			i(2, { "err" }),
			t(" := "),
			i(3, { "fn" }),
			t("("),
			i(4),
			t(")"),
			t({ "", "if " }),
			same_as(2),
			t({ " != nil {", "\treturn " }),
			d(5, ret_vals_sn, { 2, 3 }),
			t({ "", "}" }),
			i(0),
		}),
	}
end

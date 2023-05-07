local M = {}

local function mk_tag_item(name, range, uri)
	local start = range.start
	return {
		name = name,
		filename = vim.uri_to_fname(uri),
		cmd = string.format("call cursor(%d, %d)", start.line + 1, start.character + 1),
	}
end

function M.symbol_tagfunc(pattern, flags, _)
	if not (flags == "" or flags == "c" or flags == "i") then
		return vim.NIL
	end
	local clients = vim.lsp.get_active_clients()
	local num_clients = vim.tbl_count(clients)
	local results = {}
	for _, client in pairs(clients) do
		client.request("workspace/symbol", { query = pattern }, function(_, method_or_result, result_or_ctx)
			local result = type(method_or_result) == "string" and result_or_ctx or method_or_result
			for _, symbol in pairs(result or {}) do
				local loc = symbol.location
				local item = mk_tag_item(symbol.name, loc.range, loc.uri)
				item.kind = (vim.lsp.protocol.SymbolKind[symbol.kind] or "Unknown")[1]
				table.insert(results, item)
			end
			num_clients = num_clients - 1
		end, 0)
	end
	vim.wait(1000, function()
		return num_clients == 0
	end)
	return results
end

return M

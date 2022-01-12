local M = {}

M.check_capabilities = function(feature, client_id)
	local clients = vim.lsp.buf_get_clients(client_id or 0)

	local supported_client = false
	for _, client in pairs(clients) do
		-- log(client.resolved_capabilities)
		supported_client = client.resolved_capabilities[feature]
		if supported_client then
			break
		end
	end

	if supported_client then
		return true
	else
		if #clients == 0 then
			-- log("LSP: no client attached")
		else
			-- log("LSP: server does not support " .. feature)
		end
		return false
	end
end

return M

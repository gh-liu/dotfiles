local M = {}
M.progress = function(handler)
  if type(handler) ~= "function" then
    return
  end

  vim.lsp.handlers["$/progress"] = function(err, msg, info)
    handler(err, msg, info)

    print("err: " .. vim.inspect(err))
    print("msg: " .. vim.inspect(msg))
    print("info:" .. vim.inspect(info))

    -- msg = {
    -- 	token = "",
    -- 	value = {
    -- 		kind = "", // begin report end
    -- 		message = "",
    -- 		title = ""
    -- 		percentage = 13
    -- 	}
    -- }

    -- info = {
    -- 	client_id = 1,
    -- 	method = ""
    -- }

    local client_id = info.client_id
    local client_name = vim.lsp.get_client_by_id(info.client_id).name
  end
end

return M

-- https://raw.githubusercontent.com/golang/tools/refs/heads/master/gopls/doc/design/integrating-interactive-refactoring.md
local function prompt_field(field, answer, callback)
	local default = answer ~= nil and answer or field.default
	local prompt = field.description or field.id
	if field.error and field.error ~= "" then
		prompt = prompt .. " (" .. field.error .. ")"
	end

	local kind = vim.tbl_get(field, "type", "kind")
	if kind == "enum" then
		vim.ui.select(field.type.entries or {}, {
			prompt = prompt,
			format_item = function(item)
				return item.description or item.value
			end,
		}, function(choice)
			callback(choice and choice.value or nil)
		end)
	elseif kind == "bool" then
		vim.ui.select({ true, false }, { prompt = prompt }, callback)
	elseif kind == "number" then
		vim.ui.input({
			prompt = prompt .. ": ",
			scope = "cursor",
			default = default and tostring(default) or nil,
		}, function(input)
			callback(input and tonumber(input) or nil)
		end)
	elseif kind == "string" then
		vim.ui.input({
			prompt = prompt .. ": ",
			scope = "cursor",
			default = default and tostring(default) or nil,
		}, callback)
	else
		vim.notify("gopls interactive resolve: unsupported input type " .. vim.inspect(kind), vim.log.levels.WARN)
		callback(nil)
	end
end
local function prompt_fields(fields, existing_answers, callback)
	local answers_by_id = {}
	for _, answer in ipairs(existing_answers or {}) do
		answers_by_id[answer.id] = answer.value
	end

	local answers = {}
	local index = 1
	local next_field
	next_field = function()
		local field = fields[index]
		if not field then
			callback(answers)
			return
		end

		prompt_field(field, answers_by_id[field.id], function(value)
			if value == nil and field.required then
				callback(nil)
				return
			end
			if value ~= nil then
				table.insert(answers, { id = field.id, value = value })
			end
			index = index + 1
			next_field()
		end)
	end
	next_field()
end
local function apply_answers(command)
	local args = command.arguments and command.arguments[1]
	for _, answer in ipairs(command.formAnswers or {}) do
		if args then
			args[answer.id] = answer.value
		end
	end
	return command
end
local function resolve_command(client, bufnr, command)
	client:request("command/resolve", command, function(err, resolved)
		if err then
			vim.notify(err.message or vim.inspect(err), vim.log.levels.ERROR)
			return
		end

		local fields = resolved and resolved.formFields or {}
		if #fields == 0 then
			client:request(
				vim.lsp.protocol.Methods.workspace_executeCommand,
				apply_answers(resolved),
				function(exec_err)
					if exec_err then
						vim.notify(exec_err.message or vim.inspect(exec_err), vim.log.levels.ERROR)
					end
				end,
				bufnr
			)
			return
		end

		prompt_fields(fields, resolved.formAnswers, function(answers)
			if not answers then
				return
			end
			resolved.formFields = nil
			resolved.formAnswers = answers
			resolve_command(client, bufnr, resolved)
		end)
	end, bufnr)
end

local interactive_command = function(command, ctx)
	local client = ctx and vim.lsp.get_client_by_id(ctx.client_id)
	if not client then
		return
	end
	resolve_command(client, ctx.bufnr, command)
end

vim.lsp.config("gopls", {
	capabilities = {
		experimental = {
			interactiveResolve = { inputTypes = { "string", "enum", "bool", "number" } },
		},
	},
	commands = {
		["gopls.implement_interface"] = interactive_command,
		["gopls.modify_tags"] = interactive_command,
	},
})

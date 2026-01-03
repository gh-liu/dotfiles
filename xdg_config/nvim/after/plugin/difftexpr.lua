local ns = vim.api.nvim_create_namespace("Difftexpr")

-- 返回假的 diff，骗过 Neovim 验证
_G.Difftexpr = function()
	local fin = vim.v.fname_in
	local fnew = vim.v.fname_new
	local fout = vim.v.fname_out

	local dummy_line_num = 1
	local target_line = "dummy_line"

	local ts = os.date("%Y-%m-%d %H:%M:%S.000000000 +0800")
	vim.fn.writefile({
		"--- " .. fin .. "\t" .. ts,
		"+++ " .. fnew .. "\t" .. ts,
		"@@ -" .. dummy_line_num .. " +" .. dummy_line_num .. " @@",
		"-" .. target_line,
		"+" .. target_line,
	}, fout)
end

-- vim.o.diffexpr = "v:lua._G.Difftexpr()"
-- vim.opt.diffopt:append("inline:none")

-- 运行 difft 并返回解析后的 JSON
-- line_oriented: true 使用 --graph-limit 1（准确的 ADD/DELETE）
--                false 使用默认模式（语法感知的 CHANGE + DiffText）
local function run_difft(file_lhs, file_rhs, line_oriented)
	local graph_limit = line_oriented and "--graph-limit 1 " or ""
	local cmd = string.format(
		"DFT_UNSTABLE=yes difft %s--display json %s %s 2>/dev/null",
		graph_limit,
		vim.fn.shellescape(file_lhs),
		vim.fn.shellescape(file_rhs)
	)
	local output = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 or output == "" then
		return nil
	end
	local ok, result = pcall(vim.json.decode, output)
	if not ok then
		return nil
	end
	return result
end

-- 从 difft 结果中提取行信息
-- 返回 {lhs_lines, rhs_lines}，每个是 {[line_number] = {type, changes}}
local function extract_lines(result)
	local lhs_lines = {}
	local rhs_lines = {}
	if not result or not result.chunks then
		return lhs_lines, rhs_lines
	end
	for _, chunk in ipairs(result.chunks) do
		for _, hunk in ipairs(chunk) do
			local has_lhs = hunk.lhs ~= nil
			local has_rhs = hunk.rhs ~= nil
			if has_lhs and has_rhs then
				lhs_lines[hunk.lhs.line_number] = { type = "change", changes = hunk.lhs.changes }
				rhs_lines[hunk.rhs.line_number] = { type = "change", changes = hunk.rhs.changes }
			elseif has_lhs then
				lhs_lines[hunk.lhs.line_number] = { type = "delete", changes = hunk.lhs.changes }
			elseif has_rhs then
				rhs_lines[hunk.rhs.line_number] = { type = "add", changes = hunk.rhs.changes }
			end
		end
	end
	return lhs_lines, rhs_lines
end

-- 合并两次 difft 的结果
-- line_result: --graph-limit 1 的结果（准确的 ADD/DELETE）
-- syntax_result: 默认模式的结果（语法感知的 CHANGE + DiffText）
local function merge_results(line_result, syntax_result)
	local line_lhs, line_rhs = extract_lines(line_result)
	local syntax_lhs, syntax_rhs = extract_lines(syntax_result)

	-- 合并策略：
	-- 1. ADD/DELETE 使用 line_result（准确）
	-- 2. CHANGE 使用 syntax_result 的 changes（语法感知）
	local merged_lhs = {}
	local merged_rhs = {}

	-- 处理 lhs
	for ln, info in pairs(line_lhs) do
		if info.type == "delete" then
			-- DELETE 直接使用 line_result
			merged_lhs[ln] = info
		elseif info.type == "change" then
			-- CHANGE 优先使用 syntax_result 的 changes
			if syntax_lhs[ln] and syntax_lhs[ln].changes then
				merged_lhs[ln] = { type = "change", changes = syntax_lhs[ln].changes }
			else
				merged_lhs[ln] = info
			end
		end
	end

	-- 处理 rhs
	for ln, info in pairs(line_rhs) do
		if info.type == "add" then
			merged_rhs[ln] = info
		elseif info.type == "change" then
			if syntax_rhs[ln] and syntax_rhs[ln].changes then
				merged_rhs[ln] = { type = "change", changes = syntax_rhs[ln].changes }
			else
				merged_rhs[ln] = info
			end
		end
	end

	return merged_lhs, merged_rhs
end

-- 渲染单行
local function render_line(buf, line_number, info)
	local line_count = vim.api.nvim_buf_line_count(buf)
	if line_number < 0 or line_number >= line_count then
		return
	end

	local line_text = vim.api.nvim_buf_get_lines(buf, line_number, line_number + 1, false)[1] or ""
	local line_len = #line_text

	-- 确定高亮组
	local line_hl = ({
		add = "DiffAdd",
		delete = "DiffDelete",
		change = "DiffChange",
	})[info.type]

	-- 行级高亮
	vim.api.nvim_buf_set_extmark(buf, ns, line_number, 0, {
		line_hl_group = line_hl,
		priority = 100,
	})

	-- 字符级高亮（只对 CHANGE 且有语法感知的 changes）
	if info.type == "change" and info.changes then
		for _, c in ipairs(info.changes) do
			if c.highlight ~= "normal" then
				local col_start = math.min(c.start, line_len)
				local col_end = math.min(c["end"], line_len)
				if col_start < col_end then
					vim.api.nvim_buf_set_extmark(buf, ns, line_number, col_start, {
						end_col = col_end,
						hl_group = "DiffText",
						hl_mode = "replace",
						priority = 200,
					})
				end
			end
		end
	end
end

vim.api.nvim_create_autocmd("DiffUpdated", {
	callback = function()
		vim.schedule(function()
			-- 收集 diff 窗口信息
			local diff_wins = {}
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.wo[win].diff then
					local buf = vim.api.nvim_win_get_buf(win)
					local name = vim.api.nvim_buf_get_name(buf)
					table.insert(diff_wins, { win = win, buf = buf, name = name })
					vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
				end
			end

			if #diff_wins < 2 then
				return
			end

			local file_lhs = diff_wins[1].name
			local file_rhs = diff_wins[2].name

			-- 两次 difft：
			-- 1. line-oriented：准确的 ADD/DELETE
			-- 2. structural：语法感知的 DiffText
			local line_result = run_difft(file_lhs, file_rhs, true)
			local syntax_result = run_difft(file_lhs, file_rhs, false)

			if not line_result then
				return
			end

			-- 合并结果
			local merged_lhs, merged_rhs = merge_results(line_result, syntax_result)

			-- 渲染
			for ln, info in pairs(merged_lhs) do
				render_line(diff_wins[1].buf, ln, info)
			end
			for ln, info in pairs(merged_rhs) do
				render_line(diff_wins[2].buf, ln, info)
			end
		end)
	end,
})

# blink.cmp

> https://cmp.saghen.dev

补全: 

不同的source:

命令行、终端补全:

UI appearance

fuzzy: 过滤, 排序

```lua
-- 注册数据源、文件类型指定数据源
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "codecompanion" },
	callback = function()
		local ok, cmp = pcall(require, "blink.cmp")
		if ok then
			cmp.add_provider("codecompanion", {
				name = "CodeCompanion",
				module = "codecompanion.providers.completion.blink",
				enabled = true,
			})

			cmp.add_filetype_source("ft", "source")
		end
	end,
	once = true,
})
```


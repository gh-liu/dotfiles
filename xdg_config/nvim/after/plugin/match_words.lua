local match_words = function(word_groups)
	return vim.iter(word_groups)
		:map(function(word_group)
			return vim.iter(word_group):join(":")
		end)
		:join(",")
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = "go",
	callback = function(args)
		vim.b.match_words = match_words({
			{ [[^\<func\>]], [[\<return\>]] },
		})
	end,
})

vim.api.nvim_buf_create_user_command(0, "PyTest", function(opts)
	-- TODO
	print("https://docs.pytest.org/en/stable/explanation/goodpractices.html#test-discovery")
end, { desc = "Py: generate or jump to test" })

vim.cmd.inoreabbrev("<buffer> true True")
vim.cmd.inoreabbrev("<buffer> false False")
vim.cmd.inoreabbrev("<buffer> null None")
vim.cmd.inoreabbrev("<buffer> none None")
vim.cmd.inoreabbrev("<buffer> nil None")

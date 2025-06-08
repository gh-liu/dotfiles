vim.api.nvim_buf_create_user_command(0, "PyTest", function(opts)
	-- TODO
	print("https://docs.pytest.org/en/stable/explanation/goodpractices.html#test-discovery")
end, { desc = "Py: generate or jump to test" })

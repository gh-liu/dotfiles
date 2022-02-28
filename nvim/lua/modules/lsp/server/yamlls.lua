local extension = ".{yml,yaml}"
return {
	settings = {
		yaml = {
			schemas = {
				["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = {
					"docker-compose*." .. extension,
				},
				["http://json.schemastore.org/github-workflow.json"] = ".github/workflows/*." .. extension,
				["http://json.schemastore.org/github-action.json"] = ".github/action." .. extension,
			},
		},
	},
}

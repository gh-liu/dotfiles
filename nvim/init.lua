local present, impatient = pcall(require, "impatient")

if present then
  impatient.enable_profile()
end

local modules = {
  "core.global",
  "core.options",
  "core.keymaps",
  "core.autocmd",
  "core.command",
  "core.builtin",
  "modules.plugins",
  "modules.lsp",
  "modules.dap",
  "modules.lang.go",
  "core.colorscheme",
}

for _, module in ipairs(modules) do
  local ok, err = pcall(require, module)
  if not ok then
    error("Error loading " .. module .. "\n\n" .. err)
  end
end

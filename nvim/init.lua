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
  "core.colorscheme",
  "core.builtin",
  "modules.statusline",
  "modules.plugins",
  "modules.lsp",
  "modules.lang.go",
}

for _, module in ipairs(modules) do
  local ok, err = pcall(require, module)
  if not ok then
    error("Error loading " .. module .. "\n\n" .. err)
  end
end

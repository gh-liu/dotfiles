-- sudo apt install lldb-11
-- sudo ln -s /usr/bin/lldb-vscode-11 /usr/bin/lldb-vscode
return {
  type = "executable",
  command = "/usr/bin/lldb-vscode", -- adjust as needed, must be absolute path
  name = "lldb",
}

# Nvim Lua Plugin Development Skill

Neovim Lua 插件开发核心最佳实践。精简、轻量的技能文件。

## 目录结构

```
nvim-lua-plugin/
├── SKILL.md                    # 主技能文件
└── README.md                   # 本文件
```

## 使用方法

安装后，Claude 会自动识别并在相关任务中使用此 skill。按 SKILL.md 的 Step 2 指导创建目录结构。

## 核心原则

1. **plugin 入口极小** - 只注册 commands/keymaps/autocmd
2. **实现延迟加载** - 回调里 `require()`，不在顶层
3. **配置与初始化分离** - `setup()` 只 merge 配置
4. **优先 `<Plug>` 接口** - 避免全局 keymap 冲突
5. **可诊断** - 提供 `health.lua`（推荐）
6. **可阅读** - 提供 vimdoc（推荐）

## 权威文档

优先查阅 Neovim 内置帮助：

```vim
:h lua-plugin         " 插件开发指南
:h lua-guide          " Lua 使用手册
:h health-dev         " Health check 开发
:h help-writing       " Vimdoc 规范
```

## 参考资源

- [Neovim Lua Guide](https://neovim.io/doc/user/lua-guide.html)
- [mini.nvim](https://github.com/nvim-mini/mini.nvim)
- [LuaLS/lua-language-server](https://github.com/LuaLS/lua-language-server)

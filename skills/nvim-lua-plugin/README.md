# Nvim Lua Plugin Development Skill

Neovim Lua 插件开发最佳实践技能文件，包含代码骨架、参考文档和测试模板。

## 目录结构

```
nvim-lua-plugin/
├── SKILL.md                    # 主技能文件（Claude Skills 使用入口）
├── README.md                   # 本文件
├── references/                 # 参考文档
│   ├── nvim-lua-plugin-guidelines.md    # 快速索引
│   ├── api_reference.md                 # 完整指南（按 help tags 组织）
│   ├── nvim-lua-api-cheatsheet.md       # API 速查表
│   ├── common-patterns.md               # 常见代码模式
│   ├── vimdoc-template.md               # vimdoc 模板
│   └── testing-mini-test.md             # mini.test 测试指南
└── assets/                    # 可复制的代码骨架
    ├── plugin-skeleton/         # 完整插件骨架
    │   ├── plugin/
    │   │   └── myplugin.lua
    │   ├── lua/myplugin/
    │   │   ├── init.lua
    │   │   ├── config.lua
    │   │   ├── actions.lua
    │   │   └── health.lua
    │   ├── doc/
    │   │   └── myplugin.txt
    │   └── TREE.txt
    ├── mini-test-skeleton/      # 测试骨架
    │   ├── tests/
    │   │   ├── test_smoke.lua
    │   │   └── test_actions.lua
    │   ├── scripts/
    │   │   └── minimal_init.lua
    │   └── TREE.txt
    └── minimal-repro-config/    # 最小复现配置
        └── init.lua
```

## 使用方法

### 1. 作为 Claude Skill 使用

将此目录放到 `~/.claude/skills/` 或你的项目 `skills/` 目录下。Claude 会自动识别并使用它。

### 2. 创建新插件骨架

复制骨架文件到你的插件仓库：

```bash
cp -r assets/plugin-skeleton/* your-plugin/

# 替换 myplugin 为你的插件名
find your-plugin -type f -exec sed -i 's/myplugin/yourplugin/g' {} +
find your-plugin -type f -exec mv {} {} \;  # 处理文件名重命名
```

### 3. 添加测试

复制测试骨架：

```bash
cp -r assets/mini-test-skeleton/* your-plugin/

# 运行测试
nvim --headless -u scripts/minimal_init.lua -c "lua MiniTest.run()"
```

## 核心原则

1. **入口轻、实现懒** - `plugin/` 只注册入口，实现放 `lua/` 并延迟 require
2. **少做默认 keymap** - 优先 `<Plug>`/命令/Lua API
3. **配置与初始化分离** - `setup()` 只 merge 配置
4. **可诊断** - 提供 `health.lua`
5. **可阅读** - 提供 vimdoc
6. **可测试** - 使用 `mini.test`

## 权威文档

优先查阅 Neovim 内置帮助：

- `:h lua-plugin` - 插件开发指南
- `:h lua-guide` - Lua 使用手册
- `:h health-dev` - Health check 开发
- `:h help-writing` - Vimdoc 写作规范

## 相关资源

- [Neovim Lua Guide](https://neovim.io/doc/user/lua-guide.html)
- [mini.nvim](https://github.com/nvim-mini/mini.nvim) - 包含 mini.test
- [lua-language-server](https://github.com/LuaLS/lua-language-server) - 类型检查

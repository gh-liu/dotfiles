# queries/ vs after/queries/

Neovim 按 runtimepath 顺序加载 query 文件。

## 有插件提供同名 query 时

| 位置             | `;; extends` | 效果                   |
|------------------|--------------|------------------------|
| `queries/`       | 无           | **替换**插件的 query   |
| `queries/`       | 有           | **追加**到插件的 query |
| `after/queries/` | 有           | **追加**到插件的 query |
| `after/queries/` | 无           | **被忽略**             |

## 无插件提供同名 query 时

放 `queries/` 或 `after/queries/`，有无 `;; extends`，都一样生效。

## 推荐用法

- **覆盖插件** → `queries/`，不加 `;; extends`
- **扩展插件** → `after/queries/`，加 `;; extends`
- **自定义 query** → `after/queries/`

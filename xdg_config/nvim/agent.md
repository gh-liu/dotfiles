# agent

1. chat

Chat   -> 进入就近的会话
Chat!  -> 新建会话
<>Chat -> 选中，复制进就近会话
<>Chat -> 选中，开启新会话

2. fim? lsp的 inline completion
TODO: in process lsp

3. diff && apply:
其实apply没有必要，使用vim的diff功能

2. rag: repo index

source: treesitter, lsp workspace symbols
抽象出增删改查接口，用于editor更新？

vector database
做成一个lsp？executeCommand进行增删改成，lspprogess反应进度
这样子，有没有什么trick可以直接pull其他lsp的数据？
TODO: 哈希判断文件是否修改；TreeSitterChunker分块？针对块生成向量。

3. ACP

nvim 处理 ui 部分
与大模型交互，实现一个subagent，用lua实现？还是python？
TODO: rag使用python实现，则全部用python吧

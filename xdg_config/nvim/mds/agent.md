# agent

> https://code.visualstudio.com/docs/copilot/getting-started
> https://code.visualstudio.com/assets/api/extension-guides/ai/tools/copilot-tool-calling-flow.png

1. chat

modes: ask, edit

Ask   * -> 进入就近的会话
Ask!  * -> 新建会话
<>Ask * -> 选中，复制进就近会话
<>Ask * -> 选中，开启新会话
0Ask -> 当前行
* -> question?
--session= 会话名称补全？初始化会话名称：session+时间戳?
可以使用tools嘛？默认配置false?

<>Edit * -> 修改代码，给用户选择
<>Edit! * -> 直接修改
如果没有选中，当前行？或者整个文件？倾向于整个文件
0Edit -> 当前行
? 需要显示chat窗吗？需要！进行解释
Chat里面Edit?

agent = reason+plan+implement
多agent？一种tool的封装？参考软件开发流程图？claudecode的的subagent？ 和 copilot-instructions.md 的区别？
https://docs.anthropic.com/zh-CN/docs/claude-code/sub-agents

agent: 允许模型做决定，找上下文，执行命令
	只读工具，全工具: perm

修改的文件如何展示？qflist？怎么diff？inlinediff?参考minidiff？
cfdo keep/undo 

?参数：--context=diagnostic,balabala,aa

agent? ask? edit? vscodeCHAT的几种模式？
选中可以使用的tools？
添加上下文？Add Context
会话历史？sqlite, json?

请求响应都有1个id，这个id使用extmark绑定，每次修改事件，找到对应的id和内容？
判断是否修改过，做到可以编辑上次请求内容。
浮动窗口？input？

隐式上下文? 从哪个文件跳过来的？

workspace index: rag+向量数据库实现？

代码块插入文件？命令由term执行？


`#balabala` 资源？resource
`@balabal` 工具 tools  NOTE: 工具集
`/balabal` 命令？command
codebase，文件夹，文件，符号?
使用工具的时候，是否赞成？这个对话？始终允许？

.github/copilot-instructions.md 也是一种prompt了
.github/chatmodes 定义modes



2. fim? lsp的 inline completion
TODO: in process lsp

3. diff && apply:
其实apply没有必要，使用vim的diff功能
NOTE: 似乎还是有需要的，可以在diff上进行迭代

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





nvim通过lsp启动subagent，交换配置；
subagent再获取nvim的socket，通过acp协议通信？


## nvim mcp

nvim -l lua 加socket地址，获取nvim

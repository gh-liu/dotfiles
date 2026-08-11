# extensions

https://pi.dev/docs/latest/extensions

## Web search

`websearch` registers a local `web_search` tool backed by the Exa Search API. Export
`EXA_API_KEY` in the environment that starts Pi.

## Find session

`intercom` currently provides only the `find_session` tool. It searches all
local Pi session histories and returns matching session metadata plus context
snippets. Optional `cwd` and `limit` parameters narrow the search.

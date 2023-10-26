local ls = require("luasnip")
local s = ls.s
local i = ls.insert_node
local t = ls.text_node

local snips = {
	s("derivedebug", t("#[derive(Debug)]")),
	s(":turbofish", { t({ "::<" }), i(0), t({ ">" }) }),
}
return snips

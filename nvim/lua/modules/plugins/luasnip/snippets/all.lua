---@diagnostic disable: undefined-global

local date_input = function(args, snip, old_state, fmt)
  local fmt = fmt or "%Y-%m-%d"
  return sn(nil, i(1, os.date(fmt)))
end

local function with_cmt(cmt)
  return string.format(vim.bo.commentstring, " " .. cmt)
end

return {
  -- All: Prints the current date in Y-m-d format
  s(
    "date",
    f(function()
      return os.date("%Y-%m-%d")
    end)
  ),
  s("td", { t("// TODO "), d(1, date_input, {}, "%A, %B %d of %Y") }),
  s({ trig = "tdc", name = "TODO" }, {
    d(1, function()
      return s("", {
        c(1, {
          t(with_cmt("TODO: ")),
          t(with_cmt("FIXME: ")),
          t(with_cmt("HACK: ")),
          t(with_cmt("BUG: ")),
        }),
      })
    end),
    i(0),
  }),
},
  nil

---@diagnostic disable: undefined-global

local date_input = function(args, snip, old_state, fmt)
  local fmt = fmt or "%Y-%m-%d"
  return sn(nil, i(1, os.date(fmt)))
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
},
  nil

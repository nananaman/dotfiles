local M = {}

function M.get_basename(s)
  return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

function M.convert_home_dir(path)
  local cwd = path
  local home = os.getenv("HOME")
  cwd = cwd:gsub("^" .. home .. "/", "~/")
  return cwd
end

function M.merge_tables(t1, t2)
  for k, v in pairs(t2) do
    if (type(v) == "table") and (type(t1[k] or false) == "table") then
      M.merge_tables(t1[k], t2[k])
    else
      t1[k] = v
    end
  end
  return t1
end

function M.execCommand(command)
  local handle = io.popen(command, "r")
  local content = handle:read("*all")
  local rc = {handle: close()}
  return rc[1], content
end

return M

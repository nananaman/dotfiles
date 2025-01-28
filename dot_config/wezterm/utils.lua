local wezterm = require("wezterm")

local M = {}

function M.get_basename(s)
  return string.gsub(tostring(s), "(.*[/\\])(.*)", "%2")
end

---@param path string
---@return string
function M.convert_home_dir(path)
  local cwd = path
  local home = os.getenv("HOME")
  if home ~= nil then
    cwd = string.gsub(tostring(cwd), "^" .. home .. "/", "~/")
  end
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

function M.is_wsl()
  return wezterm.target_triple == "x86_64-pc-windows-msvc"
end

function M.is_apple_silicon()
  return wezterm.target_triple == "aarch64-apple-darwin"
end

return M

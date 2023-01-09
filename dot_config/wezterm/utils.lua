local wezterm = require("wezterm")

local M = {}

function M.get_basename(s)
  return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

function M.convert_home_dir(path)
  local cwd = path
  local home = os.getenv("HOME")
  if home ~= nil then
    cwd = cwd:gsub("^" .. home .. "/", "~/")
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

function M.run_child_process(command)
  if wezterm.target_triple == "x86_64-pc-windows-msvc" then
    local wsl_prefix = { "wsl.exe" }

    local wsl_distro_name = os.getenv("WSL_DISTRO_NAME")
    if wsl_distro_name ~= nil then
      wsl_prefix = { "wsl.exe", "--distribution", wsl_distro_name }
    end

    for i = 1, #wsl_prefix do
      table.insert(command, i, wsl_prefix[i])
    end
  end
  local success, stdout, stderr = wezterm.run_child_process(command)
  return success, stdout, stderr
end

return M

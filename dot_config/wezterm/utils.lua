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
  command = M.correct_command(command)
  local success, stdout, stderr = wezterm.run_child_process(command)
  return success, stdout, stderr
end

function M.spawn_command_in_new_tab(window, pane, command)
  command = M.correct_command({ "fish", "-l", "-c", command })
  window:perform_action(
    wezterm.action({
      SpawnCommandInNewTab = {
        args = command
      },
    }),
    pane
  )
end

-- OS に依るコマンドの差異を補正する
function M.correct_command(command)
  if M.is_wsl() then
    local wsl_prefix = { "wsl.exe", "--distribution", "Ubuntu-22.04" }

    for i = 1, #wsl_prefix do
      table.insert(command, i, wsl_prefix[i])
    end
  end
  return command
end

function M.is_wsl()
  return wezterm.target_triple == "x86_64-pc-windows-msvc"
end

return M

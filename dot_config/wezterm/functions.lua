local wezterm = require("wezterm")
local utils = require("utils")

local M = {}

function M.format_tab_title(tab, tabs, panes, config, hover, max_width)
  if user_title ~= nil and #user_title > 0 then
    return {
      { Text = tab.tab_index + 1 .. ":" .. user_title },
    }
  end

  -- local title = wezterm.truncate_right(utils.get_basename(tab.active_pane.foreground_process_name), max_width)
  local title = ""
  if title == "" then
    local uri = utils.convert_home_dir(tab.active_pane.current_working_dir)
    local basename = utils.get_basename(uri)
    if basename == "" then
      basename = uri
    end
    title = wezterm.truncate_right(basename, max_width)
  end
  return {
    { Text = " " .. tab.tab_index + 1 .. ":" .. title .. " " },
  }
end

function M.update_right_status(window, pane)
  -- Each element holds the text for a cell in a "powerline" style << fade
  local cells = {}
  table.insert(cells, window:active_workspace())

  local success, stdout, stderr = utils.run_child_process({ "kubectl", "config", "current-context" })
  if success then
    local kube_ctx = string.gsub(stdout, "[\n\r]", "")
    table.insert(cells, "⎈ " .. kube_ctx)
  end

  -- An entry for each battery (typically 0 or 1 battery)
  for _, b in ipairs(wezterm.battery_info()) do
    table.insert(cells, string.format("🔋 %.0f%%", b.state_of_charge * 100))
  end

  local date = wezterm.strftime("%a %b %-d %H:%M:%S")
  table.insert(cells, date)

  -- The powerline < symbol
  local LEFT_ARROW = utf8.char(0xe0b3)
  -- The filled in variant of the < symbol
  local SOLID_LEFT_ARROW = utf8.char(0xe0b2)

  -- Color palette for the backgrounds of each cell
  local colors = {
    "#1f1f28",
    "#1f1f28",
    "#252535",
    "#7e9cd8",
  }

  -- Foreground color for the text across the fade
  local text_fg_colors = {
    "#dcd7ba",
    "#dcd7ba",
    "#7e9cd8",
    "#1f1f28",
  }

  local left_arrow_colors = {
    "#dcd7ba",
    "#dcd7ba",
    "#252535",
    "#7e9cd8",
  }

  local left_arrows = {
    LEFT_ARROW,
    LEFT_ARROW,
    SOLID_LEFT_ARROW,
    SOLID_LEFT_ARROW,
  }

  -- The elements to be formatted
  local elements = {}
  -- How many cells have been formatted
  local num_cells = 0

  -- Translate a cell into elements
  local function push(text, is_last)
    local cell_no = num_cells + 1
    table.insert(elements, { Foreground = { Color = text_fg_colors[cell_no] } })
    table.insert(elements, { Background = { Color = colors[cell_no] } })
    table.insert(elements, { Text = " " .. text .. " " })
    if not is_last then
      table.insert(elements, { Foreground = { Color = left_arrow_colors[cell_no + 1] } })
      table.insert(elements, { Text = left_arrows[cell_no + 1] })
    end
    num_cells = num_cells + 1
  end

  while #cells > 0 do
    local cell = table.remove(cells, 1)
    push(cell, #cells == 0)
  end

  window:set_right_status(wezterm.format(elements))
end

function M.trigger_open_ghq_project(window, pane)
  local command = "cd (ghq root)/(ghq list | fzf +m --reverse --prompt='Project > ') && vim"
  utils.spawn_command_in_new_tab(window, pane, command)
end

function M.trigger_nvim_with_scrollback(window, pane)
  local scrollback = pane:get_lines_as_text()
  local name = os.tmpname()
  local f = io.open(name, "w+")
  f:write(scrollback)
  f:flush()
  f:close()
  local command = "nvim " .. name
  utils.spawn_command_in_new_tab(window, pane, command)
  wezterm.sleep_ms(1000)
  os.remove(name)
end

return M

local wezterm = require 'wezterm';

---------------------------------------------------------------
--- wezterm on
---------------------------------------------------------------

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local user_title = tab.active_pane.user_vars.panetitle
	if user_title ~= nil and #user_title > 0 then
		return {
			{ Text = tab.tab_index + 1 .. ":" .. user_title },
		}
	end

	local title = wezterm.truncate_right(basename(tab.active_pane.foreground_process_name), max_width)
	if title == "" then
		local uri = convert_home_dir(tab.active_pane.current_working_dir)
		local basename = basename(uri)
		if basename == "" then
			basename = uri
		end
		title = wezterm.truncate_right(basename, max_width)
	end
	return {
		{ Text = " " .. tab.tab_index + 1 .. ":" .. title .. " " },
	}
end)

wezterm.on("update-right-status", function(window, pane)
    -- Each element holds the text for a cell in a "powerline" style << fade
  local cells = {};
  table.insert(cells, window:active_workspace())

  local kube_ctx = string.gsub(execCommand("/usr/local/bin/kubectl config current-context"), "[\n\r]", "");
  table.insert(cells, "⎈ " .. kube_ctx);

  -- An entry for each battery (typically 0 or 1 battery)
  for _, b in ipairs(wezterm.battery_info()) do
    table.insert(cells, string.format("🔋 %.0f%%", b.state_of_charge * 100))
  end

  local date = wezterm.strftime("%a %b %-d %H:%M:%S");
  table.insert(cells, date);

  -- The powerline < symbol
  local LEFT_ARROW = utf8.char(0xe0b3);
  -- The filled in variant of the < symbol
  local SOLID_LEFT_ARROW = utf8.char(0xe0b2)

  -- Color palette for the backgrounds of each cell
  local colors = {
    "#1f1f28",
    "#1f1f28",
    "#252535",
    "#7e9cd8",
  };

  -- Foreground color for the text across the fade
  local text_fg_colors = {
    "#dcd7ba",
    "#dcd7ba",
    "#7e9cd8",
    "#1f1f28",
  };

  local left_arrow_colors = {
    "#dcd7ba",
    "#dcd7ba",
    "#252535",
    "#7e9cd8",
  };

  local left_arrows = {
    LEFT_ARROW,
    LEFT_ARROW,
    SOLID_LEFT_ARROW,
    SOLID_LEFT_ARROW,
  };

  -- The elements to be formatted
  local elements = {};
  -- How many cells have been formatted
  local num_cells = 0;

  -- Translate a cell into elements
  function push(text, is_last)
    local cell_no = num_cells + 1
    table.insert(elements, {Foreground={Color=text_fg_colors[cell_no]}})
    table.insert(elements, {Background={Color=colors[cell_no]}})
    table.insert(elements, {Text=" "..text.." "})
    if not is_last then
      table.insert(elements, {Foreground={Color=left_arrow_colors[cell_no+1]}})
      table.insert(elements, {Text=left_arrows[cell_no+1]})
    end
    num_cells = num_cells + 1
  end

  while #cells > 0 do
    local cell = table.remove(cells, 1)
    push(cell, #cells == 0)
  end

  window:set_right_status(wezterm.format(elements));
end)

---------------------------------------------------------------
--- Functions
---------------------------------------------------------------
local io = require("io")
local os = require("os")

function execCommand(command)
  local handle = io.popen(command, "r")
  local content = handle:read("*all")
  handle: close()
  return content
end

function basename(s)
  return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

function convert_home_dir(path)
  local cwd = path;
  local home = os.getenv("HOME")
  cwd = cwd:gsub("^" .. home .. "/", "~/")
  return cwd
end

return {
  -- default_prog = {"wsl.exe"},
  default_prog = {"/usr/local/bin/fish", "-l"},

  font = wezterm.font("HackGenNerd Console"),
  font_size = 14,
  adjust_window_size_when_changing_font_size=false,
  hide_tab_bar_if_only_one_tab = false,
  tab_bar_at_bottom = true,
  use_fancy_tab_bar = false,
  tab_max_width = 16,

  ---------------------------------------------------------------
  --- Layout
  ---------------------------------------------------------------
  window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
  },

  ---------------------------------------------------------------
  --- Visual
  ---------------------------------------------------------------
  window_background_opacity = 0.9,

  -- https://github.com/rebelot/kanagawa.nvim/blob/master/extras/wezterm.lua
  force_reverse_video_cursor = true,
	colors = {
		foreground = "#dcd7ba",
		background = "#1f1f28",

		cursor_bg = "#c8c093",
		cursor_fg = "#c8c093",
		cursor_border = "#c8c093",

		selection_fg = "#c8c093",
		selection_bg = "#2d4f67",

		scrollbar_thumb = "#16161d",
		split = "#16161d",

		ansi = { "#090618", "#c34043", "#76946a", "#c0a36e", "#7e9cd8", "#957fb8", "#6a9589", "#c8c093" },
		brights = { "#727169", "#e82424", "#98bb6c", "#e6c384", "#7fb4ca", "#938aa9", "#7aa89f", "#dcd7ba" },
		indexed = { [16] = "#ffa066", [17] = "#ff5d62" },

    tab_bar = {
      active_tab = {
        bg_color = "#7e9cd8",
        fg_color = "#1f1f28"
      },
      inactive_tab = {
        bg_color = "#1f1f28",
        fg_color = "#7e9cd8"
      },
    }
	},

  ---------------------------------------------------------------
  --- Key Bindings
  ---------------------------------------------------------------
  leader = { key="g", mods="CTRL", timeout_milliseconds=1000 },
  keys = {
    -- Hide
    { key = "T", mods = "CTRL|SHIFT", action = "HideApplication" },

    -- Font Size
    { key = "=", mods = "ALT", action = "ResetFontSize" },
    { key = "+", mods = "ALT|SHIFT", action = "IncreaseFontSize" },
    { key = "-", mods = "ALT", action = "DecreaseFontSize" },

    -- Copy Mode
    { key = " ", mods = "LEADER", action = "ActivateCopyMode" },

    -- Workspace
    -- Switch to the default workspace
    -- {key="d", mods="LEADER|CTRL", action=wezterm.action{SwitchToWorkspace={
    --   name = "default"
    -- }}},
    -- Switch to a monitoring workspace, which will have `top` launched into it
    -- {key="u", mods="LEADER|CTRL", action=wezterm.action{SwitchToWorkspace={
    --   name = "monitoring",
    --   spawn = {
    --     args = {"top"},
    --   }
    -- }}},
    -- Create a new workspace with a random name and switch to it
    {key="s", mods="LEADER|SHIFT", action=wezterm.action{SwitchToWorkspace={}}},
    -- Show the launcher in fuzzy selection mode and have it list all workspaces
    -- and allow activating one.
    {key="s", mods="LEADER|CTRL", action=wezterm.action{ShowLauncherArgs={
      flags="FUZZY|WORKSPACES"
    }}},
    {key="j", mods="LEADER|CTRL", action=wezterm.action{SwitchWorkspaceRelative=-1}},
    {key="k", mods="LEADER|CTRL", action=wezterm.action{SwitchWorkspaceRelative=1}},

    -- Tab
    {key="w", mods = "LEADER|CTRL", action = wezterm.action({ SpawnTab = "CurrentPaneDomain" })},
    {key="h", mods="LEADER|CTRL", action=wezterm.action{ActivateTabRelative=-1}},
    {key="l", mods="LEADER|CTRL", action=wezterm.action{ActivateTabRelative=1}},

    -- Pane
    {key="|", mods="LEADER|SHIFT", action=wezterm.action{SplitHorizontal={domain="CurrentPaneDomain"}}},
    {key="-", mods="LEADER", action=wezterm.action{SplitVertical={domain="CurrentPaneDomain"}}},
    { key = "LeftArrow", mods = "SHIFT|CTRL", action = wezterm.action({ AdjustPaneSize = { "Left", 1 } }) },
    { key = "RightArrow", mods = "SHIFT|CTRL", action = wezterm.action({ AdjustPaneSize = { "Right", 1 } }) },
    { key = "UpArrow", mods = "SHIFT|CTRL", action = wezterm.action({ AdjustPaneSize = { "Up", 1 } }) },
    { key = "DownArrow", mods = "SHIFT|CTRL", action = wezterm.action({ AdjustPaneSize = { "Down", 1 } }) },
    {key="LeftArrow", mods="SHIFT", action=wezterm.action{ActivatePaneDirection="Left"}},
    {key="RightArrow", mods="SHIFT", action=wezterm.action{ActivatePaneDirection="Right"}},
    {key="UpArrow", mods="SHIFT", action=wezterm.action{ActivatePaneDirection="Up"}},
    {key="DownArrow", mods="SHIFT", action=wezterm.action{ActivatePaneDirection="Down"}},
  	{ key = "x", mods = "LEADER|CTRL", action = wezterm.action({ CloseCurrentPane = { confirm = false } }) },
  },
}

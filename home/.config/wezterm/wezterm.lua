local wezterm = require("wezterm")
local functions = require("functions")
local utils = require("utils")
local io = require("io")
local os = require("os")

---------------------------------------------------------------
--- wezterm on
---------------------------------------------------------------
wezterm.on("format-tab-title", functions.format_tab_title)
wezterm.on("update-right-status", functions.update_right_status)
wezterm.on("trigger-open-ghq-project", functions.trigger_open_ghq_project)
wezterm.on("trigget-nvim-with-scrollback", functions.trigger_nvim_with_scrollback)

local win_config = {
  default_prog = { "wsl.exe" },
}

local mac_config = {
  default_prog = { "/usr/local/bin/fish", "-l" },
}

local common_config = {
  font = wezterm.font("HackGenNerd Console"),
  font_size = 14,
  adjust_window_size_when_changing_font_size = false,
  hide_tab_bar_if_only_one_tab = false,
  tab_bar_at_bottom = true,
  use_fancy_tab_bar = false,
  tab_max_width = 32,
  audible_bell = "Disabled",

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
        fg_color = "#1f1f28",
      },
      inactive_tab = {
        bg_color = "#1f1f28",
        fg_color = "#7e9cd8",
      },
    },
  },

  ---------------------------------------------------------------
  --- Key Bindings
  ---------------------------------------------------------------
  leader = { key = "g", mods = "CTRL", timeout_milliseconds = 1000 },
  keys = {
    -- Hide
    { key = "T", mods = "CTRL|SHIFT", action = "HideApplication" },

    -- Font Size
    { key = "=", mods = "ALT", action = "ResetFontSize" },
    { key = "+", mods = "ALT|SHIFT", action = "IncreaseFontSize" },
    { key = "-", mods = "ALT", action = "DecreaseFontSize" },

    -- Copy Mode
    { key = " ", mods = "LEADER", action = "ActivateCopyMode" },

    -- Quick Select
    { key = "Q", mods = "CTRL|SHIFT", action = "QuickSelect" },

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
    { key = "s", mods = "LEADER|SHIFT", action = wezterm.action({ SwitchToWorkspace = {} }) },
    -- Show the launcher in fuzzy selection mode and have it list all workspaces
    -- and allow activating one.
    {
      key = "s",
      mods = "LEADER|CTRL",
      action = wezterm.action({
        ShowLauncherArgs = {
          flags = "FUZZY|WORKSPACES",
        },
      }),
    },
    { key = "j", mods = "SHIFT|CTRL", action = wezterm.action({ SwitchWorkspaceRelative = -1 }) },
    { key = "k", mods = "SHIFT|CTRL", action = wezterm.action({ SwitchWorkspaceRelative = 1 }) },

    -- Tab
    { key = "w", mods = "SHIFT|CTRL", action = wezterm.action({ SpawnTab = "CurrentPaneDomain" }) },
    { key = "h", mods = "SHIFT|CTRL", action = wezterm.action({ ActivateTabRelative = -1 }) },
    { key = "l", mods = "SHIFT|CTRL", action = wezterm.action({ ActivateTabRelative = 1 }) },

    -- Pane
    {
      key = "|",
      mods = "LEADER|SHIFT",
      action = wezterm.action({ SplitHorizontal = { domain = "CurrentPaneDomain" } }),
    },
    { key = "-", mods = "LEADER", action = wezterm.action({ SplitVertical = { domain = "CurrentPaneDomain" } }) },
    { key = "LeftArrow", mods = "SHIFT|CTRL", action = wezterm.action({ AdjustPaneSize = { "Left", 1 } }) },
    { key = "RightArrow", mods = "SHIFT|CTRL", action = wezterm.action({ AdjustPaneSize = { "Right", 1 } }) },
    { key = "UpArrow", mods = "SHIFT|CTRL", action = wezterm.action({ AdjustPaneSize = { "Up", 1 } }) },
    { key = "DownArrow", mods = "SHIFT|CTRL", action = wezterm.action({ AdjustPaneSize = { "Down", 1 } }) },
    { key = "LeftArrow", mods = "SHIFT", action = wezterm.action({ ActivatePaneDirection = "Left" }) },
    { key = "RightArrow", mods = "SHIFT", action = wezterm.action({ ActivatePaneDirection = "Right" }) },
    { key = "UpArrow", mods = "SHIFT", action = wezterm.action({ ActivatePaneDirection = "Up" }) },
    { key = "DownArrow", mods = "SHIFT", action = wezterm.action({ ActivatePaneDirection = "Down" }) },
    { key = "x", mods = "SHIFT|CTRL", action = wezterm.action({ CloseCurrentPane = { confirm = false } }) },
    { key = "z", mods = "SHIFT|CTRL", action = "TogglePaneZoomState" },

    { key = "f", mods = "SHIFT|CTRL", action = wezterm.action({ EmitEvent = "trigger-open-ghq-project" }) },
    { key = "v", mods = "SHIFT|CTRL", action = wezterm.action({ EmitEvent = "trigget-nvim-with-scrollback" }) },
    { key = "n", mods = "SHIFT|CTRL", action = "ToggleFullScreen" },
  },
}

if wezterm.target_triple == "x86_64-pc-windows-msvc" then
  return utils.merge_tables(win_config, common_config)
elseif wezterm.target_triple == "x86_64-apple-darwin" then
  return utils.merge_tables(mac_config, common_config)
else
  return common_config
end

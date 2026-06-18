# Kanagawa Wave inspired tmux style
# Palette: https://github.com/rebelot/kanagawa.nvim

thm_bg="#1F1F28"
thm_fg="#DCD7BA"
thm_dim="#727169"
thm_gray="#54546D"
thm_blue="#7E9CD8"
thm_cyan="#7AA89F"
thm_green="#98BB6C"
thm_yellow="#DCA561"
thm_red="#E46876"
thm_purple="#957FB8"
thm_dark="#16161D"
thm_popup="#2A2A37"

separator="#[fg=${thm_gray},bg=default,nobold]▕#[default]"

# Pane / popup / message
set -g pane-border-style "fg=${thm_gray}"
set -g pane-active-border-style "fg=${thm_blue}"
set -g popup-style "fg=${thm_fg},bg=${thm_popup}"
set -g popup-border-style "fg=${thm_blue}"
set -g message-style "fg=${thm_fg},bg=${thm_popup},align=centre"
set -g message-command-style "fg=${thm_yellow},bg=${thm_popup},align=centre"
set -g mode-style "fg=${thm_dark},bg=${thm_yellow}"

# Status bar
set -g status on
set -g status-position top
set -g status-justify right
set -g status-style "fg=${thm_fg},bg=default"
set -g status-interval 5

set -g status-left-length 100
set -g status-left-style "fg=${thm_fg},bg=default"
set -g status-left "#[fg=${thm_purple}] #S #[default]${separator}#(cd '#{pane_current_path}' 2>/dev/null && branch=$(git branch --show-current 2>/dev/null) && [ -n \"\$branch\" ] && printf ' #[fg=${thm_green}] %s #[default]${separator}' \"\$branch\")"

set -g status-right-length 100
set -g status-right-style "fg=${thm_dim},bg=default"
set -g status-right "#[fg=${thm_cyan}]#h #[default]${separator} #[fg=${thm_yellow}]%H:%M #[default]"

# Windows
setw -g window-status-separator ""
setw -g window-status-style "fg=${thm_dim},bg=default"
setw -g window-status-activity-style "fg=${thm_red},bg=default"
setw -g window-status-current-style "bold,fg=${thm_fg},bg=default"
setw -g window-status-format " #[fg=${thm_dim}]#I:#W #[default]${separator}"
setw -g window-status-current-format " #[fg=${thm_blue},bold]#I:#W #[default]${separator}"

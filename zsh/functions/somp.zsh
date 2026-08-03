function somp() {
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  srt --settings "$config_home/srt/omp.json" -- omp "$@"
}

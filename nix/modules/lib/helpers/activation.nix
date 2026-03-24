_: {
  mkLinkForce = ''
    link_force() {
      local src=$1 dst=$2
      if [ "$(readlink "$dst")" = "$src" ]; then
        return 0
      fi
      $DRY_RUN_CMD rm -rf "$dst"
      $DRY_RUN_CMD ln -sf "$src" "$dst"
    }
  '';
}

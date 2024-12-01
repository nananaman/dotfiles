export def --env openGhqProject [] -> string {
  let project = (ghq list | fzf +m --reverse --prompt='Project > ')
  cd $'(ghq root)/($project)'
}

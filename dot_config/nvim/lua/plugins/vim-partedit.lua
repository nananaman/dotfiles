local function visual_selection_range()
  local cspos = vim.fn.getpos("'<")
  local cepos = vim.fn.getpos("'>")

  local csrow, cscol = cspos[1], cspos[2]
  local cerow, cecol = cepos[1], cepos[2]

  if csrow < cerow or (csrow == cerow and cscol <= cecol) then
    return csrow - 1, cscol - 1, cerow - 1, cecol
  else
    return cerow - 1, cecol - 1, csrow - 1, cscol
  end
end

return {
  "thinca/vim-partedit",
  config = function()
    local function operator_partedit()
      local srow, _, erow, _ = visual_selection_range()
      local filetype = "sql" -- TODO: 推定したい
      vim.fn["partedit#start"]({
        filetype = filetype
      })
    end

    local keymap = vim.keymap.set
    keymap({ "n", "v" }, "<leader>pe", "<cmd>Partedit<CR>")
    -- keymap({ "v" }, "<leader>pe", operator_partedit)
  end
}

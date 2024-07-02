return {
  "tkmpypy/chowcho.nvim",
  config = function()
    local chowcho = require("chowcho")

    chowcho.setup({
      icon_enabled = true,
      exclude = function(buf, win)
        -- exclude noice.nvim's cmdline_popup
        local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
        local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
        if bt == "nofile" and (ft == "noice" or ft == "vim") then
          return true
        end
        return false
      end,
    })

    -- <C-w>xと<C-w><C-x>を同時に設定する
    local win_keymap_set = function(key, callback)
      vim.keymap.set({ "n", "t" }, "<C-w>" .. key, callback)
      vim.keymap.set({ "n", "t" }, "<C-w><C-" .. key .. ">", callback)
    end

    win_keymap_set("w", function()
      local wins = 0

      -- 全ウィンドウをループ
      for i = 1, vim.fn.winnr("$") do
        local win_id = vim.fn.win_getid(i)
        local conf = vim.api.nvim_win_get_config(win_id)

        -- focusableなウィンドウをカウント
        if conf.focusable then
          wins = wins + 1

          -- ウィンドウ数が3以上ならchowchoを起動
          if wins > 2 then
            chowcho.run()
            return
          end
        end
      end

      -- ウィンドウが少なければ標準の<C-w><C-w>を実行
      vim.api.nvim_command("wincmd w")
    end)

    -- ref: https://blog.atusy.net/2022/07/31/chowcho-nvim-any-func/

    win_keymap_set("c", function()
      if vim.fn.winnr("$") <= 1 then
        return
      end
      chowcho.run(vim.api.nvim_win_hide)
    end)

    -- edit selected buffer in current window
    win_keymap_set("e", function()
      if vim.fn.winnr("$") <= 1 then
        return
      end
      chowcho.run(function(n)
        vim.cmd("buffer " .. vim.api.nvim_win_call(n, function()
          return vim.fn.bufnr("%")
        end))
      end)
    end)

    -- swap buffers
    local chowcho_bufnr = function(winid)
      return vim.api.nvim_win_call(winid, function()
        return vim.fn.bufnr("%"), vim.opt_local
      end)
    end
    local chowcho_buffer = function(winid, bufnr, opt_local)
      return vim.api.nvim_win_call(winid, function()
        local old = chowcho_bufnr(0)
        vim.cmd("buffer " .. bufnr)
        vim.opt_local = opt_local
        return old
      end)
    end
    win_keymap_set("x", function()
      chowcho.run(function(n)
        if vim.fn.winnr("$") <= 2 then
          vim.api.nvim_command("wincmd x")
          return
        end

        local current_bufnr, current_opts = chowcho_bufnr(0)
        local selected_bufnr, selected_opts = chowcho_buffer(n, current_bufnr, current_opts)
        chowcho_buffer(0, selected_bufnr, selected_opts)
      end)
    end)
  end,
}

return {
  "CopilotC-Nvim/CopilotChat.nvim",
  branch = "canary",
  dependencies = {
    { "zbirenbaum/copilot.lua" }, -- or github/copilot.vim
    { "nvim-lua/plenary.nvim" }, -- for curl, log wrapper
  },
  opts = {
    debug = false, -- Enable debugging

    model = "gpt-4o-2024-05-13",

    clear_chat_on_new_prompt = true,

    prompts = {
      Explain = {
        prompt = "/COPILOT_EXPLAIN 選択されたコードを説明してください。説明は日本語で書いてください。",
      },
      Review = {
        prompt = "/COPILOT_REVIEW 選択されたコードをレビューしてください。説明は日本語で書いてください。",
        callback = function(response, source)
          -- see config.lua for implementation
        end,
      },
      Fix = {
        prompt = "/COPILOT_GENERATE このコードには問題があります。バグを修正したコードに書き直してください。説明は日本語で書いてください。",
      },
      Optimize = {
        prompt = "/COPILOT_GENERATE 選択されたコードを最適化して、パフォーマンスと可読性を向上させてください。説明は日本語で書いてください。",
      },
      Docs = {
        prompt = "/COPILOT_GENERATE 選択部分にドキュメントコメントを追加してください。説明は日本語で書いてください。",
      },
      Tests = {
        prompt = "/COPILOT_GENERATE 選択したコードの詳細なユニットテストを書いてください。説明は日本語で書いてください。",
      },
      FixDiagnostic = {
        prompt = "コードの診断結果に従って問題を修正してください。説明は日本語で書いてください。",
      },
      Commit = {
        prompt = "コミットメッセージをコミットメッセージ規約に従って書いてください。タイトルは最大50文字、メッセージは72文字で折り返してください。メッセージ全体をgitcommit言語のコードブロックで囲んでください。説明は日本語で書いてください。",
      },
      CommitStaged = {
        prompt = "コミットメッセージをコミットメッセージ規約に従って書いてください。タイトルは最大50文字、メッセージは72文字で折り返してください。メッセージ全体をgitcommit言語のコードブロックで囲んでください。説明は日本語で書いてください。",
      },
    },
  },
  config = function(_, opts)
    local chat = require("CopilotChat")
    local select = require("CopilotChat.select")

    opts.selection = select.unamed

    chat.setup(opts)
    -- Setup the CMP integration
    require("CopilotChat.integrations.cmp").setup()

    vim.api.nvim_create_user_command("CopilotChatVisual", function(args)
      chat.ask(args.args, { selection = select.visual })
    end, { nargs = "*", range = true })

    -- Inline chat with Copilot
    vim.api.nvim_create_user_command("CopilotChatInline", function(args)
      chat.ask(args.args, {
        selection = select.visual,
        window = {
          layout = "float",
          relative = "cursor",
          width = 1,
          height = 0.4,
          row = 1,
        },
      })
    end, { nargs = "*", range = true })

    -- Restore CopilotChatBuffer
    vim.api.nvim_create_user_command("CopilotChatBuffer", function(args)
      chat.ask(args.args, { selection = select.buffer })
    end, { nargs = "*", range = true })

    -- Custom buffer for CopilotChat
    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = "copilot-*",
      callback = function()
        vim.opt_local.relativenumber = true
        vim.opt_local.number = true

        -- Get current filetype and set it to markdown if the current filetype is copilot-chat
        local ft = vim.bo.filetype
        if ft == "copilot-chat" then
          vim.bo.filetype = "markdown"
        end
      end,
    })

    -- Add which-key mappings
    local wk = require("which-key")
    wk.add({
      { "<leader>gm", group = "+Copilot Chat" }, -- group
      { "<leader>gmd", desc = "Show diff" },
      { "<leader>gmp", desc = "System prompt" },
      { "<leader>gms", desc = "Show selection" },
      { "<leader>gmy", desc = "Yank diff" },
    })
  end,
  events = "VeryLazy",
  keys = {
    -- Show help actions with telescope
    {
      "<leader>ah",
      function()
        local actions = require("CopilotChat.actions")
        require("CopilotChat.integrations.telescope").pick(actions.help_actions())
      end,
      desc = "CopilotChat - Help actions",
    },
    -- Show prompts actions with telescope
    {
      "<leader>ap",
      function()
        local actions = require("CopilotChat.actions")
        require("CopilotChat.integrations.telescope").pick(actions.prompt_actions())
      end,
      desc = "CopilotChat - Prompt actions",
    },
    {
      "<leader>ap",
      ":lua require('CopilotChat.integrations.telescope').pick(require('CopilotChat.actions').prompt_actions({selection = require('CopilotChat.select').visual}))<CR>",
      mode = "x",
      desc = "CopilotChat - Prompt actions",
    },
    -- Code related commands
    { "<leader>ae", "<cmd>CopilotChatExplain<cr>", desc = "CopilotChat - Explain code" },
    { "<leader>at", "<cmd>CopilotChatTests<cr>", desc = "CopilotChat - Generate tests" },
    { "<leader>ar", "<cmd>CopilotChatReview<cr>", desc = "CopilotChat - Review code" },
    { "<leader>aR", "<cmd>CopilotChatRefactor<cr>", desc = "CopilotChat - Refactor code" },
    { "<leader>an", "<cmd>CopilotChatBetterNamings<cr>", desc = "CopilotChat - Better Naming" },
    -- Chat with Copilot in visual mode
    {
      "<leader>av",
      ":CopilotChatVisual",
      mode = "x",
      desc = "CopilotChat - Open in vertical split",
    },
    {
      "<leader>ax",
      ":CopilotChatInline<cr>",
      mode = "x",
      desc = "CopilotChat - Inline chat",
    },
    -- Custom input for CopilotChat
    {
      "<leader>ai",
      function()
        local input = vim.fn.input("Ask Copilot: ")
        if input ~= "" then
          vim.cmd("CopilotChat " .. input)
        end
      end,
      desc = "CopilotChat - Ask input",
    },
    -- Generate commit message based on the git diff
    {
      "<leader>am",
      "<cmd>CopilotChatCommit<cr>",
      desc = "CopilotChat - Generate commit message for all changes",
    },
    {
      "<leader>aM",
      "<cmd>CopilotChatCommitStaged<cr>",
      desc = "CopilotChat - Generate commit message for staged changes",
    },
    -- Quick chat with Copilot
    {
      "<leader>aq",
      function()
        local input = vim.fn.input("Quick Chat: ")
        if input ~= "" then
          vim.cmd("CopilotChatBuffer " .. input)
        end
      end,
      desc = "CopilotChat - Quick chat",
    },
    -- Debug
    { "<leader>ad", "<cmd>CopilotChatDebugInfo<cr>", desc = "CopilotChat - Debug Info" },
    -- Fix the issue with diagnostic
    { "<leader>af", "<cmd>CopilotChatFixDiagnostic<cr>", desc = "CopilotChat - Fix Diagnostic" },
    -- Clear buffer and chat history
    { "<leader>al", "<cmd>CopilotChatReset<cr>", desc = "CopilotChat - Clear buffer and chat history" },
    -- Toggle Copilot Chat Vsplit
    { "<leader>av", "<cmd>CopilotChatToggle<cr>", desc = "CopilotChat - Toggle" },
    -- Copilot Chat Models
    { "<leader>a?", "<cmd>CopilotChatModels<cr>", desc = "CopilotChat - Select Models" },
  },
}

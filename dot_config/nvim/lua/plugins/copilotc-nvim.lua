return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    dependencies = {
      { "zbirenbaum/copilot.lua" }, -- or github/copilot.vim
      { "nvim-lua/plenary.nvim" }, -- for curl, log wrapper
    },
    opts = {
      debug = true, -- Enable debugging

      model = "gpt-4o",

      clear_chat_on_new_prompt = true,

      prompts = {
        Explain = {
          prompt = "/COPILOT_EXPLAIN 選択された部分の説明を段落形式で書いてください。",
        },
        Review = {
          prompt = "/COPILOT_REVIEW 選択されたコードをレビューしてください。",
          callback = function(response, source)
            -- see config.lua for implementation
          end,
        },
        Fix = {
          prompt = "/COPILOT_GENERATE このコードには問題があります。バグを修正したコードに書き直してください。",
        },
        Optimize = {
          prompt = "/COPILOT_GENERATE 選択されたコードを最適化して、パフォーマンスと可読性を向上させてください。",
        },
        Docs = {
          prompt = "/COPILOT_GENERATE 選択部分にドキュメントコメントを追加してください。",
        },
        Tests = {
          prompt = "/COPILOT_GENERATE コードのテストを生成してください。",
        },
        FixDiagnostic = {
          prompt = "ファイル内の次の診断問題について支援してください:",
        },
        Commit = {
          prompt = "コミットメッセージをコミットメッセージ規約に従って書いてください。タイトルは最大50文字、メッセージは72文字で折り返してください。メッセージ全体をgitcommit言語のコードブロックで囲んでください。",
        },
        CommitStaged = {
          prompt = "コミットメッセージをコミットメッセージ規約に従って書いてください。タイトルは最大50文字、メッセージは72文字で折り返してください。メッセージ全体をgitcommit言語のコードブロックで囲んでください。",
        },
      },
    },
    -- See Commands section for default commands if you want to lazy load on them
    keys = {
      {
        "<leader>ccq",
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            require("CopilotChat").ask(input, { selection = require("CopilotChat.select").buffer })
          end
        end,
        desc = "CopilotChat - Quick chat",
      },
      {
        "<leader>cch",
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.telescope").pick(actions.help_actions())
        end,
        desc = "CopilotChat - Help actions",
      },
      -- Show prompts actions with telescope
      {
        "<leader>ccp",
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.telescope").pick(actions.prompt_actions())
        end,
        desc = "CopilotChat - Prompt actions",
      },
    },
  },
}

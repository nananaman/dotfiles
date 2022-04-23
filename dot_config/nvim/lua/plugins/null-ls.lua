local nullls = require("null-ls")
nullls.setup({
    sources = {
        nullls.builtins.completion.spell,
        nullls.builtins.formatting.prettier,
    },
})

return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        desc = "Format buffer",
      },
    },
    opts = {
      formatters_by_ft = {
        lua        = { "stylua" },
        python     = { "black", "isort" },
        javascript = { "prettierd", "prettier" },
        typescript = { "prettierd", "prettier" },
        json       = { "prettierd", "prettier" },
        yaml       = { "prettierd", "prettier" },
        markdown   = { "prettierd", "prettier" },
        sh         = { "shfmt" },
        bash       = { "shfmt" },
        c          = { "clang_format" },
        cpp        = { "clang_format" },
        go         = { "gofmt" },
      },
      -- Format on save with 500 ms timeout; falls back to LSP if no formatter found
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },
    },
  },
}

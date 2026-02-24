local M = {}

function M.setup()
  local capabilities = require("cmp_nvim_lsp").default_capabilities()
  local servers = { "pyright", "ts_ls", "bashls", "clangd", "gopls" }

  local on_attach = function(_, bufnr)
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "<leader>dn", vim.diagnostic.goto_next, opts)
    vim.keymap.set("n", "<leader>dp", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
  end

  for _, server in ipairs(servers) do
    vim.lsp.config(server, {
      capabilities = capabilities,
      on_attach = on_attach,
    })
    vim.lsp.enable(server)
  end
end

return M

return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
  {
    "danymat/neogen",
    keys = {
      { "<leader>ng", "<cmd>Neogen<CR>", desc = "Generate annotations" },
    },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      snippet_engine = "luasnip",
    },
  },
}

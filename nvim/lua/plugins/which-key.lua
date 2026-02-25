return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      delay = 500,
      icons = {
        mappings = true,
      },
      spec = {
        -- Group labels for existing keymaps
        { "<leader>h", group = "git hunks" },
        { "<leader>d", group = "diagnostics" },
        { "<leader>f", group = "find (telescope)" },
        { "<leader>r", group = "refactor / rename" },
        { "<leader>t", group = "toggle" },
        { "<leader>c", group = "format / conform" },
      },
    },
  },
}

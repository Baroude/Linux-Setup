return {
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "bash",
        "c",
        "cpp",
        "go",
        "javascript",
        "json",
        "lua",
        "markdown",
        "python",
      },
      highlight = { enable = true },
      indent = { enable = false },
    },
    main = "nvim-treesitter.configs",
  },
}

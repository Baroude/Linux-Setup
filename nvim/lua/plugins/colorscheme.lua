-- Active flavor is written to colorscheme-flavor.lua by scripts/theme-switch.sh.
-- That file is gitignored so the repo never gets dirtied by a theme switch.
local ok, active_flavor = pcall(require, "colorscheme-flavor")
if not ok then
  active_flavor = "mocha"
end

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = active_flavor,
      transparent_background = true,
      integrations = {
        cmp = true,
        native_lsp = { enabled = true },
        nvimtree = true,
        telescope = true,
        treesitter = true,
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },
}

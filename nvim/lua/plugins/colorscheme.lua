-- Active theme is written to colorscheme-flavor.lua by scripts/theme-switch.sh.
-- That file is gitignored so the repo never gets dirtied by a theme switch.
local ok, active = pcall(require, "colorscheme-flavor")
if not ok or type(active) ~= "table" then
  -- Legacy bare string or missing file — fall back to catppuccin/mocha
  local fallback = type(active) == "string" and active or "mocha"
  active = { plugin = "catppuccin", flavor = fallback }
end

local plugin = active.plugin or "catppuccin"
local flavor = active.flavor or "mocha"

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = plugin ~= "catppuccin",
    opts = {
      flavour = flavor,
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
  {
    "rose-pine/neovim",
    name = "rose-pine",
    priority = 1000,
    lazy = plugin ~= "rose-pine",
    opts = {
      variant = flavor,
      dark_variant = "main",
      disable_background = true,
    },
    config = function(_, opts)
      require("rose-pine").setup(opts)
      vim.cmd.colorscheme("rose-pine")
    end,
  },
  {
    "folke/tokyonight.nvim",
    name = "tokyonight",
    priority = 1000,
    lazy = plugin ~= "tokyonight",
    opts = {
      style = flavor,
      transparent = true,
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight-" .. opts.style)
    end,
  },
}

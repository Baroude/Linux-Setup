return {
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFindFile", "NvimTreeRefresh" },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      view = {
        width = 35,
      },
      renderer = {
        group_empty = true,
      },
      update_focused_file = {
        enable = true,
      },
      filters = {
        dotfiles = false,
      },
    },
  },
}

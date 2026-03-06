return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "" },
        topdelete    = { text = "" },
        changedelete = { text = "▎" },
        untracked    = { text = "▎" },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local opts = { buffer = bufnr, silent = true }

        -- Navigate hunks
        vim.keymap.set("n", "]h", gs.next_hunk,         vim.tbl_extend("force", opts, { desc = "Next hunk" }))
        vim.keymap.set("n", "[h", gs.prev_hunk,         vim.tbl_extend("force", opts, { desc = "Prev hunk" }))
        -- Stage / reset
        vim.keymap.set("n", "<leader>hs", gs.stage_hunk,   vim.tbl_extend("force", opts, { desc = "Stage hunk" }))
        vim.keymap.set("n", "<leader>hr", gs.reset_hunk,   vim.tbl_extend("force", opts, { desc = "Reset hunk" }))
        vim.keymap.set("n", "<leader>hS", gs.stage_buffer, vim.tbl_extend("force", opts, { desc = "Stage buffer" }))
        vim.keymap.set("n", "<leader>hu", gs.undo_stage_hunk, vim.tbl_extend("force", opts, { desc = "Undo stage hunk" }))
        -- Preview / blame
        vim.keymap.set("n", "<leader>hp", gs.preview_hunk,           vim.tbl_extend("force", opts, { desc = "Preview hunk" }))
        vim.keymap.set("n", "<leader>hb", gs.blame_line,             vim.tbl_extend("force", opts, { desc = "Blame line" }))
        vim.keymap.set("n", "<leader>hd", gs.diffthis,               vim.tbl_extend("force", opts, { desc = "Diff this" }))
        vim.keymap.set("n", "<leader>tb", gs.toggle_current_line_blame, vim.tbl_extend("force", opts, { desc = "Toggle inline blame" }))
      end,
    },
  },
}

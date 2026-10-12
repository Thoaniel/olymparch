-- Olymparch's small default for Neovim (/etc/xdg/nvim/init.lua). Your own ~/.config/nvim/init.lua replaces it.
local o = vim.opt
o.number = true            -- line numbers
o.mouse = "a"              -- the mouse works
o.clipboard = "unnamedplus" -- yank and paste share the desktop clipboard (with wl-clipboard)
o.expandtab = true         -- spaces, 4 wide
o.shiftwidth = 4
o.tabstop = 4
o.smartindent = true
o.ignorecase = true        -- search ignores case, unless you type a capital
o.smartcase = true
o.undofile = true          -- undo survives closing the file
o.signcolumn = "yes"
o.scrolloff = 5
o.splitright = true
o.splitbelow = true
o.termguicolors = true
o.cursorline = true

vim.g.mapleader = " "
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { desc = "Save" })
vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit" })
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear the search highlight" })

-- Olymparch's gold for the cursor line number and search hits, on whatever colour scheme is in use
vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
        vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#d4a73a", bold = true })
        vim.api.nvim_set_hl(0, "Search", { fg = "#08080c", bg = "#d4a73a" })
    end,
})
vim.cmd.colorscheme("default")

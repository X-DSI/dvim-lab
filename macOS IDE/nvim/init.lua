-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Options
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.wrap = false
vim.opt.scrolloff = 8

-- Load plugins
require("lazy").setup("plugins")

-- nvim-treesitter's `main` branch installs parsers AND their queries into
-- stdpath("data")/site. lazy.nvim rewrites runtimepath at startup; where that
-- path doesn't survive the rewrite, the parsers still load but every query --
-- highlights, folds, indents, injections -- goes silently missing, which reads
-- as "treesitter is installed but nothing is highlighted". Guarded, so it is a
-- no-op wherever the path is already present.
local ts_site = vim.fn.stdpath("data") .. "/site"
if not vim.list_contains(vim.opt.rtp:get(), ts_site) then
  vim.opt.rtp:append(ts_site)
end

-- Keymaps
vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>")
vim.keymap.set("n", "<leader>ff", ":Telescope find_files<CR>")
vim.keymap.set("n", "<leader>fg", ":Telescope live_grep<CR>")
vim.keymap.set("n", "<leader>fb", ":Telescope buffers<CR>")
vim.keymap.set("n", "gh", ":bprev<CR>")
vim.keymap.set("n", "gl", ":bnext<CR>")
vim.keymap.set("n", "<C-x>", ":bdelete<CR>")
vim.keymap.set("n", "<leader>tt", ":ToggleTerm<CR>")

-- Move out of terminal into other windows with Ctrl+h/j/k/l directly
vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-w>h]], { desc = 'Terminal: go left' })
vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-w>j]], { desc = 'Terminal: go down' })
vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-w>k]], { desc = 'Terminal: go up' })
vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-w>l]], { desc = 'Terminal: go right' })

-- And the same in normal mode so it's symmetric everywhere
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Go to left window' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Go to down window' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Go to up window' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Go to right window' })

-- Disable unused providers
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

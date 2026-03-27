--[[
	Minimal config
	==============

	design goals:
		- single file
		- use native nvim features
		- use default keybindings as much as possible
		- prefer built-ins
		- use default colorschemes
		- plugins must be integral to workflow
]]

local vim = vim
local o = vim.opt
o.tabstop = 2
o.shiftwidth = 2
o.softtabstop = 2
o.expandtab = true
o.wrap = false
o.autoread = true
o.list = true
o.signcolumn = "yes"
o.backspace = "indent,eol,start"
o.shell = "/bin/sh"
o.colorcolumn = "100"
o.completeopt = {"menuone", "noselect", "popup"}
o.wildmode = {"lastused", "full"}
o.pumheight = 15
o.laststatus = 0
o.winborder = "rounded"
o.undofile = true
o.ignorecase = true
o.smartcase = true
o.swapfile = false
o.foldmethod = "indent"
o.foldlevelstart = 99
local g = vim.g
g.mapleader = " "
g.maplocalleader = " "

local opts = { silent = true }
local map = vim.keymap.set
map("n", "<leader>sv", ":source $MYVIMRC<cr>")

vim.pack.add({
	"https://github.com/nvim-treesitter/nvim-treesitter.git",
})

vim.cmd("colorscheme default")

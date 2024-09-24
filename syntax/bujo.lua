vim.o.list = false
vim.o.number = false
vim.o.relativenumber = false
vim.api.nvim_set_hl(0, "BujoLine", {})
vim.cmd.syntax("match", "BujoLine", "/^.*$/")
vim.api.nvim_set_hl(0, "BujoBullet", { bold = true, fg = "yellow" })
vim.cmd.syntax("match", "BujoBullet", "/^\\s*[<(]\\?[-+][>)]\\?\\d*/ containedin=BujoLine nextgroup=BujoValue")
vim.api.nvim_set_hl(0, "BujoBulletDone", { bold = true, fg = "green" })
vim.cmd.syntax("match", "BujoBulletDone", "/+/ containedin=BujoBullet contained")
vim.api.nvim_set_hl(0, "BujoValue", { bold = true, fg = "grey" })
vim.cmd.syntax("match", "BujoValue", "/\\s\\+[^{]*/ contained nextgroup=BujoDetails")
vim.cmd.syntax("conceal", "on")
vim.api.nvim_set_hl(0, "BujoDetails", { bold = true, fg = "grey" })
vim.cmd.syntax("match", "BujoDetails", "/\\s*{.*}/ contained")
vim.cmd.syntax("conceal", "off")

local bujo = require("bujo")

vim.api.nvim_buf_create_user_command(0, "BujoCurrentLineSymbol", function()
	print(bujo.get_symbol(vim.api.nvim_get_current_line()))
end, { bang = true })

vim.api.nvim_buf_create_user_command(0, "BujoNextSymbol", function()
	bujo.replace_symbol()
end, { bang = true })

vim.api.nvim_buf_create_user_command(0, "BujoPreviousSymbol", function()
	bujo.replace_symbol(true)
end, { bang = true })

vim.api.nvim_buf_set_keymap(
	0,
	"n",
	bujo.opts.cycle_statuses_keymap,
	":BujoNextSymbol<CR>",
	{ silent = true, noremap = true, desc = "Rotate Bujo symbols" }
)

vim.api.nvim_buf_set_keymap(
	0,
	"n",
	bujo.opts.cycle_back_statuses_keymap,
	":BujoPreviousSymbol<CR>",
	{ silent = true, noremap = true, desc = "Rotate back Bujo symbols" }
)

vim.api.nvim_buf_set_keymap(
	0,
	"n",
	bujo.opts.create_task_inside_keymap,
	":BujoCreateEntry<CR>",
	{ silent = true, noremap = true, desc = "Create Bujo task" }
)

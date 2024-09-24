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
vim.cmd.syntax("match", "BujoDetails", "/{.*}/ contained")
vim.cmd.syntax("conceal", "off")

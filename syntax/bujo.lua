local bujo = require("bujo")

vim.wo.list = false
vim.wo.number = false
vim.wo.relativenumber = false
vim.wo.wrap = false

for _, status in ipairs(bujo.opts.statuses) do
	local color = bujo.opts.default_symbol_color
	local color_table = bujo.opts.symbol_color or {}
	if color_table[status] then
		color = color_table[status]
	end
	vim.api.nvim_set_hl(0, "BujoBullet" .. status, color)
end

vim.api.nvim_set_hl(0, "BujoValue", bujo.opts.default_line_color)
vim.cmd.syntax("match", "BujoValue", "/\\s\\+[^{]*/ contained nextgroup=BujoDetails")

vim.cmd.syntax("match", "BujoLine", "/^.*$/")
for symbol, status in pairs(bujo.sym2st) do
	vim.cmd.syntax(
		"match",
		"BujoBullet" .. status,
		"/^\\s*" .. symbol .. "/ containedin=BujoLine contained nextgroup=BujoValue"
	)
end

local grp = vim.api.nvim_create_augroup("bujo_auto_cmd", { clear = true })
vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = "*.bujo",
	group = grp,
	callback = function()
		local tasks = bujo.tasks_from_buffer_lines()
		for _, task in ipairs(tasks) do
			if task:has_origin() then
				task:origin({ status = "MIGRATED" }):write()
			end
		end
		vim.api.nvim_set_option_value("modified", false, { buf = 0 })
	end,
})

vim.cmd.syntax("conceal", "on")
vim.api.nvim_set_hl(0, "BujoDetails", { bold = false, fg = "grey" })
vim.cmd.syntax("match", "BujoDetails", "/\\s*{.*}/ contained")
vim.cmd.syntax("conceal", "off")

vim.api.nvim_buf_create_user_command(0, "BujoCurrentTask", function()
	print(vim.inspect(bujo.task_from_line(vim.api.nvim_get_current_line())))
end, { bang = true })

vim.api.nvim_buf_create_user_command(0, "BujoFollowOrigin", function()
	bujo.task_from_line(vim.api.nvim_get_current_line()):follow()
end, { bang = true })

vim.api.nvim_buf_create_user_command(0, "BujoNextSymbol", function(args)
	if args.range > 0 then
		for line = args.line1, args.line2 do
			bujo.replace_symbol(false, 0, line - 1)
		end
	else
		bujo.replace_symbol()
	end
end, { bang = true, range = true })

vim.api.nvim_buf_create_user_command(0, "BujoPreviousSymbol", function(args)
	if args.range > 0 then
		for line = args.line1, args.line2 do
			bujo.replace_symbol(true, 0, line - 1)
		end
	else
		bujo.replace_symbol()
	end
end, { bang = true, range = true })

vim.api.nvim_buf_create_user_command(0, "BujoSetSymbol", function(opts)
	if opts.args ~= "" then
		return bujo.set_status(opts.args)
	end
	vim.ui.select(bujo.opts.statuses, {
		prompt = "Chose status/symbol",
		format_item = function(status)
			local symbol = bujo.symbol_from_status(status)
			return symbol .. "\t" .. status
		end,
	}, function(status)
		bujo.set_status(status)
	end)
end, { bang = true, nargs = "?" })

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
	"v",
	bujo.opts.cycle_statuses_keymap,
	":'<,'>BujoNextSymbol<CR>",
	{ silent = true, noremap = true, desc = "Rotate Bujo symbols" }
)

vim.api.nvim_buf_set_keymap(
	0,
	"v",
	bujo.opts.cycle_back_statuses_keymap,
	":'<,'>BujoPreviousSymbol<CR>",
	{ silent = true, noremap = true, desc = "Rotate back Bujo symbols" }
)

vim.api.nvim_buf_set_keymap(
	0,
	"n",
	bujo.opts.create_task_inside_keymap,
	":BujoCreateEntryCurrentBuffer<CR>",
	{ silent = true, noremap = true, desc = "Create Bujo task" }
)

vim.api.nvim_buf_set_keymap(
	0,
	"n",
	bujo.opts.set_status_keymap,
	":BujoSetSymbol<CR>",
	{ silent = true, noremap = true, desc = "Set symbol on current line" }
)

vim.api.nvim_buf_set_keymap(
	0,
	"n",
	bujo.opts.follow_keymap,
	":BujoFollowOrigin<CR>",
	{ silent = true, noremap = true, desc = "Follow task origin" }
)

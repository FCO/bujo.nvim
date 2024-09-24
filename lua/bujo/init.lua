local M = {}

function M.get_symbol(line)
	local _, symbol = string.match(line, M.regex)
	return symbol
end

function M.date_file(days)
	return vim.fn.resolve(
		vim.fn.expand(os.date(M.opts.path .. "/%Y-%m-%d.bujo", os.time() + ((days or 0) * 24 * 60 * 60)))
	)
end

M.symbol_chain = {
	["-"] = "->",
	["->"] = "<-",
	["<-"] = "(-)",
	["(-)"] = "+",
	["+"] = "-",
}

M.reverse_chain = {}
for key, val in pairs(M.symbol_chain) do
	M.reverse_chain[val] = key
end

function M.replace_symbol(reverse)
	local symbol_chain = M.symbol_chain
	if reverse then
		symbol_chain = M.reverse_chain
	end
	local indent, symbol, task = string.match(vim.api.nvim_get_current_line(), M.regex)
	symbol = string.match(symbol, "^%s*(.+)%s*$")
	if symbol == nil or symbol_chain[symbol] == nil then
		return
	end
	symbol = symbol_chain[symbol]
	if string.find(symbol, "[-+]") == 1 then
		symbol = " " .. symbol
	end
	vim.api.nvim_set_current_line(indent .. symbol .. "\t" .. task)
end

M.default_opts = {
	path = "~/bujo",
	default_symbol = "-",
	create_task_keymap = "<leader>bc",
	open_today_keymap = "<leader>bt",
	cycle_statuses_keymap = " ",
	cycle_back_statuses_keymap = "<S- >",
	create_task_inside_keymap = "bc",
}

function M.setup(opts)
	opts = vim.tbl_deep_extend("force", M.default_opts, opts or {})

	M.opts = opts
	M.regex = "^(%s*)([%s<(][-+][>)]?)%s*(.*)$"

	vim.fn.mkdir(vim.fn.expand(M.opts.path), "p")

	vim.api.nvim_set_keymap(
		"n",
		M.opts.create_task_keymap,
		":BujoCreateEntry<CR>",
		{ silent = true, noremap = true, desc = "Create Bujo task" }
	)

	vim.api.nvim_set_keymap(
		"n",
		M.opts.open_today_keymap,
		":BujoOpenTodaysFile<CR>",
		{ silent = true, noremap = true, desc = "Open today's file" }
	)

	vim.api.nvim_create_user_command("BujoOpenTodaysFile", function()
		local curr_date_file = M.date_file()
		vim.cmd.edit(curr_date_file)
	end, { bang = true })

	vim.api.nvim_create_user_command("BujoCreateEntry", function()
		vim.ui.input({ prompt = "entry a new task:" }, function(task)
			if not task then
				return
			end

			local symbol = M.opts.default_symbol
			local match = { string.match(task, M.regex) }
			if #match > 0 then
				task = match[3]
				if match[2] then
					symbol = match[2]
				end
			end
			if string.find(symbol, "^[-+]") == 1 then
				symbol = " " .. symbol
			end

			local meta = {
				created_at = os.date("%H:%M:%S"),
				file = vim.api.nvim_buf_get_name(0),
			}

			local curr_date_file = M.date_file()
			local file = io.open(curr_date_file, "a+")
			if file == nil then
				error("Could not open file")
			end
			file:write(symbol .. "\t" .. task .. "\t" .. vim.json.encode(meta) .. "\n")
			io.close(file)
			if vim.fn.resolve(curr_date_file) == vim.fn.resolve(vim.api.nvim_buf_get_name(0)) then
				if vim.bo.modified then
					vim.notify("Buffer modified, not updating...", "error")
					return
				end
				vim.cmd.edit()
			end
		end)
	end, { bang = true })
end

return M

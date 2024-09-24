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

M.default_opts = {
	path = "~/bujo",
	default_symbol = "-",
	create_task_keymap = "<leader>bc",
	open_today_keymap = "<leader>bt",
	cycle_statuses_keymap = " ",
	cycle_back_statuses_keymap = "<S- >",
	create_task_inside_keymap = "bc",
	symbols = { " - ", " + ", " ->", "<- ", "---", "(-)" },
	statuses = { "TODO", "DONE", "MIGRATED", "DELEGATED", "DELETED", "IDEA" },
}

function M.symbol_from_status(status)
	return M.st2sym[status]
end

function M.status_from_symbol(symbol)
	return M.sym2st[symbol]
end

function M.next_status(status)
	return M.status_chain[status]
end

function M.previous_status(status)
	return M.reverse_chain[status]
end

function M.next_symbol(symbol)
	local status = M.status_from_symbol(symbol)
	local next_status = M.next_status(status)
	return M.symbol_from_status(next_status)
end

function M.previous_symbol(symbol)
	local status = M.status_from_symbol(symbol)
	local next_status = M.previous_status(status)
	return M.symbol_from_status(next_status)
end

function M.format_symbol(symbol)
	local s, e = string.find(symbol, "[-+]+")
	if s == 1 and e == 1 then
		symbol = " " .. symbol
	end
	return symbol
end

function M.replace_symbol(reverse)
	local indent, symbol, task = string.match(vim.api.nvim_get_current_line(), M.regex)
	symbol = string.match(symbol, "^%s*(.+)%s*$")
	if symbol == nil or M.status_chain[M.sym2st[symbol]] == nil then
		return
	end
	if reverse then
		symbol = M.previous_symbol(symbol)
	else
		symbol = M.next_symbol(symbol)
	end

	symbol = M.format_symbol(symbol)

	vim.api.nvim_set_current_line(indent .. symbol .. "\t" .. task)
end

function M.setup(opts)
	opts = vim.tbl_deep_extend("force", M.default_opts, opts or {})

	M.opts = opts

	local statuses = M.opts.statuses
	local symbols = M.opts.symbols
	M.sym2st = {}
	M.st2sym = {}
	for i, status in ipairs(statuses) do
		local sym = string.gsub(string.gsub(symbols[i], "^%s*", ""), "%s*$", "")
		M.sym2st[sym] = status
		M.st2sym[status] = sym
	end

	M.status_chain = {}
	M.reverse_chain = {}
	local prev = statuses[#statuses]
	for _, status in ipairs(statuses) do
		M.status_chain[prev] = status
		M.reverse_chain[status] = prev
		prev = status
	end

	local sym_or = ""
	for _, sym in ipairs(symbols) do
		if sym_or ~= nil then
			sym_or = sym_or .. "|"
		end
		sym_or = sym_or .. sym
	end

	M.regex = "^(%s*)([-%s<(][-+][->)]?)%s*(.*)$"

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

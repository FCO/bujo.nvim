local M = {}

M.default_opts = {
	path = "~/bujo",
	default_symbol = " - ",
	create_task_keymap = "<leader>bc",
	open_today_keymap = "<leader>bt",
	cycle_statuses_keymap = "<Tab>",
	cycle_back_statuses_keymap = "<S-Tab>",
	set_status_keymap = "<Tab><Tab>",
	create_task_inside_keymap = "bc",
	symbols = { " - ", " ÷ ", " + ", " ->", "<- ", "---", "(-)" },
	statuses = { "TODO", "DOING", "DONE", "MIGRATED", "DELEGATED", "DELETED", "IDEA" },
	cycle_over_states = { "TODO", "DOING", "DONE" },
	default_symbol_color = { bold = true, fg = "yellow" },
	default_line_color = { bold = false, fg = "grey" },
	symbol_color = {
		DONE = { bold = true, fg = "green" },
		DELETED = { bold = false, fg = "red" },
	},
}

function M.task_from_line(line)
	local symbol = ""
	local indent = ""

	for _, sym in ipairs(M.opts.symbols) do
		local s = string.find(line, sym, 1, true)
		if s and (s == 1 or string.find(string.sub(line, s - 1), "^%s*$")) then
			symbol = sym
			indent = string.sub(line, 1, s - 1)
			break
		end
	end

	local value = string.match(line, "^([^{]*)", #indent + #symbol + 2)
	if value == nil then
		value = string.sub(line, #indent + #symbol)
	end
	if string.match(value, "%s+$") then
		value = string.gsub(value, "%s+$", "")
	end

	local meta = string.match(line, "({.*})$", #indent + #symbol)

	return M.new_task({
		indent = indent,
		symbol = symbol,
		status = M.status_from_symbol(symbol),
		value = value,
		meta = meta,
	})
end

function M.new_task(pars, new)
	pars = vim.tbl_deep_extend("force", pars, new or {})
	local status = pars.status or M.opts.statuses[1]
	local oldmeta = pars.meta or {
		created_at = os.date("%H:%M:%S"),
	}
	local meta
	if type(oldmeta) == "string" then
		meta = vim.json.decode(oldmeta)
	else
		meta = oldmeta
	end
	return {
		indent = pars.indent or "",
		status = status,
		symbol = M.symbol_from_status(status),
		value = pars.value or "",
		meta = meta,
		tostring = function(self)
			return self.indent .. self.symbol .. "\t" .. self.value .. "\t\t" .. vim.json.encode(self.meta)
		end,
		next = function(self)
			local new_status = M.next_status(self.status)
			meta.changes = meta.changes or {}
			table.insert(meta.changes, { time = os.time(), from = self.status, to = new_status })
			return M.new_task(pars, { status = new_status, meta = meta })
		end,
		previous = function(self)
			local new_status = M.previous_status(self.status)
			meta.changes = meta.changes or {}
			table.insert(meta.changes, { time = os.time(), from = self.status, to = status })
			return M.new_task(pars, { status = new_status, meta = meta })
		end,
		append_to_file = function(self, curr_date_file)
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				local name = vim.api.nvim_buf_get_name(buf)
				if vim.fn.expand(name) == vim.fn.expand(curr_date_file) then
					return vim.api.nvim_buf_set_lines(buf, -1, -1, false, { self:tostring() })
				end
			end
			local file = io.open(curr_date_file, "a+")
			if file == nil then
				error("Could not open file")
			end
			file:write(self:tostring() .. "\n")
			io.close(file)
		end,
		clone = M.new_task,
	}
end

function M.date_file(days)
	return vim.fn.resolve(
		vim.fn.expand(os.date(M.opts.path .. "/%Y-%m-%d.bujo", os.time() + ((days or 0) * 24 * 60 * 60)))
	)
end

function M.symbol_from_status(status)
	return M.st2sym[status]
end

function M.status_from_symbol(symbol)
	return M.sym2st[symbol]
end

function M.next_status(status)
	return M.status_chain[status] or M.opts.statuses[1]
end

function M.previous_status(status)
	return M.reverse_chain[status] or M.opts.statuses[1]
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

function M.replace_symbol(reverse)
	local task = M.task_from_line(vim.api.nvim_get_current_line())
	local new
	if reverse then
		new = task:previous()
	else
		new = task:next()
	end

	vim.api.nvim_set_current_line(new:tostring())
end

function M.set_status(status)
	local task = M.task_from_line(vim.api.nvim_get_current_line())
	local meta = task.meta or {}
	if meta.changes == nil then
		meta.changes = {}
	end
	table.insert(meta.changes, { time = os.time(), from = task.status, to = status })
	local new = task:clone({ status = status, meta = meta })

	vim.api.nvim_set_current_line(new:tostring())
end

function M.setup(opts)
	opts = vim.tbl_deep_extend("force", M.default_opts, opts or {})

	M.opts = opts

	local statuses = M.opts.statuses
	local symbols = M.opts.symbols
	M.sym2st = {}
	M.st2sym = {}
	for i, status in ipairs(statuses) do
		local sym = symbols[i]
		M.sym2st[sym] = status
		M.st2sym[status] = sym
	end

	M.status_chain = {}
	M.reverse_chain = {}
	local cycle_over = M.opts.cycle_over_states
	local prev = cycle_over[#cycle_over]
	for _, status in ipairs(cycle_over) do
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
				vim.notify("No task entred", vim.log.WARN)
				return
			end

			local curr_date_file = M.date_file()
			M.new_task({ value = task }):append_to_file(curr_date_file)
		end)
	end, { bang = true })
end

return M

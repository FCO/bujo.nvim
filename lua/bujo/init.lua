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
	follow_keymap = "bf",
	open_notes_keymap = "bn",
	symbols = { " - ", " ÷ ", " + ", " ->", "<- ", "---", "(-)", " * " },
	statuses = { "TODO", "DOING", "DONE", "MIGRATED", "DELEGATED", "DELETED", "IDEA", "MEETING" },
	cycle_over_states = { "TODO", "DOING", "DONE" },
	default_symbol_color = { bold = true, fg = "yellow" },
	default_line_color = { bold = false, italic = true, fg = "grey" },
	symbol_color = {
		DONE = { bold = true, fg = "green" },
		DELETED = { bold = false, fg = "red" },
	},
}

function M.inbox_files()
	return vim.split(vim.fn.glob(M.opts.path .. "/**/*.bujo"), "\n")
end

function M.tasks_from_buffer_lines(buf, start, _end, file)
	if buf == nil then
		buf = 0
	end
	if start == nil then
		start = 0
	end
	if _end == nil then
		_end = -1
	end
	if file == nil then
		file = vim.api.nvim_buf_get_name(buf)
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local tasks = {}
	for i, line in ipairs(lines) do
		if line ~= nil and line ~= "" then
			table.insert(tasks, M.task_from_line(line, { file = file, line = i - 1 }))
		end
	end
	return tasks
end

function M.prepare_inbox()
	local inbox_file = M.date_file()
	local _, inbox = M.find_or_create_buffer(inbox_file, true, false)
	vim.api.nvim_win_set_buf(0, inbox)
	vim.cmd.edit()
	for _, file in ipairs(M.inbox_files()) do
		if file < inbox_file then
			local newBuf, buf = M.find_or_create_buffer(file)
			vim.api.nvim_buf_call(buf, vim.cmd.edit)
			local tasks = M.tasks_from_buffer_lines(buf, 0, -1, file)
			for _, task in ipairs(tasks) do
				if task.status == "TODO" or task.status == "DOING" then
					local clone = task:clone_with_orig({
						file = inbox_file,
						line = -1,
						line_end = -1,
						buf = inbox,
						silent = true,
					})
					clone:append_to_file()
				end
			end
			if newBuf then
				vim.api.nvim_buf_delete(buf, {})
			end
		end
	end
	vim.api.nvim_set_option_value("modified", false, { buf = 0 })
	vim.o.filetype = "bujo"
end

function M.task_from_buffer_and_line_number(buf, line_number)
	local line = vim.api.nvim_buf_get_lines(buf, line_number, line_number + 1, false)
	local file = vim.api.nvim_buf_get_name(buf)

	return M.task_from_line(line[1], { line = line_number + 1, line_end = line_number + 2, buf = buf, file = file })
end

function M.task_from_line(line, pars)
	pars = pars or {}
	local symbol = ""
	local indent = ""

	if line == nil or line == "" then
		error("Not a task", vim.log.levels.ERROR)
		return nil
	end
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

	local line_number = unpack(vim.api.nvim_win_get_cursor(0))
	local all_pars = vim.tbl_deep_extend("force", {
		line = line_number,
		line_end = line_number + 1,
		indent = indent,
		file = vim.fn.expand("%:p"),
		buf = 0,
		symbol = symbol,
		status = M.status_from_symbol(symbol),
		value = value,
		meta = meta,
	}, pars)
	return M.new_task(all_pars)
end

function M.find_or_create_buffer(file, listed, scrtched)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(buf)
		if vim.fn.expand(name) == vim.fn.expand(file) then
			return false, buf
		end
	end
	local buf = vim.api.nvim_create_buf(listed or false, scrtched or false)
	vim.api.nvim_buf_set_name(buf, file)
	return true, buf
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
	local orig_pars = pars.orig_pars
	local notes = pars.notes
	if orig_pars == nil then
		if meta ~= nil then
			orig_pars = meta.orig_pars
			notes = meta.notes
		end
	end
	if meta then
		meta.orig_pars = nil
	end
	if pars.line and pars.line_end ~= nil then
		if pars.line == -1 then
			pars.line_end = -1
		else
			pars.line_end = pars.line + 1
		end
	end
	local auto_save = false
	if pars.auto_save ~= nil then
		auto_save = pars.auto_save
	end
	local auto_close = false
	if pars.auto_close ~= nil then
		auto_close = pars.auto_close
	end
	if pars.silent == nil then
		pars.silent = true
	end
	return {
		notes = notes or nil,
		silent = pars.silent or false,
		indent = pars.indent or "",
		status = status,
		symbol = M.symbol_from_status(status),
		value = pars.value or "",
		meta = meta,
		buf = pars.buf,
		file = pars.file,
		line = pars.line or -1,
		orig_pars = orig_pars,
		line_end = pars.line_end or -1,
		auto_save = auto_save,
		auto_close = auto_close,
		notes_file = function(self)
			if self.notes then
				return self.notes
			end
			return M.date_file(0, self.value or "meeting")
		end,
		open_notes = function(self)
			local file = self:notes_file()

			local new_buf, buf = M.find_or_create_buffer(file)
			if new_buf then
				self:clone({ notes = file }):write()
			end
			vim.api.nvim_buf_call(buf, vim.cmd.edit)
			vim.api.nvim_win_set_buf(0, buf)
		end,
		tostring = function(self)
			local meta = self.meta
			meta.orig_pars = self.orig_pars
			meta.notes = self.notes
			return self.indent .. self.symbol .. "\t" .. self.value .. "\t\t" .. vim.json.encode(self.meta)
		end,
		next = function(self)
			local _meta = self.meta
			local new_status = M.next_status(self.status)
			if new_status == nil then
				return
			end
			-- _meta.changes = _meta.changes or {}
			-- table.insert(_meta.changes, { time = os.time(), from = self.status, to = new_status })
			return self:clone({ status = new_status, meta = _meta })
		end,
		previous = function(self)
			local _meta = self.meta
			local new_status = M.previous_status(self.status)
			if new_status == nil then
				return
			end
			-- _meta.changes = _meta.changes or {}
			-- table.insert(_meta.changes, { time = os.time(), from = self.status, to = new_status })
			return self:clone({ status = new_status, meta = _meta })
		end,
		buffer_is_opened = function(self)
			if self.buf and vim.api.nvim_buf_is_loaded(self.buf) then
				local name = vim.api.nvim_buf_get_name(self.buf)
				return vim.fn.expand(name) == vim.fn.expand(self.file)
			end
			return false
		end,
		fix_buffer = function(self)
			if self:buffer_is_opened() then
				return self
			end
			return self:create_buffer()
		end,
		create_buffer = function(self)
			local newBuf, buf = M.find_or_create_buffer(self.file)
			if not newBuf then
				return self:clone({ auto_close = false, buf = buf })
			end
			vim.api.nvim_buf_set_name(buf, self.file)
			return self:clone({ buf = buf, auto_save = true, auto_close = true })
		end,
		follow = function(self)
			local orig = self:origin()
			local _, buf = M.find_or_create_buffer(orig.file, true, false)
			vim.api.nvim_win_set_buf(0, buf)
			vim.cmd.edit()
			vim.api.nvim_win_set_cursor(0, { orig.line, 0 })
		end,
		append_to_file = function(self)
			self = self:clone({ line = -1, line_end = -1 })
			return self:write()
		end,
		clone = M.new_task,
		clone_with_orig = function(self, new_pars)
			local o_pars = {}
			for key in pairs(new_pars) do
				o_pars[key] = self[key]
				if key == "line" or key == "line_end" then
					o_pars[key] = o_pars[key] + 1
				end
			end
			new_pars.orig_pars = o_pars
			return self:clone(new_pars)
		end,
		has_origin = function(self)
			return self.orig_pars ~= nil
		end,
		origin = function(self, change)
			local clone = self:clone(self.orig_pars or {})
			clone.orig_pars = nil
			return clone:clone(change)
		end,
		write = function(self)
			local line = self.line
			local line_end = self.line_end
			if line > 0 then
				line = line - 1
			end
			if line_end > 0 then
				line_end = line_end - 1
			end

			self = self:fix_buffer()

			vim.api.nvim_buf_set_lines(self.buf, line, line_end, false, { self:tostring() })
			if not self.silent then
				vim.notify("Written to buffer '" .. self.file .. "'", vim.log.levels.INFO)
			end

			if self.auto_save then
				vim.api.nvim_buf_call(self.buf, function()
					vim.cmd.write({ self.file, bang = true })
				end)
			end
			if self.auto_close then
				vim.api.nvim_buf_delete(self.buf, {})
			end
			return self
		end,
	}
end

function M.date_file(days, complement)
	if complement == nil then
		complement = ""
	else
		complement = "-" .. complement:gsub("%W", "_")
	end
	return vim.fn.resolve(
		vim.fn.expand(
			os.date(M.opts.path .. "/%Y-%m-%d" .. complement .. ".bujo", os.time() + ((days or 0) * 24 * 60 * 60))
		)
	)
end

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

function M.replace_symbol(reverse, buf, line_number)
	local task
	if line_number ~= nil then
		task = M.task_from_buffer_and_line_number(buf, line_number)
	else
		task = M.task_from_line(vim.api.nvim_get_current_line())
	end
	local new
	if reverse then
		new = task:previous()
	else
		new = task:next()
	end

	if new == nil then
		return
	end

	new:write()
end

function M.set_status(status)
	local task = M.task_from_line(vim.api.nvim_get_current_line())
	local meta = task.meta or {}
	-- if meta.changes == nil then
	-- 	meta.changes = {}
	-- end
	-- table.insert(meta.changes, { time = os.time(), from = task.status, to = status })
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
	local prev
	for _, status in ipairs(cycle_over) do
		if prev ~= nil then
			M.status_chain[prev] = status
			M.reverse_chain[status] = prev
		end
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
		":BujoReviewInbox<CR>",
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

			M.new_task({ value = task, file = M.date_file() }):append_to_file()
		end)
	end, { bang = true })

	vim.api.nvim_create_user_command("BujoCreateEntryCurrentBuffer", function()
		vim.ui.input({ prompt = "entry a new task:" }, function(task)
			if not task then
				vim.notify("No task entred", vim.log.WARN)
				return
			end

			M.new_task({ value = task, file = vim.api.nvim_buf_get_name(0) }):append_to_file()
		end)
	end, { bang = true })

	vim.api.nvim_create_user_command("BujoReviewInbox", function()
		M.prepare_inbox()
	end, { bang = true })
end

return M

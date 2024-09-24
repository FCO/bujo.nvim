local M = {}

function curr_date_file(opts)
	return vim.fn.resolve(vim.fn.expand(os.date(opts.path .. "/%Y-%m-%d.bujo")))
end

function M.setup(opts)
	opts = vim.tbl_deep_extend("force", {
		path = "~/bujo",
		default_symbol = "-",
		create_task_keymap = "<leader>bc",
		open_today_keymap = "<leader>bt",
	}, opts or {})

	vim.fn.mkdir(vim.fn.expand(opts.path), "p")

	vim.api.nvim_set_keymap(
		"n",
		opts.create_task_keymap,
		":BujoCreateEntry<CR>",
		{ silent = true, noremap = true, desc = "Create Bujo task" }
	)

	vim.api.nvim_set_keymap(
		"n",
		opts.open_today_keymap,
		":BujoOpenTodaysFile<CR>",
		{ silent = true, noremap = true, desc = "Open today's file" }
	)

	vim.api.nvim_create_user_command("BujoOpenTodaysFile", function()
		local curr_date_file = curr_date_file(opts)
		vim.cmd.edit(curr_date_file)
	end, { bang = true })

	vim.api.nvim_create_user_command("BujoCreateEntry", function()
		vim.ui.input({ prompt = "entry a new task:" }, function(task)
			local regex = "^%s*([<(]?[-+][>)]?)%s*(.*)$"

			local symbol = opts.default_symbol
			local match = { string.find(task, regex) }
			if #match > 0 then
				task = match[4]
				if match[3] then
					symbol = match[3]
				end
			end
			if string.find(symbol, "^[-+]") == 1 then
				symbol = " " .. symbol
			end

			local meta = {
				created_at = os.date("%H:%M:%S"),
				file = vim.api.nvim_buf_get_name(0),
			}

			local curr_date_file = curr_date_file(opts)
			print(curr_date_file .. ": " .. task .. "\n")
			local file = io.open(curr_date_file, "a+")
			if file == nil then
				error("Could not open file")
			end
			file:write(symbol .. "\t" .. task .. " " .. vim.json.encode(meta) .. "\n")
			io.close(file)
		end)
	end, { bang = true })
end

return M

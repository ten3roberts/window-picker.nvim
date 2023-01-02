local api = vim.api
local fn = vim.fn
local o = vim.o

local numbers = {
	["1"] = 1,
	["2"] = 2,
	["3"] = 3,
	["4"] = 4,
	["5"] = 5,
	["6"] = 6,
	["7"] = 7,
	["8"] = 8,
	["9"] = 9,
	["0"] = "$",
}

local shift_numbers = {
	["!"] = 1,
	["@"] = 2,
	["#"] = 3,
	["$"] = 4,
	["%"] = 5,
	["^"] = 6,
	["&"] = 7,
	["*"] = 8,
	["("] = 9,
	[")"] = "$",
}

local defaults = {
	keys = "asdfghjklqwertyuiop",
	swap_shift = true,
	exclude = { qf = true, NvimTree = true, aerial = true },
	flash_duration = 300,
}

local M = {
	config = defaults,
}

function M.setup(config)
	M.config = vim.tbl_extend("force", defaults, config or {})
end

-- Flashes the the cursor line of winid
local function flash_highlight(winid, duration, hl_group)
	if not api.nvim_win_is_valid(winid) then
		return
	end
	if duration == false or duration == 0 then
		return
	end

	if duration == true or duration == 1 then
		duration = 300
	end

	local lnum = api.nvim_win_get_cursor(winid)[1]
	local bufnr = api.nvim_win_get_buf(winid)

	local ns = vim.api.nvim_buf_add_highlight(bufnr, 0, hl_group, lnum - 1, 0, -1)
	local remove_highlight = function()
		if api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
		end
	end

	vim.defer_fn(remove_highlight, duration)
end

---@class SelectOptions
---@field prompt string
---@field hl string
---@field include_cur boolean

---@param callback fun(winid: number|nil, mod: string|nil)
---@param opts SelectOptions
---Annotates and returns the picker window.
local function select(opts, callback)
	local tabpage = api.nvim_get_current_tabpage()
	local win_ids = api.nvim_tabpage_list_wins(tabpage)
	local exclude = M.config.exclude
	local cur_winid = fn.win_getid()

	local hits = 0
	local last_valid = nil
	local candidates = vim.tbl_filter(function(id)
		local bufnr = api.nvim_win_get_buf(id)

		if exclude[api.nvim_buf_get_option(bufnr, "filetype")] == true then
			return false
		end
		if api.nvim_win_get_config(id).relative ~= "" then
			return false
		end

		if id ~= cur_winid or opts.include_cur then
			last_valid = id
			hits = hits + 1
		end

		return true
	end, win_ids)

	if hits == 0 then
		return callback(nil, nil)
	end
	if hits == 1 and last_valid then
		return callback(last_valid, nil)
	end

	-- If there are no candidate windows, return nil
	if #candidates == 0 then
		return callback()
	end
	-- There is only one candidate

	-- Old window statusline
	local old_statuslines = {}

	-- Save old value and force statusline
	local laststatus = o.laststatus
	o.laststatus = 2
	local nums = {}

	-- Setup UI
	local ckeys = M.config.keys
	local key_nums = {}
	local index = 0
	if hits == 1 and last_valid then
		if api.nvim_win_is_valid(last_valid) then
			return callback(last_valid, nil)
		end
	end

	for _, v in ipairs(candidates) do
		local winid = v

		index = index + 1
		if winid ~= cur_winid or opts.include_cur then
			local i = index
			hits = hits + 1
			last_valid = winid
			local key = ckeys:sub(i, i):upper()

			local ok, old_statusline = pcall(api.nvim_win_get_option, winid, "statusline")

			if ok == true then
				old_statuslines[winid] = old_statusline
			end

			nums[i] = winid

			api.nvim_win_set_option(
				winid,
				"statusline",
				string.format("%%#%s#%%=%s%%=", opts.hl or "WindowPicker", key)
			)
			key_nums[key:lower()] = i
		end
	end

	vim.cmd("redraw")

	-- Get next char
	local input = fn.getcharstr()

	-- Restore window statuslines
	for _, v in ipairs(candidates) do
		local winid = v
		if api.nvim_win_is_valid(winid) then
			api.nvim_win_set_option(winid, "statusline", old_statuslines[winid])
		end
	end

	-- Restore laststatus
	o.laststatus = laststatus

	local key = input:sub(#input)

	local num = key_nums[key:lower()] or numbers[key] or shift_numbers[key]
	local winid = nums[num]
	local mod

	local alt = "^\x80\xfc\x08"
	if input:find(alt) then
		mod = "alt"
	elseif key:lower() ~= key then
		mod = "shift"
	end

	if api.nvim_win_is_valid(last_valid) then
		return callback(winid, mod)
	end
end

local function swap_with(stay, winid)
	if not winid then
		return
	end

	local cur_winid = fn.win_getid()

	local cur_bufnr = api.nvim_win_get_buf(cur_winid)
	local target_bufnr = api.nvim_win_get_buf(winid)

	api.nvim_win_set_buf(cur_winid, target_bufnr)
	api.nvim_win_set_buf(winid, cur_bufnr)

	if not stay then
		api.nvim_set_current_win(winid)
	end

	flash_highlight(winid, M.config.flash_duration, "WindowPickerSwap")
end

local function zap_with(winid, force)
	api.nvim_win_close(winid, force)
end

--- Jump to the selected window
--- If shift is held, the window will be swapped
--- If alt is held, the window will be zapped
function M.pick()
	select({ hl = "WindowPicker", prompt = "Pick window: " }, function(winid, mod)
		if not winid then
			return
		end
		if mod == "shift" and M.config.swap_shift then
			return swap_with(false, winid)
		elseif mod == "alt" then
			return zap_with(winid, false)
		else
			api.nvim_set_current_win(winid)
			flash_highlight(winid, M.config.flash_duration, "WindowPicker")
		end
	end)
end

--- Swaps current window with selected
--- @param stay boolean Stay in the window, do not follow the buffer
function M.swap(stay)
	select({ hl = "WindowPickerSwap", prompt = "Swap window: " }, function(w)
		swap_with(stay, w)
	end)
end

--- Closes the selected window
--- If there are only two windows the other window will be closed
--- @param force boolean Force close last window
function M.zap(force)
	force = force or false
	select({ hl = "WindowPickerZap", prompt = "Zap window: ", include_cur = force }, function(winid)
		if not winid then
			return
		end

		zap_with(winid, force)
	end)
end

vim.cmd("hi default WindowPicker     guifg=#ededed guibg=#5e81ac gui=bold")
vim.cmd("hi default WindowPickerSwap guifg=#ededed guibg=#b48ead gui=bold")
vim.cmd("hi default WindowPickerZap  guifg=#ededed guibg=#bf616a gui=bold")

M.select = select

return M

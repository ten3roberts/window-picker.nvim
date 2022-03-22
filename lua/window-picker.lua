local api = vim.api
local fn = vim.fn
local o = vim.o

local shift_numbers = {
  [ '!' ] = 1,
  [ '@' ] = 2,
  [ '#' ] = 3,
  [ '$' ] = 4,
  [ '%' ] = 5,
  [ '^' ] = 6,
  [ '&' ] = 7,
  [ '*' ] = 8,
  [ '(' ] = 9,
  [ ')' ] = '$',
}

local defaults = {
  keys = 'alskdjfhgwoeiruty',
  swap_shift = true,
  exclude = { qf = true, NvimTree = true, aerial = true },
  flash_duration = 300,
}

local M = {
  config = defaults
}

function M.setup(config)
  M.config = vim.tbl_extend('force', defaults, config or {})
end

local function clear_prompt()
  vim.api.nvim_command('normal :esc<CR>')
end

-- Flashes the the cursor line of winid
local function flash_highlight(winid, duration, hl_group)
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
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
  vim.defer_fn(remove_highlight, duration)
end

--- Annotates and returns the picker window.
--- @param callback function
--- @param opts SelectOptions
--- @class SelectOptions
--- @field prompt string
--- @field hl string
--- @field include_cur boolean
local function select(opts, callback)
  local tabpage = api.nvim_get_current_tabpage()
  local win_ids = api.nvim_tabpage_list_wins(tabpage)
  local exclude = M.config.exclude
  local cur_winid = fn.win_getid()

  local candidates = vim.tbl_filter(function (id)
    local bufnr = api.nvim_win_get_buf(id)

    if id == cur_winid and not opts.include_cur then
      return false
    end
    if exclude[api.nvim_buf_get_option(bufnr, 'filetype')] == true then
      return false
    end
    if api.nvim_win_get_config(id).relative ~= '' then
      return false
    end

    return true
  end, win_ids)

  -- If there are no candidate windows, return nil
  if #candidates == 0 then return callback() end
  -- There is only one candidate
  if #candidates == 1 then return callback(candidates[1], false) end

  local keys = M.config.keys

  -- Old window statusline
  local old_statuslines = {}
  local win_keys = {}

  -- Save old value and force statusline
  local laststatus = o.laststatus
  o.laststatus = 2

  -- Setup UI
  for i, winid in ipairs(candidates) do
    local key = keys:sub(i, i):upper()

    local ok, old_statusline = pcall(api.nvim_win_get_option, winid, 'statusline')

    if ok == true then
      old_statuslines[winid] = old_statusline
    end

    win_keys[key] = winid

    api.nvim_win_set_option(winid, 'statusline', string.format("%%#%s#%%=%s%%=", opts.hl or 'WindowPicker', key))

    if i > #keys then break end
  end

  vim.cmd("redraw")
  print(opts.prompt or "Pick window: ")

  -- Get next char
  local input = fn.getchar()

  clear_prompt()

  -- Restore window statuslines
  for _, winid in ipairs(candidates) do
    api.nvim_win_set_option(winid, 'statusline', old_statuslines[winid])
  end

  -- Restore laststatus
  o.laststatus = laststatus


  local key = input

  if type(input) == "number" then
    key = string.char(input)
  end

  -- User entered a number
  if type(input) == "number" and input > 48 and input < 58 then
    return callback(fn.win_getid(input - 48), false)
  elseif shift_numbers[key] then
    return callback(fn.win_getid(shift_numbers[key]), true)
  elseif type(input) == "number" then
    return callback(win_keys[key:upper()], bit.band(input, 100000) == 0)
  end

  callback(nil)
end

local function swap_with(stay, winid)
  if not winid then return end

  local cur_winid = fn.win_getid()

  local cur_bufnr = api.nvim_win_get_buf(cur_winid)
  local target_bufnr = api.nvim_win_get_buf(winid)

  api.nvim_win_set_buf(cur_winid, target_bufnr)
  api.nvim_win_set_buf(winid, cur_bufnr)

  if not stay then
    api.nvim_set_current_win(winid)
  end

  flash_highlight(winid, M.config.flash_duration, 'WindowPickerSwap')
end

local function zap_with(winid, force)
  api.nvim_win_close(winid, force)
end

-- Jumps to `winid`.
function M.pick()
  select({ hl = 'WindowPicker', prompt = 'Pick window: '}, function(winid, upper)
    if not winid then return end
    if upper and M.config.swap_shift then
      return swap_with(false, winid)
    else
      api.nvim_set_current_win(winid)
      flash_highlight(winid, M.config.flash_duration, 'WindowPicker')
    end
  end)
end

--- Swaps current window with selected
--- @param stay boolean Stay in the window, do not follow the buffer
function M.swap(stay)
  select({ hl = 'WindowPickerSwap', prompt = 'Swap window: '}, function(w) swap_with(stay, w) end)
end

--- Closes the selected window
--- If there are only two windows the other window will be closed
--- @param force boolean Force close last window
function M.zap(force)
  force = force or false
  select({ hl = 'WindowPickerZap', prompt = 'Zap window: ', include_cur = force}, function(winid)
    if not winid then return end

    zap_with(winid, force)
  end)
end

vim.cmd 'hi default WindowPicker     guifg=#ededed guibg=#5e81ac gui=bold'
vim.cmd 'hi default WindowPickerSwap guifg=#ededed guibg=#b48ead gui=bold'
vim.cmd 'hi default WindowPickerZap  guifg=#ededed guibg=#bf616a gui=bold'

M.select = select

return M

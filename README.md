# window-picker.nvim

A Neovim plugin for quickly navigating between windows.

## Motivation

Vim's window movement commands work fine when navigating to adjacent windows.
However, they quickly become tedious when navigating further and often causes
you to end up at the wrong split when there are two adjacent ones.

window-picker.nvim allows you to quickly jump to any window by annotating each
window with a letter.

It also allows you to swap the contents of two windows without disturbing your
layout, something which is almost impossible in normal vim.

If a number is given instead of a key, the winnr is used, similar to `<number><C-w><C-w>`

If `swap_shift == true` the windows will be swapped if the shift key is held
when swapping windows.

If there are only two windows, the user wont be prompted as there are no other
windows to select.

## Usage

Configuration is done by passing a table to the setup function. All keys are
optional and will be set to their default value if left out. If you are only
using the default values, `setup` is not necessary.
```lua
require'window-picker'.setup{
  -- Default keys to annotate, keys will be used in order. The default uses the
  -- most accessible keys from the home row and then top row.
  keys = 'alskdjfhgwoeiruty',
  -- Swap windows by holding shift + letter
  swap_shift = true,
  -- Windows containing filetype to exclude
  exclude = { qf = true, NvimTree = true, aerial = true },
  -- Flash the cursor line of the newly focused window for 300ms.
  -- Set to 0 or false to disable.
  flash_duration = 300,
}

-- Example keymaps

-- Move to window, or swap by using shift + letter
vim.api.nvim_set_keymap('n', '<leader>ww', 'require"window-picker".pick()')

-- Swap with any window
vim.api.nvim_set_keymap('n', '<leader>ws', 'require"window-picker".swap()')
```

## Colors
window-picker uses the highlight groups `WindowPicker` and `WindowPickerSwap`.
To customize the colors, simple define these groups yourself with `hi!`

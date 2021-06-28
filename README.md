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

## Usage

Configuration is done by passing a table to the setup function. All keys are
optional and will be set to their default value if left out.
```lua
require'window-picker'.setup{
  -- Default keys to annotate, keys will be used in order. The default uses the
  most accessible keys from the home row and then top row.
  keys = 'alskdjfhgwoeiruty',
  -- Swap windows by holding shift + letter
  swap_shift = true,
}

-- Example keymaps

-- Move to window, or swap by using shift + letter
vim.api.nvim_set_keymap('n', '<leader>ww', 'require"window-picker".pick()')

-- Swap with any window
vim.api.nvim_set_keymap('n', '<leader>ws', 'require"window-picker".swap()')
```



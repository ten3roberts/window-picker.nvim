command! WindowPick     lua require"window-picker".pick()
command! WindowSwap     lua require"window-picker".swap()
command! WindowSwapStay lua require"window-picker".swap(true)


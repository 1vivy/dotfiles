local wezterm = require 'wezterm'
local act = wezterm.action

local config = wezterm.config_builder()

config.font = wezterm.font 'MesloLGS NF'
config.font_size = 12.0
config.window_background_opacity = 0.92

config.scrollback_lines = 50000
config.audible_bell = 'Disabled'
config.window_padding = { left = 8, right = 8, top = 8, bottom = 4 }

-- tmux owns windows/panes, so tmux's status line replaces WezTerm's tab bar.
config.enable_tab_bar = false

-- Attach the shared tmux session, but never nest inside an existing one, and
-- always fall through to a plain shell if tmux is unavailable, so a broken or
-- missing tmux can never leave a window with no shell at all.
config.default_prog = {
  'zsh', '-lc',
  '[ -z "$TMUX" ] && command -v tmux >/dev/null && exec tmux new-session -A -s main; exec zsh -l',
}

-- Shift is the explicit escape hatch that punches through both tmux `mouse on`
-- and the opencode TUI's mouse capture so drag-to-select and click-to-copy keep
-- working inside full-screen terminal apps.
config.bypass_mouse_reporting_modifiers = 'SHIFT'

config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'SHIFT',
    action = act.SelectTextAtMouseCursor 'Cell',
  },
  {
    event = { Drag = { streak = 1, button = 'Left' } },
    mods = 'SHIFT',
    action = act.ExtendSelectionToMouseCursor 'Cell',
  },
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'SHIFT',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'SUPER',
    action = act.OpenLinkAtMouseCursor,
  },
  {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'SUPER',
    action = act.Nop,
  },
}

-- \x02 is C-b, the tmux prefix. Driving tmux by prefix sequence rather than
-- WezTerm actions is what makes splits/tabs survive detach and reattach.
local function tmux(suffix)
  return act.SendString('\x02' .. suffix)
end

-- Each iTerm2 shortcut is bound twice. Toshy modmaps Cmd to RIGHT_CTRL and
-- emits Ctrl+Shift combos, so ctrl is the layer that fires while Toshy runs;
-- super is the fallback for when Toshy is stopped.
local bindings = {
  { super = { 'd', 'SUPER' },          ctrl = { 'd', 'CTRL|SHIFT' },        action = tmux '%' },
  { super = { 'd', 'SUPER|SHIFT' },    ctrl = { 'e', 'CTRL|SHIFT' },        action = tmux '"' },
  { super = { 't', 'SUPER' },          ctrl = { 't', 'CTRL|SHIFT' },        action = tmux 'c' },
  { super = { 'w', 'SUPER' },          ctrl = { 'w', 'CTRL|SHIFT' },        action = tmux 'x' },
  { super = { '[', 'SUPER' },          ctrl = { '[', 'CTRL|SHIFT' },        action = tmux 'O' },
  { super = { ']', 'SUPER' },          ctrl = { ']', 'CTRL|SHIFT' },        action = tmux 'o' },
  { super = { 'PageUp', 'SUPER' },     ctrl = { 'PageUp', 'CTRL|SHIFT' },   action = tmux 'p' },
  { super = { 'PageDown', 'SUPER' },   ctrl = { 'PageDown', 'CTRL|SHIFT' }, action = tmux 'n' },
  { super = { 'Enter', 'SUPER|SHIFT' },ctrl = { 'z', 'CTRL|SHIFT' },        action = tmux 'z' },
  { super = { 'k', 'SUPER' },          ctrl = { 'k', 'CTRL|SHIFT' },        action = tmux 'k' },

  { super = { 'LeftArrow', 'SUPER|ALT' },  ctrl = { 'LeftArrow', 'CTRL|SHIFT' },  action = tmux '\x1b[D' },
  { super = { 'RightArrow', 'SUPER|ALT' }, ctrl = { 'RightArrow', 'CTRL|SHIFT' }, action = tmux '\x1b[C' },
  { super = { 'UpArrow', 'SUPER|ALT' },    ctrl = { 'UpArrow', 'CTRL|SHIFT' },    action = tmux '\x1b[A' },
  { super = { 'DownArrow', 'SUPER|ALT' },  ctrl = { 'DownArrow', 'CTRL|SHIFT' },  action = tmux '\x1b[B' },
}

local keys = {
  { key = 'Enter', mods = 'SUPER', action = act.ToggleFullScreen },
  { key = 'Enter', mods = 'CTRL|SHIFT', action = act.ToggleFullScreen },
  { key = 'n', mods = 'SUPER', action = act.SpawnWindow },
  { key = 'q', mods = 'SUPER', action = act.QuitApplication },
  { key = 'c', mods = 'SUPER', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'SUPER', action = act.PasteFrom 'Clipboard' },

  { key = 'f', mods = 'SUPER', action = act.Search { CaseInSensitiveString = '' } },
  { key = 'g', mods = 'SUPER', action = act.Search 'CurrentSelectionOrEmptyString' },
  { key = 'g', mods = 'CTRL|SHIFT', action = act.Search 'CurrentSelectionOrEmptyString' },

  { key = '=', mods = 'SUPER', action = act.IncreaseFontSize },
  { key = '-', mods = 'SUPER', action = act.DecreaseFontSize },
  { key = '0', mods = 'SUPER', action = act.ResetFontSize },

  { key = 'LeftArrow', mods = 'SUPER', action = act.SendKey { key = 'a', mods = 'CTRL' } },
  { key = 'RightArrow', mods = 'SUPER', action = act.SendKey { key = 'e', mods = 'CTRL' } },
  { key = 'LeftArrow', mods = 'ALT', action = act.SendString '\x1bb' },
  { key = 'RightArrow', mods = 'ALT', action = act.SendString '\x1bf' },
  { key = 'Backspace', mods = 'SUPER', action = act.SendKey { key = 'u', mods = 'CTRL' } },
  { key = 'Backspace', mods = 'ALT', action = act.SendKey { key = 'w', mods = 'CTRL' } },
}

for _, b in ipairs(bindings) do
  table.insert(keys, { key = b.super[1], mods = b.super[2], action = b.action })
  table.insert(keys, { key = b.ctrl[1], mods = b.ctrl[2], action = b.action })
end

for i = 1, 9 do
  local d = tostring(i)
  table.insert(keys, { key = d, mods = 'SUPER', action = tmux(d) })
  table.insert(keys, { key = d, mods = 'CTRL|SHIFT', action = tmux(d) })
end

config.keys = keys

return config

-- Neovim. Deliberately almost empty: the point of learning this editor is the
-- motions, and a pile of plugins at the start teaches the plugins instead.
--
-- The one thing here that is not optional is langmap.

-- Normal-mode commands on the Russian layout.
--
-- Nothing in normal mode is bound to Cyrillic, so with the `ru` group active
-- every command key is silently dead: `h` sends `р`, `:` sends `Ж`, and the
-- editor looks broken while the arrow keys keep working, because those carry
-- no character at all. langmap translates the character back to the command
-- it sits on, so the whole keyboard works in either group without switching.
--
-- It applies to normal, visual and operator-pending mode only. Insert mode is
-- untouched - typing Russian text still types Russian text.
--
-- Read the two halves as one list against the other: every Cyrillic character
-- maps to the Latin one on the same physical key.
vim.opt.langmap = table.concat({
  "ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ",
  "фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz",
  -- Punctuation, pair by pair, because these are the keys that matter most:
  -- Ж is `:` (every command), ю is `.` (repeat), the `/` key types `.` in
  -- this layout (search), and б is `,`. A comma inside langmap has to be
  -- escaped, since it is also the separator between entries.
  -- `;` and `,` are langmap's own separators, so those two entries escape
  -- them; without the backslash nvim reads `ж;` as a list with nothing on the
  -- other side and refuses the whole option.
  "Ж:", [[ж\;]], "Ю>", "ю.", "./", "Б<", [[б\,]],
  "х[", "ъ]", "Х{", "Ъ}", "э'", "Э\"",
}, ",")

-- Minimal comfort, nothing that changes how editing works.
vim.opt.number = true          -- line numbers, so :42 has something to aim at
vim.opt.mouse = "a"            -- the mouse still works while the motions do not
vim.opt.ignorecase = true      -- / searches without caring about case,
vim.opt.smartcase = true       -- unless the pattern itself has a capital
vim.opt.undofile = true        -- undo survives closing the file
vim.opt.termguicolors = true   -- the terminal's own 24-bit palette

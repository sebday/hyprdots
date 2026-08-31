-- App window rules (loaded after Omarchy defaults).
o.window("^(Insync)$", { tag = "+floating-window" })

-- Pop & pin (Super+O): Omarchy defaults to rounded corners for the pop tag.
o.window({ tag = "pop" }, { rounding = 0 })

/* Walker GTK CSS — from colors.toml. No global `* { all: unset }` (breaks ListView). */
@define-color window_bg_color {{ background }};
@define-color accent_bg_color {{ accent }};
@define-color theme_fg_color {{ foreground }};
@define-color error_bg_color {{ color1 }};
@define-color error_fg_color {{ foreground }};

.box-wrapper {
    background: @window_bg_color;
    padding: 24px;
    border: 1px solid darker(@accent_bg_color);
}

.input {
    padding: 8px 24px;
    border-radius: 0;
    margin-bottom: 15px;
}

.item-subtext {
  font-size: 0;
}

.keybind-button {
    font-size: 11px;
    opacity: 0.9;
}

.keybind-button:hover {
    opacity: 0.85;
}

.keybind-bind {
    opacity: 0.35;
    font-size: 10px;
    text-transform: lowercase;
}

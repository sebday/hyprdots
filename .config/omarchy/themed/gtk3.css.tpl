/* Omarchy GTK3 palette — Chromium/Brave/Cursor file choosers and portal-gtk. */
/* @define-color alone does not restyle Adwaita widgets; paint the surfaces too. */

@define-color theme_bg_color {{ background }};
@define-color theme_fg_color {{ foreground }};
@define-color theme_base_color {{ darker_background }};
@define-color theme_text_color {{ foreground }};
@define-color theme_selected_bg_color {{ accent }};
@define-color theme_selected_fg_color {{ background }};
@define-color theme_unfocused_bg_color {{ background }};
@define-color theme_unfocused_fg_color {{ foreground }};
@define-color theme_unfocused_base_color {{ darker_background }};
@define-color theme_unfocused_text_color {{ foreground }};
@define-color theme_unfocused_selected_bg_color {{ selection }};
@define-color theme_unfocused_selected_fg_color {{ foreground }};
@define-color insensitive_bg_color {{ lighter_background }};
@define-color insensitive_fg_color {{ dark_foreground }};
@define-color insensitive_base_color {{ darker_background }};
@define-color borders {{ muted }};
@define-color unfocused_borders {{ muted }};
@define-color warning_color {{ yellow }};
@define-color error_color {{ red }};
@define-color success_color {{ green }};

window, dialog, messagedialog, filechooser, .background {
  background-color: {{ background }};
  color: {{ foreground }};
}

headerbar, .titlebar, .header-bar {
  background-color: {{ lighter_background }};
  background-image: none;
  color: {{ foreground }};
  border-color: {{ muted }};
}

treeview, list, iconview, .view, textview, placessidebar, .sidebar, .navigation-sidebar {
  background-color: {{ darker_background }};
  color: {{ foreground }};
}

entry, spinbutton, searchentry {
  background-color: {{ darker_background }};
  background-image: none;
  color: {{ foreground }};
  border-color: {{ muted }};
}

button, combobox button {
  background-image: none;
  background-color: {{ lighter_background }};
  color: {{ foreground }};
  border-color: {{ muted }};
}

button:hover {
  background-color: {{ muted }};
}

button:checked, button:active, button.suggested-action {
  background-color: {{ accent }};
  color: {{ background }};
}

*:selected, treeview:selected, list row:selected, .view:selected {
  background-color: {{ accent }};
  color: {{ background }};
}

scrollbar slider {
  background-color: {{ muted }};
}

label {
  color: {{ foreground }};
}

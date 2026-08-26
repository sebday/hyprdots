/* Omarchy libadwaita palette — Nautilus, Geary, GNOME Calendar, etc. */
/* No @media wrapper: GTK's user gtk.css provider does not sync prefers-color-scheme on Hyprland. */

@define-color accent_bg_color {{ accent }};
	@define-color accent_fg_color {{ foreground }};

	@define-color destructive_bg_color {{ red }};
	@define-color destructive_fg_color {{ background }};

	@define-color success_bg_color {{ green }};
	@define-color success_fg_color {{ background }};

	@define-color warning_bg_color {{ yellow }};
	@define-color warning_fg_color {{ background }};

	@define-color error_bg_color {{ red }};
	@define-color error_fg_color {{ background }};

	@define-color window_bg_color {{ background }};
	@define-color window_fg_color {{ foreground }};

	@define-color view_bg_color {{ dark_background }};
	@define-color view_fg_color {{ foreground }};

	@define-color headerbar_bg_color {{ lighter_background }};
	@define-color headerbar_fg_color {{ foreground }};
	@define-color headerbar_border_color {{ muted }};
	@define-color headerbar_backdrop_color {{ background }};
	@define-color headerbar_shade_color color-mix(in srgb, {{ foreground }} 12%, transparent);
	@define-color headerbar_darker_shade_color color-mix(in srgb, {{ foreground }} 36%, transparent);

	@define-color sidebar_bg_color {{ lighter_background }};
	@define-color sidebar_fg_color {{ foreground }};
	@define-color sidebar_backdrop_color {{ background }};
	@define-color sidebar_border_color {{ muted }};
	@define-color sidebar_shade_color color-mix(in srgb, {{ foreground }} 12%, transparent);

	@define-color secondary_sidebar_bg_color {{ lighter_background }};
	@define-color secondary_sidebar_fg_color {{ foreground }};
	@define-color secondary_sidebar_backdrop_color {{ background }};
	@define-color secondary_sidebar_border_color {{ muted }};
	@define-color secondary_sidebar_shade_color color-mix(in srgb, {{ foreground }} 12%, transparent);

	@define-color card_bg_color {{ lighter_background }};
	@define-color card_fg_color {{ foreground }};
	@define-color card_shade_color color-mix(in srgb, {{ foreground }} 12%, transparent);

	@define-color dialog_bg_color {{ lighter_background }};
	@define-color dialog_fg_color {{ foreground }};

	@define-color popover_bg_color {{ lighter_background }};
	@define-color popover_fg_color {{ foreground }};
	@define-color popover_shade_color color-mix(in srgb, {{ foreground }} 12%, transparent);

	@define-color thumbnail_bg_color {{ lighter_background }};
	@define-color thumbnail_fg_color {{ foreground }};

	@define-color shade_color color-mix(in srgb, {{ foreground }} 12%, transparent);
	@define-color scrollbar_outline_color color-mix(in srgb, {{ foreground }} 36%, transparent);

	:root {
		--window-bg-color: {{ background }};
		--window-fg-color: {{ foreground }};
		--view-bg-color: {{ dark_background }};
		--view-fg-color: {{ foreground }};
		--headerbar-bg-color: {{ lighter_background }};
		--headerbar-fg-color: {{ foreground }};
		--headerbar-border-color: {{ muted }};
		--headerbar-backdrop-color: {{ background }};
		--headerbar-shade-color: color-mix(in srgb, {{ foreground }} 12%, transparent);
		--headerbar-darker-shade-color: color-mix(in srgb, {{ foreground }} 36%, transparent);
		--sidebar-bg-color: {{ lighter_background }};
		--sidebar-fg-color: {{ foreground }};
		--sidebar-backdrop-color: {{ background }};
		--sidebar-border-color: {{ muted }};
		--sidebar-shade-color: color-mix(in srgb, {{ foreground }} 12%, transparent);
		--secondary-sidebar-bg-color: {{ lighter_background }};
		--secondary-sidebar-fg-color: {{ foreground }};
		--secondary-sidebar-backdrop-color: {{ background }};
		--secondary-sidebar-border-color: {{ muted }};
		--secondary-sidebar-shade-color: color-mix(in srgb, {{ foreground }} 12%, transparent);
		--card-bg-color: {{ lighter_background }};
		--card-fg-color: {{ foreground }};
		--card-shade-color: color-mix(in srgb, {{ foreground }} 12%, transparent);
		--dialog-bg-color: {{ lighter_background }};
		--dialog-fg-color: {{ foreground }};
		--popover-bg-color: {{ lighter_background }};
		--popover-fg-color: {{ foreground }};
		--popover-shade-color: color-mix(in srgb, {{ foreground }} 12%, transparent);
		--thumbnail-bg-color: {{ lighter_background }};
		--thumbnail-fg-color: {{ foreground }};
		--shade-color: color-mix(in srgb, {{ foreground }} 12%, transparent);
		--scrollbar-outline-color: color-mix(in srgb, {{ foreground }} 36%, transparent);
		--accent-bg-color: {{ accent }};
		--accent-fg-color: {{ foreground }};
		--destructive-bg-color: {{ red }};
		--destructive-fg-color: {{ background }};
		--success-bg-color: {{ green }};
		--success-fg-color: {{ background }};
		--warning-bg-color: {{ yellow }};
		--warning-fg-color: {{ background }};
		--error-bg-color: {{ red }};
		--error-fg-color: {{ background }};
}

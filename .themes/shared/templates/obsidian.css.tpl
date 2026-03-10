/* Obsidian CSS generated from colors.toml - overrides shared/obsidian.css (must load last)
   Uses body.theme-dark for higher specificity so we win over Obsidian's built-in body rules
   that remap --background-primary from --color-base-00. */
body.theme-dark,
body.theme-light {
  /* Neutral ramp - Obsidian derives semantic backgrounds from these */
  --color-base-00: {{ background }};
  --color-base-05: {{ color0 }};
  --color-base-10: {{ color0 }};
  --color-base-20: {{ color0 }};
  --color-base-25: {{ color0 }};
  --color-base-30: {{ color8 }};
  /* Semantic backgrounds - reassert so Obsidian's body rule resolves to our palette */
  --background-primary: {{ background }};
  --background-primary-alt: {{ mantle }};
  --background-secondary: var(--background-primary);
  --background-secondary-alt: var(--background-primary-alt);
  --tab-container-background: var(--background-primary);
  --text-normal: {{ foreground }};
  --text-on-accent: {{ background }};
  --text-title-h1: {{ color5 }};
  --text-title-h2: {{ color3 }};
  --text-title-h3: {{ color2 }};
  --text-title-h4: {{ color1 }};
  --text-title-h5: {{ color3 }};
  --text-title-h6: {{ color5 }};
  --text-link: {{ color4 }};
  --text-a: {{ color13 }};
  --text-a-hover: {{ color13 }};
  --interactive-accent: var(--text-title-h3);
  --blockquote-border: {{ color5 }};

  /* Code view */
  --code-normal: var(--text-normal);
  --code-background: var(--background-primary);
  --modular-foreground: var(--text-normal);
  --modular-Comment: {{ accent }};
  --modular-keyword: var(--text-a);
  --modular-definition: var(--text-title-h3);
  --modular-variable: var(--text-normal);
  --modular-number: var(--text-title-h1);
  --modular-function: {{ color6 }};
  --modular-string: var(--text-title-h5);
}

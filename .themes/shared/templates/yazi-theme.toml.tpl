# Yazi theme - generated from colors.toml

[icon]
prepend_conds = [
  { if = "link", text = "󰌵", fg = "{{ color4 }}" },
  { if = "dir", text = "󰉓", fg = "{{ color4 }}" },
]

prepend_dirs = [
  { name = ".config", text = "󰒓", fg = "{{ color4 }}" },
  { name = ".local", text = "󰒓", fg = "{{ color6 }}" },
  { name = ".cache", text = "󰒓", fg = "{{ color2 }}" },
  { name = "downloads", text = "󰉉", fg = "{{ color3 }}" },
  { name = "desktop", text = "󰇄", fg = "{{ color4 }}" },
  { name = "pictures", text = "󰋩", fg = "{{ color3 }}" },
  { name = "videos", text = "󰕧", fg = "{{ color3 }}" },
  { name = "music", text = "󰉓", fg = "{{ color4 }}" },
  { name = "notes", text = "󰉓", fg = "{{ color4 }}" },
  { name = "git", text = "󰊢", fg = "{{ color3 }}" },
  { name = "node_modules", text = "󰎙", fg = "{{ color2 }}" },
]

prepend_exts = [
  { name = "lua", text = "󰠱", fg = "{{ color4 }}" },
  { name = "js", text = "󰌞", fg = "{{ color3 }}" },
  { name = "ts", text = "󰛧", fg = "{{ color4 }}" },
  { name = "sh", text = "󰆍", fg = "{{ color3 }}" },
  { name = "bash", text = "󰆍", fg = "{{ color3 }}" },
  { name = "zsh", text = "󰆍", fg = "{{ color3 }}" },
  { name = "py", text = "󰌠", fg = "{{ color2 }}" },
  { name = "rs", text = "󱘗", fg = "{{ color1 }}" },
  { name = "go", text = "󰟓", fg = "{{ color4 }}" },
  { name = "cpp", text = "󰙲", fg = "{{ color4 }}" },
  { name = "h", text = "󰙱", fg = "{{ color5 }}" },
  { name = "css", text = "󰌜", fg = "{{ color6 }}" },
  { name = "scss", text = "󰌜", fg = "{{ color5 }}" },
  { name = "html", text = "󰌝", fg = "{{ color1 }}" },
  { name = "yaml", text = "󰗀", fg = "{{ color3 }}" },
  { name = "toml", text = "󰓆", fg = "{{ color4 }}" },
  { name = "mp3", text = "󰎈", fg = "{{ color5 }}" },
  { name = "flac", text = "󰎈", fg = "{{ color2 }}" },
  { name = "jpg", text = "󰋩", fg = "{{ color3 }}" },
  { name = "png", text = "󰋩", fg = "{{ color3 }}" },
  { name = "pdf", text = "󰈙", fg = "{{ color1 }}" },
  { name = "zip", text = "󰀼", fg = "{{ color3 }}" },
  { name = "dockerfile", text = "󰡨", fg = "{{ color4 }}" },
  { name = "gitignore", text = "󰊢", fg = "{{ color5 }}" },
  { name = "json", text = "󰘦", fg = "{{ color3 }}" },
  { name = "md", text = "󰍔", fg = "{{ foreground }}" },
  { name = "lock", text = "󰌁", fg = "{{ color3 }}" },
]

prepend_files = [
  { name = ".gitignore", text = "󰊢", fg = "{{ color5 }}" },
  { name = ".bashrc", text = "󰆍", fg = "{{ color3 }}" },
  { name = ".zshrc", text = "󰆍", fg = "{{ color3 }}" },
  { name = "Makefile", text = "󰛕", fg = "{{ color4 }}" },
  { name = "makefile", text = "󰛕", fg = "{{ color4 }}" },
  { name = "Dockerfile", text = "󰡨", fg = "{{ color4 }}" },
  { name = "dockerfile", text = "󰡨", fg = "{{ color4 }}" },
  { name = "LICENSE", text = "󰿃", fg = "{{ color3 }}" },
  { name = "Cargo.toml", text = "󱘗", fg = "{{ color1 }}" },
  { name = "go.mod", text = "󰟓", fg = "{{ color4 }}" },
  { name = "package.json", text = "󰎙", fg = "{{ color3 }}" },
  { name = "package-lock.json", text = "󰎙", fg = "{{ color3 }}" },
  { name = "bun.lock", text = "󰝯", fg = "{{ color3 }}" },
  { name = "bun.lockb", text = "󰝯", fg = "{{ color3 }}" },
  { name = "yarn.lock", text = "󰝯", fg = "{{ color3 }}" },
  { name = "README.md", text = "󰍔", fg = "{{ foreground }}" },
  { name = "readme.md", text = "󰍔", fg = "{{ foreground }}" },
  { name = "install.sh", text = "󰆍", fg = "{{ color3 }}" },
]

[filetype]
rules = [
  { mime = "image/*", fg = "{{ color3 }}" },
  { mime = "video/*", fg = "{{ color3 }}" },
  { mime = "audio/*", fg = "{{ color5 }}" },
  { mime = "application/pdf", fg = "{{ color1 }}" },
]

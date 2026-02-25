export ZSH="$HOME/.oh-my-zsh"

# Starship handles the prompt; no oh-my-zsh theme needed
ZSH_THEME=""

plugins=(git zsh-syntax-highlighting zsh-autosuggestions)

source "$ZSH/oh-my-zsh.sh"

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"

export PATH="$HOME/.local/bin:$PATH"

# Go — only export if Go is actually installed
if [ -d "/usr/local/go/bin" ]; then
  export PATH="$PATH:/usr/local/go/bin"
  export GOPATH="$HOME/.go"
  export PATH="$PATH:$GOPATH/bin"
fi

# ---------------------------------------------------------------------------
# Modern CLI replacements — aliases
# ---------------------------------------------------------------------------

# bat: syntax-highlighted cat (Debian installs as 'batcat')
if command -v batcat &>/dev/null; then
  alias bat="batcat"
fi
if command -v bat &>/dev/null || command -v batcat &>/dev/null; then
  alias cat="bat --paging=never"
  alias less="bat --paging=always"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export BAT_THEME="Catppuccin Mocha"
fi

# eza: modern ls replacement
if command -v eza &>/dev/null; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza --icons --group-directories-first -l --git"
  alias la="eza --icons --group-directories-first -la --git"
  alias lt="eza --icons --tree --level=2"
fi

# fd: fast find (Debian installs as 'fdfind')
if command -v fdfind &>/dev/null; then
  alias fd="fdfind"
fi

# ripgrep: already named 'rg', no alias needed

# ---------------------------------------------------------------------------
# fzf — fuzzy finder
# ---------------------------------------------------------------------------
if command -v fzf &>/dev/null; then
  # Key bindings and completion (installed by apt package)
  [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && \
    source /usr/share/doc/fzf/examples/key-bindings.zsh
  [ -f /usr/share/doc/fzf/examples/completion.zsh ] && \
    source /usr/share/doc/fzf/examples/completion.zsh

  # Use fd for fzf file listing if available
  if command -v fdfind &>/dev/null; then
    export FZF_DEFAULT_COMMAND="fdfind --type f --hidden --follow --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fdfind --type d --hidden --follow --exclude .git"
  elif command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"
  fi

  # Catppuccin Mocha colour scheme for fzf
  export FZF_DEFAULT_OPTS="\
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
    --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
    --color=selected-bg:#45475a \
    --border rounded --prompt '  ' --pointer '' --marker ''"
fi

# ---------------------------------------------------------------------------
# zoxide — smarter cd
# ---------------------------------------------------------------------------
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# ---------------------------------------------------------------------------
# Starship prompt
# ---------------------------------------------------------------------------
eval "$(starship init zsh)"

# ---------------------------------------------------------------------------
# Greeting
# ---------------------------------------------------------------------------
cbonsai -p

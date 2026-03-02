export ZSH="$HOME/.oh-my-zsh"

# Starship handles the prompt — no oh-my-zsh theme needed
ZSH_THEME=""

# --- History ---
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt EXTENDED_HISTORY       # Timestamp each entry
setopt HIST_IGNORE_ALL_DUPS   # No duplicate entries
setopt HIST_REDUCE_BLANKS     # Strip extra blanks
setopt HIST_VERIFY            # Show expanded history before running
setopt SHARE_HISTORY          # Share history across sessions

# --- Misc options ---
setopt EXTENDED_GLOB
setopt CORRECT                # Suggest corrections for typos
setopt AUTO_CD                # cd by typing directory name alone

# --- Plugins ---
plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
  zsh-history-substring-search
)

source "$ZSH/oh-my-zsh.sh"

# --- Completion ---
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'  # Case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"  # Colorized
zstyle ':completion:*' menu select                        # Arrow-key menu

# --- history-substring-search keybindings ---
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# --- fzf · Catppuccin Mocha ---
export FZF_DEFAULT_OPTS=" \
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
  --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
  --color=selected-bg:#45475a \
  --multi"

# --- zoxide (replaces cd) ---
eval "$(zoxide init zsh --cmd cd)"

# --- Starship ---
eval "$(starship init zsh)"

# --- Modern CLI aliases ---
# eza replaces ls (icons require a Nerd Font)
if command -v eza &>/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lh --icons --group-directories-first --git'
  alias la='eza -lah --icons --group-directories-first --git'
  alias lt='eza --tree --icons --level=2'
  alias lta='eza --tree --icons -a --level=2'
fi

# bat replaces cat (Debian ships it as 'batcat')
if command -v batcat &>/dev/null; then
  alias bat='batcat'
  alias cat='batcat --paging=never'
elif command -v bat &>/dev/null; then
  alias cat='bat --paging=never'
fi

# fd replaces find (Debian ships it as 'fdfind')
if command -v fdfind &>/dev/null; then
  alias fd='fdfind'
fi

# btop replaces top/htop
alias top='btop'
alias htop='btop'

# dust replaces du
if command -v dust &>/dev/null; then
  alias du='dust'
fi

# duf replaces df
if command -v duf &>/dev/null; then
  alias df='duf'
fi

# delta: set as git pager (via gitconfig, not alias)

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# --- PATH ---
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:/usr/local/go/bin"
export GOPATH=~/.go
export PATH="$PATH:$GOPATH/bin"

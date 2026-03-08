# ~/.config/starship.toml
# Catppuccin Mocha — Powerline preset
#
# Segments: os+user  directory  git  languages  docker  time  ❯
# All connected with powerline chevron (►) separators.

"$schema" = 'https://starship.rs/config-schema.json'

palette = '${STARSHIP_PALETTE_NAME}'

format = """
[](red)\
$os\
$username\
[](bg:peach fg:red)\
$directory\
[](fg:peach bg:yellow)\
$git_branch\
$git_status\
[](fg:yellow bg:green)\
$c\
$rust\
$golang\
$nodejs\
$php\
$java\
$kotlin\
$haskell\
$python\
[](fg:green bg:sapphire)\
$docker_context\
[](fg:sapphire bg:lavender)\
$time\
[ ](fg:lavender)\
$cmd_duration\
$line_break\
$character"""

# --- OS icon ---
[os]
disabled = false
style = "bg:red fg:crust"

[os.symbols]
Linux   = "󰌽"
Debian  = "󰣚"
Ubuntu  = "󰕈"
Windows = ""
Macos   = "󰀵"
Arch    = "󰣇"
Fedora  = "󰣛"
Manjaro = ""

# --- Username ---
[username]
show_always = true
style_user = "bg:red fg:crust"
style_root = "bg:red fg:crust"
format = '[ $user ]($style)'

# --- Directory ---
[directory]
style = "bg:peach fg:crust"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[directory.substitutions]
"Documents" = "󰈙 "
"Downloads" = " "
"Music"     = "󰝚 "
"Pictures"  = " "

# --- Git ---
[git_branch]
symbol = ""
style = "bg:yellow"
format = '[[ $symbol $branch ](fg:crust bg:yellow)]($style)'

[git_status]
style = "bg:yellow"
format = '[[($all_status$ahead_behind )](fg:crust bg:yellow)]($style)'
up_to_date = ''
modified   = '~${count}'
staged     = '+${count}'
untracked  = '?${count}'
deleted    = '✘${count}'
renamed    = '»${count}'
stashed    = '≡'
ahead      = '⇡${count}'
behind     = '⇣${count}'
diverged   = '⇕⇡${ahead_count}⇣${behind_count}'
conflicted = '⚡${count}'

# --- Languages (green segment, only shown when active) ---
[c]
symbol = " "
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[rust]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[golang]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[nodejs]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[php]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[java]
symbol = " "
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[kotlin]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[haskell]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[python]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version)(\(#$virtualenv\)) ](fg:crust bg:green)]($style)'

# --- Docker (sapphire segment) ---
[docker_context]
symbol = ""
style = "bg:sapphire"
format = '[[ $symbol( $context) ](fg:crust bg:sapphire)]($style)'

# --- Time (lavender segment) ---
[time]
disabled = false
time_format = "%R"
style = "bg:lavender"
format = '[[  $time ](fg:crust bg:lavender)]($style)'

# --- Command duration (after the bar, plain text) ---
[cmd_duration]
disabled = false
min_time = 2000
show_milliseconds = false
format = " took [$duration](bold yellow) "

# --- Prompt character ---
[line_break]
disabled = true

[character]
disabled = false
success_symbol = '[❯](bold fg:green)'
error_symbol   = '[❯](bold fg:red)'
vimcmd_symbol  = '[❮](bold fg:green)'
vimcmd_replace_one_symbol = '[❮](bold fg:lavender)'
vimcmd_replace_symbol     = '[❮](bold fg:lavender)'
vimcmd_visual_symbol      = '[❮](bold fg:yellow)'

# --- ${STARSHIP_PALETTE_NAME} palette ---
[palettes.${STARSHIP_PALETTE_NAME}]
rosewater = '${ROSEWATER}'
flamingo  = '${FLAMINGO}'
pink      = '${PINK}'
mauve     = '${MAUVE}'
red       = '${RED}'
maroon    = '${MAROON}'
peach     = '${PEACH}'
yellow    = '${YELLOW}'
green     = '${GREEN}'
teal      = '${TEAL}'
sky       = '${SKY}'
sapphire  = '${SAPPHIRE}'
blue      = '${BLUE}'
lavender  = '${LAVENDER}'
text      = '${TEXT}'
subtext1  = '${SUBTEXT1}'
subtext0  = '${SUBTEXT0}'
overlay2  = '${OVERLAY2}'
overlay1  = '${OVERLAY1}'
overlay0  = '${OVERLAY0}'
surface2  = '${SURFACE2}'
surface1  = '${SURFACE1}'
surface0  = '${SURFACE0}'
base      = '${BASE}'
mantle    = '${MANTLE}'
crust     = '${CRUST}'

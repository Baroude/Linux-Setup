/* Generated theme for tidal-hifi.
   Selection: ${THEME}/${FLAVOR}/${ACCENT_NAME}
   Load via: Settings -> Theming -> "Choose theme file" */
:root {
  --ctp-base:    ${BASE};
  --ctp-mantle:  ${MANTLE};
  --ctp-crust:   ${CRUST};
  --ctp-surface0:${SURFACE0};
  --ctp-surface1:${SURFACE1};
  --ctp-text:    ${TEXT};
  --ctp-subtext0:${SUBTEXT0};
  --ctp-accent:  ${ACCENT};
  --ctp-peach:   ${PEACH};
  --ctp-green:   ${GREEN};
  --ctp-red:     ${RED};
  --ctp-blue:    ${BLUE};
}

#react-root, body, .nowPlaying, .mainContent, .main-content {
  background-color: var(--ctp-base) !important;
  color: var(--ctp-text) !important;
}

nav, [class*="sidebar"], [class*="NavigationMenu"] {
  background-color: var(--ctp-mantle) !important;
}

[class*="playbackControls"], [class*="footer"], #footerPlayer {
  background-color: var(--ctp-crust) !important;
  border-top: 1px solid var(--ctp-surface0) !important;
}

[class*="progressBar"] [role="progressbar"],
[class*="progressBar"] [class*="bar"] {
  background-color: var(--ctp-accent) !important;
}

button[class*="playButton"], [class*="button--primary"] {
  background-color: var(--ctp-accent) !important;
  color: var(--ctp-base) !important;
}

a, [class*="title"], [class*="trackName"] {
  color: var(--ctp-text) !important;
}

a:hover { color: var(--ctp-accent) !important; }
[class*="isPlaying"], [class*="active"] { color: var(--ctp-accent) !important; }

[class*="card"], [class*="modal"], [class*="dialog"], [class*="dropdown"] {
  background-color: var(--ctp-surface0) !important;
  border: 1px solid var(--ctp-surface1) !important;
}

input, [class*="search"] {
  background-color: var(--ctp-surface0) !important;
  color: var(--ctp-text) !important;
  border-color: var(--ctp-surface1) !important;
}

::-webkit-scrollbar { width: 6px; }
::-webkit-scrollbar-track { background: var(--ctp-mantle); }
::-webkit-scrollbar-thumb { background: var(--ctp-surface1); border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: var(--ctp-accent); }

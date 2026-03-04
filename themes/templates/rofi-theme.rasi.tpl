* {
  bg: ${BASE};
  bg-alt: ${MANTLE};
  fg: ${TEXT};
  fg-muted: ${SUBTEXT0};
  fg-selected: ${CRUST};
  accent: ${ACCENT};
  urgent: ${RED};
  border-color: ${SURFACE1};
  border-radius: 14px;
  spacing: 10px;
}

window {
  width: 42%;
  background-color: @bg;
  border: 2px;
  border-color: @border-color;
  border-radius: @border-radius;
  padding: 14px;
}

mainbox {
  spacing: @spacing;
}

inputbar {
  padding: 10px 12px;
  border: 1px;
  border-color: @border-color;
  border-radius: 10px;
  background-color: @bg-alt;
  text-color: @fg;
}

prompt {
  enabled: true;
  text-color: @accent;
}

entry {
  placeholder: "Search apps";
  placeholder-color: @fg-muted;
  text-color: @fg;
}

listview {
  lines: 8;
  columns: 1;
  fixed-height: false;
  dynamic: true;
  scrollbar: true;
  spacing: 6px;
}

element {
  padding: 8px 10px;
  border-radius: 8px;
  background-color: transparent;
  text-color: @fg;
}

element-icon {
  size: 1em;
}

element selected {
  background-color: @accent;
  text-color: @fg-selected;
}

element-text selected {
  text-color: @fg-selected;
}

message {
  border: 0;
  padding: 2px 4px;
  text-color: @fg-muted;
}

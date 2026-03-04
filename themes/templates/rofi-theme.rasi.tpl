* {
  bg: ${BASE};
  bg-alt: ${MANTLE};
  bg-strong: ${CRUST};
  surface: ${SURFACE0};
  fg: ${TEXT};
  fg-muted: ${SUBTEXT0};
  fg-selected: ${TEXT};
  accent: ${ACCENT};
  urgent: ${RED};
  border-color: ${SURFACE1};
  border-radius: 14px;
  spacing: 8px;
}

window {
  location: center;
  anchor: center;
  width: 42%;
  background-color: @bg;
  border: 2px;
  border-color: @border-color;
  border-radius: @border-radius;
  padding: 14px;
}

mainbox {
  spacing: @spacing;
  background-color: transparent;
}

inputbar {
  children: [ "prompt", "entry" ];
  padding: 10px 12px;
  border: 1px;
  border-color: @border-color;
  border-radius: 10px;
  background-color: @bg-strong;
  text-color: @fg;
}

prompt {
  enabled: true;
  background-color: @accent;
  text-color: @bg;
  padding: 2px 10px;
  border-radius: 999px;
}

entry {
  expand: true;
  background-color: transparent;
  placeholder: "Search apps";
  placeholder-color: @fg-muted;
  text-color: @fg;
  margin: 0 0 0 8px;
}

listview {
  lines: 8;
  columns: 1;
  fixed-height: false;
  dynamic: true;
  scrollbar: true;
  spacing: 6px;
  background-color: transparent;
  padding: 4px 0 0 0;
}

element {
  children: [ "element-icon", "element-text" ];
  padding: 8px 10px;
  border-radius: 8px;
  background-color: transparent;
  text-color: @fg;
}

element-icon {
  size: 1em;
}

element selected {
  background-color: @surface;
  text-color: @fg-selected;
}

element-text selected {
  text-color: @accent;
}

element normal.normal {
  background-color: transparent;
  text-color: @fg;
}

element normal.urgent {
  background-color: @urgent;
  text-color: @bg;
}

element selected.normal {
  background-color: @surface;
  text-color: @fg-selected;
}

element selected.urgent {
  background-color: @urgent;
  text-color: @bg;
}

message {
  border: 1px;
  border-color: @border-color;
  border-radius: 8px;
  padding: 6px 8px;
  background-color: @bg-strong;
  text-color: @fg-muted;
}

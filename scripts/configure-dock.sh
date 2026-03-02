#!/usr/bin/env bash
# configure-dock.sh — Create a floating bottom dock via Plasma JS scripting
# Requires a running Plasma session (qdbus must be available).

set -euo pipefail

qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
// Remove all existing panels (fresh install only has the default bottom panel)
var allPanels = panels();
for (var i = 0; i < allPanels.length; i++) {
    allPanels[i].remove();
}

// Create floating dock at the bottom
var dock = new Panel;
dock.location = 'bottom';
dock.height = 64;
dock.floating = true;
dock.alignment = 'center';
dock.maximumLength = 1200;
dock.minimumLength = 200;

// Icons-only Task Manager — the dock content
dock.addWidget('org.kde.plasma.icontasks');

// System tray
dock.addWidget('org.kde.plasma.systemtray');

// Digital clock
var clock = dock.addWidget('org.kde.plasma.digitalclock');
clock.currentConfigGroup = ['Appearance'];
clock.writeConfig('showDate', 'false');
"

#!/bin/sh
# Plasma session environment variables
# Sourced automatically by plasma-workspace on login
# Path: ~/.config/plasma-workspace/env/envvars.sh

# Qt apps: force Wayland (most already do on Plasma 6)
export QT_QPA_PLATFORM=wayland

# Electron/Chromium on Wayland
export ELECTRON_OZONE_PLATFORM_HINT=auto

# Java AWT fix
export _JAVA_AWT_WM_NONREPARENTING=1

# LibreOffice: Qt6 backend
export SAL_USE_VCLPLUGIN=qt6

# Do NOT set GDK_BACKEND=wayland globally — breaks some GTK apps

#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/theme-common.sh"

theme_apply_firefox_theme() {
  local firefox_method firefox_repo firefox_file_pattern xpi_name firefox_url firefox_tmp firefox_id firefox_installed
  firefox_method="$(theme_context_get "firefox_config.method")"
  firefox_repo="$(theme_context_get "firefox_config.repo")"
  firefox_file_pattern="$(theme_context_get "firefox_config.file_pattern")"

  if [[ "$firefox_method" == "none" || -z "$firefox_method" ]]; then
    theme_info "Firefox theme skipped (method: none)"
    return 0
  fi

  # github_xpi method:
  xpi_name="$firefox_file_pattern"
  firefox_url="https://github.com/${firefox_repo}/releases/download/old/${xpi_name}"
  firefox_installed=0

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] download firefox theme ${firefox_url}"
    echo "[dry-run] parse firefox extension id from ${xpi_name}"
    echo "[dry-run] install firefox theme into /usr/lib/firefox*/distribution/extensions"
    return 0
  fi

  firefox_tmp="$(mktemp --suffix=.xpi)"
  if ! curl -fsSL -o "$firefox_tmp" "$firefox_url"; then
    rm -f "$firefox_tmp"
    theme_warn "Firefox theme archive not found (${xpi_name}); skipped."
    return 0
  fi

  firefox_id="$(python3 - "$firefox_tmp" <<'PY'
import json
import sys
import zipfile

try:
    with zipfile.ZipFile(sys.argv[1]) as zf:
        manifest = json.loads(zf.read("manifest.json").decode("utf-8"))
except Exception:
    print("")
    raise SystemExit(0)

for path in (
    ("browser_specific_settings", "gecko", "id"),
    ("applications", "gecko", "id"),
):
    cur = manifest
    ok = True
    for key in path:
        if not isinstance(cur, dict) or key not in cur:
            ok = False
            break
        cur = cur[key]
    if ok and isinstance(cur, str):
        print(cur)
        break
else:
    print("")
PY
)"

  if [[ -z "$firefox_id" ]]; then
    rm -f "$firefox_tmp"
    theme_warn "Could not read Firefox extension id from ${xpi_name}; skipped."
    return 0
  fi

  for firefox_root in /usr/lib/firefox /usr/lib/firefox-esr; do
    if [[ ! -d "$firefox_root" ]]; then
      continue
    fi
    if sudo mkdir -p "$firefox_root/distribution/extensions" && \
       sudo install -m 0644 "$firefox_tmp" "$firefox_root/distribution/extensions/${firefox_id}.xpi"; then
      firefox_installed=1
    else
      theme_warn "Failed to install Firefox theme in ${firefox_root}; continuing."
    fi
  done

  rm -f "$firefox_tmp"

  if [[ "$firefox_installed" -eq 1 ]]; then
    theme_info "Firefox theme installed (${xpi_name})"
    theme_warn "Manual step: if Firefox keeps the default look, open Add-ons and Themes and enable the installed extension."
  else
    theme_warn "Firefox not found under /usr/lib/firefox or /usr/lib/firefox-esr; skipped theme install."
  fi
}

theme_apply_tidal_desktop_override() {
  local desktop_dir desktop_file vibes_music

  if ! command -v flatpak &>/dev/null; then
    theme_warn "flatpak not found; tidal-hifi desktop override skipped."
    return 0
  fi

  if ! flatpak list --app 2>/dev/null | grep -q "com.mastermindzh.tidal-hifi"; then
    theme_warn "tidal-hifi flatpak not installed; desktop override skipped."
    return 0
  fi

  desktop_dir="$HOME/.local/share/applications"
  desktop_file="${desktop_dir}/com.mastermindzh.tidal-hifi.desktop"
  vibes_music="$HOME/.local/share/icons/catppuccin-vibes/music-vibrant.svg"

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] write ${desktop_file}"
    return 0
  fi

  mkdir -p "$desktop_dir"
  cat > "$desktop_file" <<'EOF'
[Desktop Entry]
Name=TIDAL Hi-Fi
Comment=Tidal music streaming (Catppuccin)
Exec=flatpak run com.mastermindzh.tidal-hifi -- --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations,WaylandLinuxDmabuf --enable-wayland-ime
Icon=com.mastermindzh.tidal-hifi
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Music;Player;
StartupWMClass=tidal-hifi
EOF

  if [[ -f "$vibes_music" ]]; then
    sed -i "s|^Icon=.*|Icon=$vibes_music|" "$desktop_file"
  fi

  theme_info "tidal-hifi .desktop override written (Wayland flags)"
}

theme_apply_tidal_css_theme() {
  local flavor accent theme_dir variant_css stable_css
  flavor="$(theme_context_get "flavor")"
  accent="$(theme_context_get "accent")"
  theme_dir="$HOME/.config/tidal-hifi"
  variant_css="${theme_dir}/catppuccin-${flavor}-${accent}.css"
  stable_css="${theme_dir}/catppuccin.css"

  theme_render_template "${THEME_REPO_DIR}/themes/templates/tidal-hifi.css.tpl" "$variant_css"
  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] copy ${variant_css} -> ${stable_css}"
  else
    cp "$variant_css" "$stable_css"
  fi

  theme_info "TIDAL CSS theme written: ${variant_css}"
  theme_warn "Manual step: Open tidal-hifi -> Settings -> Theming -> choose ${stable_css}"
}

theme_apply_rofi_theme() {
  local rofi_dir rofi_config rofi_layout_dir rofi_layout_shared rofi_colors_dir
  local rofi_style rofi_shared_colors rofi_shared_fonts rofi_catppuccin
  rofi_dir="$HOME/.config/rofi"
  rofi_config="${rofi_dir}/config.rasi"
  rofi_layout_dir="${rofi_dir}/launchers/type-2"
  rofi_layout_shared="${rofi_layout_dir}/shared"
  rofi_colors_dir="${rofi_dir}/colors"
  rofi_style="${rofi_layout_dir}/style-9.rasi"
  rofi_shared_colors="${rofi_layout_shared}/colors.rasi"
  rofi_shared_fonts="${rofi_layout_shared}/fonts.rasi"
  rofi_catppuccin="${rofi_colors_dir}/catppuccin.rasi"

  theme_run "create rofi config dir" mkdir -p "$rofi_dir"
  theme_run "create rofi layout dirs" mkdir -p "$rofi_layout_shared" "$rofi_colors_dir"

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] download adi1090x launcher style ${rofi_style}"
    echo "[dry-run] download adi1090x shared colors ${rofi_shared_colors}"
    echo "[dry-run] download adi1090x shared fonts ${rofi_shared_fonts}"
    echo "[dry-run] download adi1090x catppuccin colors ${rofi_catppuccin}"
    echo "[dry-run] force ${rofi_shared_colors} to import ~/.config/rofi/colors/catppuccin.rasi"
  else
    curl -fsSL -o "$rofi_style" \
      "https://raw.githubusercontent.com/adi1090x/rofi/master/files/launchers/type-2/style-9.rasi"
    curl -fsSL -o "$rofi_shared_colors" \
      "https://raw.githubusercontent.com/adi1090x/rofi/master/files/launchers/type-2/shared/colors.rasi"
    curl -fsSL -o "$rofi_shared_fonts" \
      "https://raw.githubusercontent.com/adi1090x/rofi/master/files/launchers/type-2/shared/fonts.rasi"
    curl -fsSL -o "$rofi_catppuccin" \
      "https://raw.githubusercontent.com/adi1090x/rofi/master/files/colors/catppuccin.rasi"

    sed -i -E \
      's|^@import "~/.config/rofi/colors/[A-Za-z0-9_-]+\.rasi"|@import "~/.config/rofi/colors/catppuccin.rasi"|' \
      "$rofi_shared_colors"
  fi

  theme_render_template "${THEME_REPO_DIR}/themes/templates/rofi-config.rasi.tpl" "$rofi_config"

  theme_info "Rofi launcher theme set to adi1090x type-2/style-9 (catppuccin preset)"
}

theme_apply_apps_adapter() {
  theme_apply_firefox_theme
  theme_apply_tidal_desktop_override
  theme_apply_tidal_css_theme
  theme_apply_rofi_theme
  theme_info "Apps adapter completed"
}

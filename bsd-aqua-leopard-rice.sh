#!/bin/sh
# bsd-aqua-leopard-rice.sh
#
# Better Mac OS X 2000s-ish X11 setup for FreeBSD + Openbox.
#
# Uses real community themes:
#   - B00merang OS-X-Leopard GTK theme
#   - B00merang macOS theme for Openbox decorations/fallback GTK
#   - La Capitaine icon theme
#   - picom shadows/fades
#   - tint2 fake dock
#
# Usage as root:
#   sh bsd-aqua-leopard-rice.sh USER [leopard|graphite|modern]
#
# Example:
#   sh bsd-aqua-leopard-rice.sh w3r leopard
#
# Then login as USER:
#   startx

set -eu

die() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

warn() {
  echo "WARN: $*" >&2
}

[ "$(id -u)" -eq 0 ] || die "Run as root."
[ "$(uname -s)" = "FreeBSD" ] || die "This script is for FreeBSD."

USER_NAME="${1:-}"
PROFILE="${2:-leopard}"

[ -n "$USER_NAME" ] || die "Usage: sh $0 USER [leopard|graphite|modern]"
id "$USER_NAME" >/dev/null 2>&1 || die "User '$USER_NAME' does not exist."

USER_HOME="$(pw usershow "$USER_NAME" | awk -F: '{print $9}')"
[ -n "$USER_HOME" ] || die "Could not determine home directory."
[ -d "$USER_HOME" ] || die "Home directory does not exist: $USER_HOME"

case "$PROFILE" in
  leopard)
    GTK_THEME="OS-X-Leopard"
    OB_THEME="macOS"
    WALL_TOP="14 68 145"
    WALL_MID="90 170 240"
    WALL_BOT="222 244 255"
    PANEL_BG="#ecf5ff"
    PANEL_BORDER="#a4c8e8"
    ACCENT="#2f8edb"
    TERM_BG="#f7fbff"
    TERM_FG="#10243d"
    ;;
  graphite)
    GTK_THEME="OS-X-Leopard"
    OB_THEME="macOS"
    WALL_TOP="52 60 72"
    WALL_MID="150 164 180"
    WALL_BOT="238 240 244"
    PANEL_BG="#f4f4f4"
    PANEL_BORDER="#b9c0c8"
    ACCENT="#73808d"
    TERM_BG="#fbfbfd"
    TERM_FG="#1d2430"
    ;;
  modern)
    GTK_THEME="macOS"
    OB_THEME="macOS"
    WALL_TOP="44 97 190"
    WALL_MID="133 198 255"
    WALL_BOT="246 252 255"
    PANEL_BG="#f8fbff"
    PANEL_BORDER="#c8dff4"
    ACCENT="#2684d9"
    TERM_BG="#f9fcff"
    TERM_FG="#10243d"
    ;;
  *)
    die "Unknown profile '$PROFILE'. Use: leopard, graphite, modern"
    ;;
esac

ICON_THEME="la-capitaine-icon-theme"
TS="$(date +%Y%m%d-%H%M%S)"

install_pkg() {
  PKG="$1"
  if pkg info -e "$PKG" >/dev/null 2>&1; then
    return 0
  fi
  info "Installing package: $PKG"
  pkg install -y "$PKG" || warn "Could not install package '$PKG'; continuing."
}

backup_path() {
  P="$1"
  if [ -e "$P" ]; then
    cp -Rp "$P" "$P.backup.$TS"
    info "Backup: $P.backup.$TS"
  fi
}

clone_repo() {
  REPO="$1"
  DEST="$2"
  BRANCH="${3:-master}"

  rm -rf "$DEST"

  info "Cloning $REPO -> $DEST"
  if ! git clone --depth 1 --branch "$BRANCH" "https://github.com/$REPO.git" "$DEST"; then
    warn "git clone failed for $REPO branch $BRANCH. Trying default branch..."
    git clone --depth 1 "https://github.com/$REPO.git" "$DEST" || return 1
  fi
}

copy_dir_clean() {
  SRC="$1"
  DST="$2"
  [ -d "$SRC" ] || die "Source directory missing: $SRC"
  rm -rf "$DST"
  mkdir -p "$(dirname "$DST")"
  cp -Rp "$SRC" "$DST"
}

info "Bootstrapping pkg if needed..."
env ASSUME_ALWAYS_YES=yes pkg bootstrap -f >/dev/null 2>&1 || true

info "Updating package metadata..."
pkg update || warn "pkg update failed; continuing with current package metadata."

info "Installing packages..."
install_pkg ca_root_nss
install_pkg git
install_pkg openbox
install_pkg obconf
install_pkg lxappearance
install_pkg xterm
install_pkg picom
install_pkg tint2
install_pkg feh
install_pkg pcmanfm
install_pkg dbus
install_pkg dejavu
install_pkg webfonts
install_pkg hicolor-icon-theme
install_pkg adwaita-icon-theme
install_pkg gtk-murrine-engine
install_pkg gtk-engines2

# Help git with TLS certificates on minimal systems.
if [ -f /usr/local/share/certs/ca-root-nss.crt ]; then
  git config --system http.sslCAInfo /usr/local/share/certs/ca-root-nss.crt >/dev/null 2>&1 || true
fi

info "Creating desktop directories..."
mkdir -p \
  "$USER_HOME/.themes" \
  "$USER_HOME/.icons" \
  "$USER_HOME/.config/openbox" \
  "$USER_HOME/.config/picom" \
  "$USER_HOME/.config/tint2" \
  "$USER_HOME/.config/gtk-3.0" \
  "$USER_HOME/.config/fontconfig" \
  "$USER_HOME/Pictures"

backup_path "$USER_HOME/.themes/OS-X-Leopard"
backup_path "$USER_HOME/.themes/macOS"
backup_path "$USER_HOME/.icons/$ICON_THEME"
backup_path "$USER_HOME/.config/openbox"
backup_path "$USER_HOME/.config/picom"
backup_path "$USER_HOME/.config/tint2"
backup_path "$USER_HOME/.gtkrc-2.0"
backup_path "$USER_HOME/.config/gtk-3.0/settings.ini"
backup_path "$USER_HOME/.Xresources"
backup_path "$USER_HOME/.xinitrc"

TMP="/tmp/bsd-aqua-rice.$$"
rm -rf "$TMP"
mkdir -p "$TMP"

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

info "Downloading real themes from GitHub..."
clone_repo "B00merang-Project/OS-X-Leopard" "$TMP/OS-X-Leopard" "master" || die "Could not download OS-X-Leopard theme."
clone_repo "B00merang-Project/macOS" "$TMP/macOS" "master" || die "Could not download macOS theme."
clone_repo "keeferrourke/la-capitaine-icon-theme" "$TMP/la-capitaine-icon-theme" "master" || die "Could not download La Capitaine icons."

info "Installing themes into $USER_HOME..."
copy_dir_clean "$TMP/OS-X-Leopard" "$USER_HOME/.themes/OS-X-Leopard"
copy_dir_clean "$TMP/macOS" "$USER_HOME/.themes/macOS"
copy_dir_clean "$TMP/la-capitaine-icon-theme" "$USER_HOME/.icons/$ICON_THEME"

# Openbox theme fallback check.
if [ ! -d "$USER_HOME/.themes/$OB_THEME/openbox-3" ]; then
  warn "Openbox theme '$OB_THEME' lacks openbox-3; falling back to Clearlooks."
  OB_THEME="Clearlooks"
fi

info "Generating Aqua/Leopard-like wallpaper..."
WALL="$USER_HOME/Pictures/bsd-aqua-${PROFILE}.ppm"
set -- $WALL_TOP; R1="$1"; G1="$2"; B1="$3"
set -- $WALL_MID; R2="$1"; G2="$2"; B2="$3"
set -- $WALL_BOT; R3="$1"; G3="$2"; B3="$3"

awk -v w=1440 -v h=900 \
    -v r1="$R1" -v g1="$G1" -v b1="$B1" \
    -v r2="$R2" -v g2="$G2" -v b2="$B2" \
    -v r3="$R3" -v g3="$G3" -v b3="$B3" '
function clamp(v) { if (v < 0) return 0; if (v > 255) return 255; return int(v); }
BEGIN {
  print "P3";
  print w " " h;
  print "255";

  for (y = 0; y < h; y++) {
    t = y / (h - 1);

    if (t < 0.58) {
      u = t / 0.58;
      r = r1 * (1-u) + r2 * u;
      g = g1 * (1-u) + g2 * u;
      b = b1 * (1-u) + b2 * u;
    } else {
      u = (t - 0.58) / 0.42;
      r = r2 * (1-u) + r3 * u;
      g = g2 * (1-u) + g3 * u;
      b = b2 * (1-u) + b3 * u;
    }

    # Leopard-ish glossy horizontal glow.
    band1 = exp(-((t - 0.27) * (t - 0.27)) / 0.003) * 70;
    band2 = exp(-((t - 0.48) * (t - 0.48)) / 0.008) * 26;

    for (x = 0; x < w; x++) {
      sx = x / (w - 1);
      dx = sx - 0.72;
      dy = t - 0.18;
      radial = exp(-(dx*dx + dy*dy) / 0.030) * 48;

      wave = sin((sx * 8.0 + t * 3.0)) * 4 + sin((sx * 18.0 - t * 2.0)) * 2;

      rr = clamp(r + band1 + band2 + radial + wave);
      gg = clamp(g + band1 + band2 + radial + wave);
      bb = clamp(b + band1 + band2 + radial + wave + 8);

      printf "%d %d %d ", rr, gg, bb;
    }
    printf "\n";
  }
}' > "$WALL"

info "Writing GTK settings..."
cat > "$USER_HOME/.gtkrc-2.0" <<EOF
gtk-theme-name="$GTK_THEME"
gtk-icon-theme-name="$ICON_THEME"
gtk-font-name="DejaVu Sans 10"
gtk-cursor-theme-name="Adwaita"
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-menu-images=1
gtk-button-images=1
EOF

cat > "$USER_HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=$ICON_THEME
gtk-font-name=DejaVu Sans 10
gtk-cursor-theme-name=Adwaita
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-menu-images=1
gtk-button-images=1
gtk-application-prefer-dark-theme=false
EOF

info "Writing fontconfig..."
cat > "$USER_HOME/.config/fontconfig/fonts.conf" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
  </match>
</fontconfig>
EOF

info "Writing Xresources..."
cat > "$USER_HOME/.Xresources" <<EOF
Xft.dpi: 96
Xft.antialias: true
Xft.hinting: true
Xft.hintstyle: hintslight
Xft.rgba: rgb

XTerm*faceName: DejaVu Sans Mono
XTerm*faceSize: 11
XTerm*utf8: 1
XTerm*saveLines: 8192
XTerm*scrollBar: false
XTerm*rightScrollBar: false
XTerm*background: $TERM_BG
XTerm*foreground: $TERM_FG
XTerm*cursorColor: $ACCENT
XTerm*pointerColor: $ACCENT
XTerm*color0: #1c2430
XTerm*color1: #ba2f36
XTerm*color2: #2f8a45
XTerm*color3: #b57900
XTerm*color4: $ACCENT
XTerm*color5: #8a4dbf
XTerm*color6: #008c9e
XTerm*color7: #eef6ff
XTerm*color8: #667383
XTerm*color9: #ff5c63
XTerm*color10: #66cf76
XTerm*color11: #ffd36a
XTerm*color12: #74b9ff
XTerm*color13: #c49cff
XTerm*color14: #63d8e8
XTerm*color15: #ffffff
EOF

info "Writing picom config..."
cat > "$USER_HOME/.config/picom/picom.conf" <<'EOF'
backend = "xrender";
vsync = false;

shadow = true;
shadow-radius = 24;
shadow-offset-x = -9;
shadow-offset-y = 9;
shadow-opacity = 0.42;

fading = true;
fade-in-step = 0.045;
fade-out-step = 0.045;
fade-delta = 8;

inactive-opacity = 0.975;
active-opacity = 1.0;
frame-opacity = 0.96;
menu-opacity = 0.96;

corner-radius = 9;

rounded-corners-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'",
  "class_g = 'XTerm'"
];

shadow-exclude = [
  "name = 'Notification'",
  "class_g = 'Tint2'",
  "window_type = 'dock'",
  "window_type = 'desktop'"
];

wintypes:
{
  tooltip = { fade = true; shadow = true; opacity = 0.94; };
  menu = { shadow = true; opacity = 0.96; };
  dropdown_menu = { shadow = true; opacity = 0.96; };
  popup_menu = { shadow = true; opacity = 0.96; };
  dock = { shadow = false; };
  desktop = { shadow = false; };
};
EOF

info "Writing tint2 dock..."
cat > "$USER_HOME/.config/tint2/tint2rc" <<EOF
# Aqua/Leopard fake dock for tint2

rounded = 20
border_width = 1
background_color = $PANEL_BG 78
border_color = $PANEL_BORDER 80

rounded = 14
border_width = 1
background_color = #ffffff 48
border_color = #ffffff 72

rounded = 14
border_width = 1
background_color = $ACCENT 72
border_color = #ffffff 80

panel_items = LTSC
panel_size = 76% 58
panel_margin = 0 12
panel_padding = 10 5 10
panel_position = bottom center horizontal
panel_layer = top
panel_background_id = 1
wm_menu = 1
panel_dock = 0
panel_pivot_struts = 0

launcher_padding = 10 5 10
launcher_background_id = 0
launcher_icon_size = 38
launcher_item_app = /usr/local/share/applications/pcmanfm.desktop
launcher_item_app = /usr/local/share/applications/firefox.desktop
launcher_item_app = /usr/local/share/applications/xterm.desktop
launcher_item_app = /usr/local/share/applications/lxappearance.desktop

taskbar_mode = single_desktop
taskbar_padding = 4 4 4
taskbar_background_id = 0
taskbar_active_background_id = 0

task_icon = 1
task_text = 0
task_centered = 1
task_maximum_size = 52 46
task_padding = 8 5 8
task_background_id = 2
task_active_background_id = 3
task_iconified_background_id = 1
task_icon_asb = 100 0 0
task_active_icon_asb = 100 0 8
task_iconified_icon_asb = 70 0 0

systray = 1
systray_padding = 8 5 8
systray_background_id = 0
systray_icon_size = 24
systray_icon_asb = 100 0 0

clock = 1
time1_format = %H:%M
time2_format = %a %d
time1_font = DejaVu Sans Bold 10
time2_font = DejaVu Sans 8
clock_font_color = #18334f 100
clock_padding = 12 5
clock_background_id = 1

tooltip = 1
tooltip_padding = 8 6
tooltip_show_timeout = 0.5
tooltip_hide_timeout = 0.2
tooltip_background_id = 1
tooltip_font = DejaVu Sans 10
tooltip_font_color = #18334f 100
EOF

info "Writing Openbox config..."
cat > "$USER_HOME/.config/openbox/rc.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc"
 xmlns:xi="http://www.w3.org/2001/XInclude">

  <resistance>
    <strength>10</strength>
    <screen_edge_strength>20</screen_edge_strength>
  </resistance>

  <focus>
    <focusNew>yes</focusNew>
    <followMouse>no</followMouse>
    <focusLast>yes</focusLast>
    <underMouse>no</underMouse>
    <focusDelay>160</focusDelay>
    <raiseOnFocus>no</raiseOnFocus>
  </focus>

  <placement>
    <policy>Smart</policy>
    <center>yes</center>
    <monitor>Primary</monitor>
  </placement>

  <theme>
    <name>$OB_THEME</name>
    <titleLayout>CIML</titleLayout>
    <keepBorder>yes</keepBorder>
    <animateIconify>yes</animateIconify>
    <font place="ActiveWindow">
      <name>DejaVu Sans</name>
      <size>10</size>
      <weight>bold</weight>
      <slant>normal</slant>
    </font>
    <font place="InactiveWindow">
      <name>DejaVu Sans</name>
      <size>10</size>
      <weight>normal</weight>
      <slant>normal</slant>
    </font>
    <font place="MenuHeader">
      <name>DejaVu Sans</name>
      <size>10</size>
      <weight>bold</weight>
      <slant>normal</slant>
    </font>
    <font place="MenuItem">
      <name>DejaVu Sans</name>
      <size>10</size>
      <weight>normal</weight>
      <slant>normal</slant>
    </font>
  </theme>

  <desktops>
    <number>4</number>
    <firstdesk>1</firstdesk>
    <names>
      <name>Finder</name>
      <name>Terminal</name>
      <name>Web</name>
      <name>BSD</name>
    </names>
    <popupTime>750</popupTime>
  </desktops>

  <resize>
    <drawContents>yes</drawContents>
    <popupShow>Nonpixel</popupShow>
    <popupPosition>Center</popupPosition>
  </resize>

  <keyboard>
    <chainQuitKey>C-g</chainQuitKey>

    <keybind key="A-Return">
      <action name="Execute"><command>xterm</command></action>
    </keybind>

    <keybind key="A-space">
      <action name="ShowMenu"><menu>root-menu</menu></action>
    </keybind>

    <keybind key="A-Tab">
      <action name="NextWindow"/>
    </keybind>

    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>

    <keybind key="W-r">
      <action name="Reconfigure"/>
    </keybind>

    <keybind key="W-f">
      <action name="Execute"><command>pcmanfm</command></action>
    </keybind>
  </keyboard>

  <mouse>
    <dragThreshold>8</dragThreshold>
    <doubleClickTime>200</doubleClickTime>
    <screenEdgeWarpTime>400</screenEdgeWarpTime>
    <screenEdgeWarpMouse>false</screenEdgeWarpMouse>
  </mouse>

  <menu>
    <file>menu.xml</file>
    <hideDelay>180</hideDelay>
    <middle>no</middle>
    <submenuShowDelay>100</submenuShowDelay>
    <applicationIcons>yes</applicationIcons>
    <manageDesktops>yes</manageDesktops>
  </menu>

  <applications>
  </applications>
</openbox_config>
EOF

cat > "$USER_HOME/.config/openbox/menu.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
  <menu id="root-menu" label=" BSD Aqua">
    <item label="Finder / Files">
      <action name="Execute"><command>pcmanfm</command></action>
    </item>
    <item label="Terminal">
      <action name="Execute"><command>xterm</command></action>
    </item>
    <item label="Firefox">
      <action name="Execute"><command>firefox</command></action>
    </item>
    <separator/>
    <item label="GTK Appearance">
      <action name="Execute"><command>lxappearance</command></action>
    </item>
    <item label="Openbox Theme">
      <action name="Execute"><command>obconf</command></action>
    </item>
    <item label="Reconfigure Openbox">
      <action name="Reconfigure"/>
    </item>
    <separator/>
    <menu id="power-menu" label="Power">
      <item label="Exit Openbox">
        <action name="Exit"/>
      </item>
      <item label="Reboot">
        <action name="Execute"><command>su - root -c 'reboot'</command></action>
      </item>
      <item label="Shutdown">
        <action name="Execute"><command>su - root -c 'shutdown -p now'</command></action>
      </item>
    </menu>
  </menu>
</openbox_menu>
EOF

info "Writing Openbox autostart..."
cat > "$USER_HOME/.config/openbox/autostart" <<EOF
#!/bin/sh

# Load terminal colors/fonts.
if command -v xrdb >/dev/null 2>&1; then
  xrdb -merge "\$HOME/.Xresources" &
fi

# GTK and icon theme environment.
export GTK_THEME="$GTK_THEME"
export XCURSOR_THEME="Adwaita"

# Nice cursor.
xsetroot -cursor_name left_ptr 2>/dev/null || true

# Wallpaper.
if command -v feh >/dev/null 2>&1; then
  feh --bg-fill "\$HOME/Pictures/bsd-aqua-${PROFILE}.ppm" &
else
  xsetroot -solid "$ACCENT" &
fi

# File manager desktop is intentionally disabled: Openbox right-click menu stays usable.
# Start pcmanfm desktop manually if you want it:
#   pcmanfm --desktop &

# Compositor: shadows, fades, menu transparency.
if command -v picom >/dev/null 2>&1; then
  picom --config "\$HOME/.config/picom/picom.conf" &
fi

# Dock-like bottom panel.
if command -v tint2 >/dev/null 2>&1; then
  tint2 -c "\$HOME/.config/tint2/tint2rc" &
fi

# VirtualBox clipboard integration.
if command -v VBoxClient >/dev/null 2>&1; then
  VBoxClient --clipboard &
  VBoxClient --draganddrop &
  VBoxClient --seamless &
  VBoxClient --checkhostversion &
fi

# Safety terminal.
xterm &
EOF
chmod +x "$USER_HOME/.config/openbox/autostart"

cat > "$USER_HOME/.xinitrc" <<'EOF'
#!/bin/sh
exec openbox-session
EOF
chmod +x "$USER_HOME/.xinitrc"

info "Setting ownership..."
chown -R "$USER_NAME:$USER_NAME" \
  "$USER_HOME/.themes" \
  "$USER_HOME/.icons" \
  "$USER_HOME/.config" \
  "$USER_HOME/Pictures" \
  "$USER_HOME/.gtkrc-2.0" \
  "$USER_HOME/.Xresources" \
  "$USER_HOME/.xinitrc"

# Best-effort icon cache.
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f "$USER_HOME/.icons/$ICON_THEME" >/dev/null 2>&1 || true
fi

cat <<EOF

DONE.

Applied profile:
  $PROFILE

Installed themes:
  GTK:      $GTK_THEME
  Openbox: $OB_THEME
  Icons:   $ICON_THEME

Run as user '$USER_NAME':
  startx

Hotkeys:
  Alt+Enter  terminal
  Alt+Space  menu
  Super+f    file manager
  Super+r    reconfigure Openbox

To try another profile, run as root:
  sh $0 $USER_NAME leopard
  sh $0 $USER_NAME graphite
  sh $0 $USER_NAME modern

If something looks half-applied:
  1) exit Openbox
  2) startx again
  3) open lxappearance and choose GTK '$GTK_THEME' + icons '$ICON_THEME'
EOF

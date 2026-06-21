#!/bin/sh
# whitesur-xfce-freebsd.sh
# XFCE + LightDM + WhiteSur GTK/icons/cursors/wallpapers for FreeBSD.
# Usage as root: sh whitesur-xfce-freebsd.sh USER [light|dark]

set -eu

info(){ echo "==> $*"; }
warn(){ echo "WARN: $*" >&2; }
die(){ echo "ERROR: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root"
[ "$(uname -s)" = "FreeBSD" ] || die "FreeBSD only"

U="${1:-}"
MODE="${2:-light}"
[ -n "$U" ] || die "usage: sh $0 USER [light|dark]"
case "$MODE" in light|dark) ;; *) die "mode must be light or dark";; esac
id "$U" >/dev/null 2>&1 || die "user not found: $U"
H="$(pw usershow "$U" | awk -F: '{print $9}')"
[ -d "$H" ] || die "home not found: $H"

CAP="$(printf '%s' "$MODE" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"

pkg_bootstrap(){ env ASSUME_ALWAYS_YES=yes pkg bootstrap -f >/dev/null 2>&1 || true; }
try_pkg(){ pkg info -e "$1" >/dev/null 2>&1 || pkg install -y "$1" || warn "pkg failed/missing: $1"; }

info "pkg bootstrap/update"
pkg_bootstrap
pkg update || true

info "installing XFCE, LightDM, WhiteSur build deps"
for p in \
  xorg xfce lightdm lightdm-gtk-greeter dbus git bash ca_root_nss sudo \
  firefox xfce4-terminal thunar-archive-plugin xfce4-whiskermenu-plugin \
  xfce4-pulseaudio-plugin xfce4-screensaver feh picom plank \
  fontconfig dejavu webfonts noto-basic hicolor-icon-theme adwaita-icon-theme \
  gtk-murrine-engine gtk-engines2 sassc gsed gmake libxml2 optipng ImageMagick7-nox11
 do try_pkg "$p"; done

info "users/groups/services"
pw groupmod video -m "$U" 2>/dev/null || true
pw groupmod wheel -m "$U" 2>/dev/null || true
pw groupmod operator -m "$U" 2>/dev/null || true
sysrc dbus_enable=YES
sysrc lightdm_enable=YES
[ -f /usr/local/etc/rc.d/vboxguest ] && sysrc vboxguest_enable=YES || true
[ -f /usr/local/etc/rc.d/vboxservice ] && sysrc vboxservice_enable=YES || true
mkdir -p /usr/local/etc/sudoers.d
echo '%wheel ALL=(ALL:ALL) ALL' > /usr/local/etc/sudoers.d/wheel
chmod 0440 /usr/local/etc/sudoers.d/wheel

TS="$(date +%Y%m%d-%H%M%S)"
backup(){ [ -e "$1" ] && cp -Rp "$1" "$1.backup.$TS" && info "backup: $1.backup.$TS" || true; }
for x in "$H/.themes" "$H/.icons" "$H/.local/share/icons" "$H/.config/xfce4" "$H/.config/autostart" "$H/.gtkrc-2.0" "$H/.config/gtk-3.0" "$H/.xinitrc"; do backup "$x"; done

mkdir -p "$H/.themes" "$H/.icons" "$H/.local/share/icons" "$H/.local/share/backgrounds" \
         "$H/.local/bin" "$H/.config/autostart" "$H/.config/gtk-3.0" \
         "$H/.config/xfce4/xfconf/xfce-perchannel-xml" "$H/Pictures/WhiteSur"
chown -R "$U:$U" "$H/.themes" "$H/.icons" "$H/.local" "$H/.config" "$H/Pictures"

USER_SCRIPT="/tmp/whitesur-user-$$.sh"
cat > "$USER_SCRIPT" <<'USER_INNER_SCRIPT'
#!/bin/sh
set -eu
H="$1"
MODE="$2"
[ "$MODE" = dark ] && CAP=Dark || CAP=Light
export HOME="$H"
export PATH="/tmp/whitesur-gnu-bin:$HOME/.local/bin:/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin"
mkdir -p /tmp/whitesur-gnu-bin "$HOME/.themes" "$HOME/.icons" "$HOME/.local/share/icons" "$HOME/.local/share/backgrounds" "$HOME/.config/autostart" "$HOME/.config/gtk-3.0" "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml" "$HOME/Pictures/WhiteSur"
command -v gsed >/dev/null 2>&1 && ln -sf "$(command -v gsed)" /tmp/whitesur-gnu-bin/sed || true
TMP="$HOME/.cache/whitesur-build"
rm -rf "$TMP"; mkdir -p "$TMP"
clone(){ rm -rf "$2"; git clone --depth 1 --branch "$3" "https://github.com/$1.git" "$2" || git clone --depth 1 "https://github.com/$1.git" "$2" || true; }
clone vinceliuice/WhiteSur-gtk-theme "$TMP/gtk" master
clone vinceliuice/WhiteSur-icon-theme "$TMP/icons" master
clone vinceliuice/WhiteSur-cursors "$TMP/cursors" master
clone vinceliuice/WhiteSur-wallpapers "$TMP/walls" main

if [ -d "$TMP/gtk" ]; then
  cd "$TMP/gtk"
  bash ./install.sh -d "$HOME/.themes" -c light -c dark -o normal -t blue -N stable || \
  bash ./install.sh -d "$HOME/.themes" -c "$MODE" -o normal -t blue || true
fi
if [ -d "$TMP/icons" ]; then
  cd "$TMP/icons"
  bash ./install.sh -d "$HOME/.local/share/icons" -t default -a || bash ./install.sh -d "$HOME/.local/share/icons" || true
fi
if [ -d "$TMP/cursors" ]; then
  cd "$TMP/cursors"
  bash ./install.sh || true
fi
if [ -d "$TMP/walls" ]; then
  cd "$TMP/walls"
  bash ./install-wallpapers.sh -t whitesur -c light -s 1080p >/dev/null 2>&1 || true
  bash ./install-wallpapers.sh -t whitesur -c dark -s 1080p >/dev/null 2>&1 || true
  find "$TMP/walls" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -exec cp -f {} "$HOME/Pictures/WhiteSur/" \; 2>/dev/null || true
fi

GTK="$(find "$HOME/.themes" -maxdepth 1 -type d -name "WhiteSur-${CAP}*" 2>/dev/null | sed 's|.*/||' | sort | head -n 1 || true)"
[ -n "$GTK" ] || GTK="WhiteSur-${CAP}"
ICON="$(find "$HOME/.local/share/icons" "$HOME/.icons" -maxdepth 1 -type d -name 'WhiteSur*' 2>/dev/null | sed 's|.*/||' | sort | head -n 1 || true)"
[ -n "$ICON" ] || ICON=WhiteSur
CURSOR="$(find "$HOME/.local/share/icons" "$HOME/.icons" -maxdepth 1 -type d -name '*WhiteSur*' 2>/dev/null | while read d; do [ -d "$d/cursors" ] && basename "$d"; done | sort | head -n 1 || true)"
[ -n "$CURSOR" ] || CURSOR=WhiteSur-cursors
WALL="$(find "$HOME/Pictures/WhiteSur" "$HOME/.local/share/backgrounds" -type f \( -iname "*${MODE}*.jpg" -o -iname "*${MODE}*.png" \) 2>/dev/null | sort | head -n 1 || true)"
[ -n "$WALL" ] || WALL="$(find "$HOME/Pictures/WhiteSur" "$HOME/.local/share/backgrounds" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | sort | head -n 1 || true)"

cat > "$HOME/.gtkrc-2.0" <<USER_GTK2_EOF
gtk-theme-name="$GTK"
gtk-icon-theme-name="$ICON"
gtk-cursor-theme-name="$CURSOR"
gtk-font-name="DejaVu Sans 10"
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-menu-images=1
gtk-button-images=1
USER_GTK2_EOF
cat > "$HOME/.config/gtk-3.0/settings.ini" <<USER_GTK3_EOF
[Settings]
gtk-theme-name=$GTK
gtk-icon-theme-name=$ICON
gtk-cursor-theme-name=$CURSOR
gtk-font-name=DejaVu Sans 10
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-menu-images=1
gtk-button-images=1
gtk-application-prefer-dark-theme=$([ "$MODE" = dark ] && echo true || echo false)
USER_GTK3_EOF
cat > "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" <<USER_XSETTINGS_EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="$GTK"/>
    <property name="IconThemeName" type="string" value="$ICON"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CursorThemeName" type="string" value="$CURSOR"/>
    <property name="FontName" type="string" value="DejaVu Sans 10"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
</channel>
USER_XSETTINGS_EOF
cat > "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" <<USER_XFWM4_EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="$GTK"/>
    <property name="title_font" type="string" value="DejaVu Sans Bold 10"/>
    <property name="button_layout" type="string" value="CHM|O"/>
    <property name="use_compositing" type="bool" value="true"/>
    <property name="show_frame_shadow" type="bool" value="true"/>
    <property name="inactive_opacity" type="int" value="96"/>
  </property>
</channel>
USER_XFWM4_EOF
cat > "$HOME/.local/bin/apply-whitesur-xfce.sh" <<USER_APPLY_EOF
#!/bin/sh
sleep 2
setv(){ xfconf-query -c "\$1" -p "\$2" -s "\$4" >/dev/null 2>&1 || xfconf-query -c "\$1" -p "\$2" --create -t "\$3" -s "\$4" >/dev/null 2>&1 || true; }
GTK='$GTK'; ICON='$ICON'; CURSOR='$CURSOR'; WALL='$WALL'
setv xsettings /Net/ThemeName string "\$GTK"
setv xsettings /Net/IconThemeName string "\$ICON"
setv xsettings /Gtk/CursorThemeName string "\$CURSOR"
setv xsettings /Gtk/FontName string "DejaVu Sans 10"
setv xfwm4 /general/theme string "\$GTK"
setv xfwm4 /general/button_layout string "CHM|O"
setv xfwm4 /general/use_compositing bool true
setv xfwm4 /general/show_frame_shadow bool true
setv xfwm4 /general/inactive_opacity int 96
if [ -n "\$WALL" ] && [ -f "\$WALL" ]; then
  for p in \$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '/last-image$|/image-path$' || true); do xfconf-query -c xfce4-desktop -p "\$p" -s "\$WALL" >/dev/null 2>&1 || true; done
  for p in /backdrop/screen0/monitorVirtual1/workspace0/last-image /backdrop/screen0/monitorDefault/workspace0/last-image; do xfconf-query -c xfce4-desktop -p "\$p" --create -t string -s "\$WALL" >/dev/null 2>&1 || true; done
fi
if command -v plank >/dev/null 2>&1 && ! pgrep -u "\$(id -u)" plank >/dev/null 2>&1; then plank >/dev/null 2>&1 & fi
USER_APPLY_EOF
chmod +x "$HOME/.local/bin/apply-whitesur-xfce.sh"
cat > "$HOME/.config/autostart/whitesur-xfce-apply.desktop" <<USER_AUTOSTART_EOF
[Desktop Entry]
Type=Application
Name=Apply WhiteSur XFCE
Exec=$HOME/.local/bin/apply-whitesur-xfce.sh
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
USER_AUTOSTART_EOF
cat > "$HOME/.config/autostart/plank.desktop" <<USER_PLANK_EOF
[Desktop Entry]
Type=Application
Name=Plank Dock
Exec=plank
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
USER_PLANK_EOF
cat > "$HOME/.xinitrc" <<'USER_XINITRC_EOF'
. /usr/local/etc/xdg/xfce4/xinitrc
USER_XINITRC_EOF
chmod +x "$HOME/.xinitrc"
cat > "$HOME/.cache/whitesur-xfce-meta" <<USER_META_EOF
GTK_THEME=$GTK
ICON_THEME=$ICON
CURSOR_THEME=$CURSOR
WALL=$WALL
USER_META_EOF
USER_INNER_SCRIPT
chmod +x "$USER_SCRIPT"

info "installing themes as user $U"
su -m "$U" -c "sh '$USER_SCRIPT' '$H' '$MODE'" || warn "user install had errors"
rm -f "$USER_SCRIPT"

GTK_THEME="WhiteSur-$CAP"; ICON_THEME=WhiteSur; CURSOR_THEME=WhiteSur-cursors; WALL=""
[ -f "$H/.cache/whitesur-xfce-meta" ] && . "$H/.cache/whitesur-xfce-meta" || true

info "configuring LightDM greeter"
mkdir -p /usr/local/etc/lightdm
cat > /usr/local/etc/lightdm/lightdm-gtk-greeter.conf <<LIGHTDM_CONF_EOF
[greeter]
theme-name=$GTK_THEME
icon-theme-name=$ICON_THEME
cursor-theme-name=$CURSOR_THEME
font-name=DejaVu Sans 10
xft-antialias=true
xft-hintstyle=hintslight
xft-rgba=rgb
background=$WALL
user-background=false
panel-position=top
clock-format=%a %d %b, %H:%M
indicators=~host;~spacer;~clock;~spacer;~session;~a11y;~power
LIGHTDM_CONF_EOF

chown -R "$U:$U" "$H/.themes" "$H/.icons" "$H/.local" "$H/.config" "$H/Pictures" "$H/.gtkrc-2.0" "$H/.xinitrc"
service dbus onestart 2>/dev/null || service dbus start 2>/dev/null || true
service lightdm onerestart 2>/dev/null || true

cat <<FINAL_MESSAGE_EOF

DONE: XFCE + full WhiteSur route installed for $U
Mode: $MODE
GTK: $GTK_THEME
Icons: $ICON_THEME
Cursor: $CURSOR_THEME
Wallpaper: ${WALL:-none}

Now:
  reboot

Then login via LightDM into XFCE.
Fallback:
  login as $U
  startx

If it only half-applies, logout/login once, then check:
  Settings -> Appearance
  Settings -> Window Manager
FINAL_MESSAGE_EOF

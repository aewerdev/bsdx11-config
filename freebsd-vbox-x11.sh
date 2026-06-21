#!/bin/sh
# Minimal durable X11 setup for FreeBSD guest in VirtualBox.
# Usage as root:
#   sh freebsd-vbox-x11.sh your_username
#
# After reboot/login as your user:
#   startx

set -eu

die() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

[ "$(id -u)" -eq 0 ] || die "Run this script as root."
[ "$(uname -s)" = "FreeBSD" ] || die "This script is intended for FreeBSD only."

USER_NAME="${1:-}"
[ -n "$USER_NAME" ] || die "Usage: sh $0 your_username"

id "$USER_NAME" >/dev/null 2>&1 || die "User '$USER_NAME' does not exist."

USER_HOME="$(pw usershow "$USER_NAME" | awk -F: '{print $9}')"
[ -n "$USER_HOME" ] || die "Could not determine home directory for '$USER_NAME'."
[ -d "$USER_HOME" ] || die "Home directory '$USER_HOME' does not exist."

info "Bootstrapping pkg if needed..."
env ASSUME_ALWAYS_YES=yes pkg bootstrap -f >/dev/null 2>&1 || true

info "Updating pkg repository metadata..."
pkg update

info "Installing minimal X11 desktop packages..."
pkg install -y \
  xorg \
  openbox \
  xterm \
  twm \
  dbus \
  virtualbox-ose-additions

info "Enabling required services in /etc/rc.conf..."
sysrc dbus_enable="YES"
sysrc vboxguest_enable="YES"
sysrc vboxservice_enable="YES"

info "Adding '$USER_NAME' to useful desktop groups..."
pw groupmod video -m "$USER_NAME" 2>/dev/null || true
pw groupmod wheel -m "$USER_NAME" 2>/dev/null || true

info "Creating ~/.xinitrc for Openbox..."
cat > "$USER_HOME/.xinitrc" <<'EOF'
#!/bin/sh

# Minimal durable X11 session.
# Start VirtualBox clipboard integration when available.
if command -v VBoxClient >/dev/null 2>&1; then
  VBoxClient --clipboard &
  VBoxClient --draganddrop &
  VBoxClient --seamless &
  VBoxClient --checkhostversion &
fi

# Basic fallback terminal in case Openbox menu is empty.
xterm &

exec openbox-session
EOF

chown "$USER_NAME:$USER_NAME" "$USER_HOME/.xinitrc"
chmod +x "$USER_HOME/.xinitrc"

info "Starting services now..."
service dbus onestart 2>/dev/null || service dbus start 2>/dev/null || true
service vboxguest onestart 2>/dev/null || service vboxguest start 2>/dev/null || true
service vboxservice onestart 2>/dev/null || service vboxservice start 2>/dev/null || true

cat <<EOF

DONE.

VirtualBox VM settings recommended:
  Display -> Graphics Controller: VBoxSVGA
  Video Memory: 128 MB
  3D Acceleration: OFF for the first test

Now reboot:
  reboot

Then login as '$USER_NAME' and run:
  startx

If Openbox starts, you have a minimal working X11 desktop.
Right-click on the desktop for the Openbox menu.
EOF

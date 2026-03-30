# .profile — /bin/sh login shell config (FreeBSD)

# ── path ──────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── environment ───────────────────────────────────────────────────────────────
export EDITOR=vim
export PAGER=less
# -R: pass ANSI colour codes through; -F: quit if output fits on one screen;
# -X: don't clear screen on exit; -i: case-insensitive search
export LESS="-RFXi"

# point sh(1) at the interactive config
export ENV=$HOME/.shrc

# ── wayland ───────────────────────────────────────────────────────────────────
# XDG_RUNTIME_DIR is normally set by seatd/pam_xdg, but set it here as a
# fallback so tools launched from a terminal can find the Wayland socket.
# /tmp/runtime-<uid> follows the XDG spec default when no login manager sets it.
: "${XDG_RUNTIME_DIR:=/tmp/runtime-$(id -u)}"
export XDG_RUNTIME_DIR
# Firefox defaults to XWayland without this; set unconditionally since the
# .profile only loads on FreeBSD where Wayland is the only display server.
export MOZ_ENABLE_WAYLAND=1
# Qt 6 Wayland backend; qt6-wayland is installed on this machine.
export QT_QPA_PLATFORM=wayland

# ── vt / serial helpers ───────────────────────────────────────────────────────
# requery terminal size; useful on serial lines and after resize
[ -x /usr/bin/resizewin ] && /usr/bin/resizewin -z

# larger VT font — only applies on the FreeBSD virtual console
[ -x /usr/sbin/vidcontrol ] && vidcontrol -f 12x22 /usr/share/vt/fonts/ttyp0-22.fnt 2>/dev/null

# ── login greeting ────────────────────────────────────────────────────────────
[ -x /usr/bin/fortune ] && /usr/bin/fortune freebsd-tips

# ── home symlink fix ──────────────────────────────────────────────────────────
# /home is a symlink on FreeBSD; ensure $PWD resolves correctly
if [ "$PWD" != "$HOME" ] && [ "$PWD" -ef "$HOME" ]; then cd; fi

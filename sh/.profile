# .profile — /bin/sh login shell config (FreeBSD)

# ── path ──────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── environment ───────────────────────────────────────────────────────────────
export EDITOR=vim
export PAGER=less

# point sh(1) at the interactive config
export ENV=$HOME/.shrc

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

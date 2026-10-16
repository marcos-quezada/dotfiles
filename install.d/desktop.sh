#!/bin/sh
# install.d/desktop.sh — Wayland/desktop package selection: foot, sway,
# quickshell, cursors, mpv, pulseaudio, the FreeBSD-only vt console font
# and ly display manager config, and (FreeBSD-only) the sh/.shrc package.
# sourced only, never executed directly.
# requires: common.sh already sourced (ok/warn/info/die/prompt_yn/stow_pkg/
# stow_root/detect_sudo), $PLATFORM and $YES set, $REPO_DIR set.

desktop_select_main() {
    # ── defaults ──────────────────────────────────────────────────────────────
    # quickshell, sh, sway are only meaningful on freebsd/linux (Wayland)
    DO_QUICKSHELL=0
    DO_SH=0
    DO_FOOT=0
    DO_SWAY=0
    DO_VT=0
    [ "$PLATFORM" = "freebsd" ] && DO_QUICKSHELL=1
    [ "$PLATFORM" = "freebsd" ] && DO_SH=1
    # foot and sway are Wayland-native; default on for freebsd and linux
    [ "$PLATFORM" = "freebsd" ] && DO_FOOT=1
    [ "$PLATFORM" = "freebsd" ] && DO_SWAY=1
    [ "$PLATFORM" = "linux" ]   && DO_FOOT=1
    [ "$PLATFORM" = "linux" ]   && DO_SWAY=1
    # vt console font — FreeBSD only; one time copy to /boot/fonts/ (root-owned,
    # not stow managed - a simlink here would fail at boot, see
    # docs/architecture.md's "why early boot system config files aren't stowed")
    [ "$PLATFORM" = "freebsd" ] && DO_VT=1
    # ly display manager config — FreeBSD only; stows to /usr/local/etc/ly/ (root-owned)
    DO_LY=0
    [ "$PLATFORM" = "freebsd" ] && DO_LY=1
    # mpv config (ao=pulse) — FreeBSD only; requires mpv rebuild from ports with
    # PulseAudio enabled, see docs/architecture.md's "audio output" section
    DO_MPV=0
    [ "$PLATFORM" = "freebsd" ] && DO_MPV=1
    # pulseaudio daemon.conf (exit-idle-time = -1) — FreeBSD only
    DO_PULSEAUDIO=0
    [ "$PLATFORM" = "freebsd" ] && DO_PULSEAUDIO=1

    # —— prompts ——————————————————————————————————————————————————————————————
    if [ "$YES" = "0" ]; then
      if [ "$PLATFORM" = "freebsd" ]; then
        printf '\n  FreeBSD packages:\n\n'
        prompt_yn "stow sh (.shrc + .profile)?" y && DO_SH=1 || DO_SH=0
        prompt_yn "stow foot (Wayland terminal emulator)?" y && DO_FOOT=1 || DO_FOOT=0
        prompt_yn "stow sway (window manager config)?" y && DO_SWAY=1 || DO_SWAY=0
        prompt_yn "stow cursors (retrosmart win-ish XCursor themes)?" y && DO_CURSORS=1 || DO_CURSORS=0
        prompt_yn "stow quickshell (sway statusbar — Wayland only)?" y && DO_QUICKSHELL=1 || DO_QUICKSHELL=0
        prompt_yn "copy vt console font to /boot/fonts/ (one time, requires doas/sudo)?" y && DO_VT=1 || DO_VT=0
        prompt_yn "install ly config to /usr/local/etc/ly/ (requires doas/sudo)?" y && DO_LY=1 || DO_LY=0
        prompt_yn "stow mpv (.config/mpv/mpv.conf — ao=pulse)?" y && DO_MPV=1 || DO_MPV=0
        prompt_yn "stow pulseaudio (.config/pulse/daemon.conf — exit-idle-time = -1)?" y && DO_PULSEAUDIO=1 || DO_PULSEAUDIO=0
      elif [ "$PLATFORM" = "linux" ]; then
        printf '\n  Linux packages:\n\n'
        prompt_yn "stow foot (Wayland terminal emulator)?" y && DO_FOOT=1 || DO_FOOT=0
        prompt_yn "stow sway (window manager config)?" y && DO_SWAY=1 || DO_SWAY=0
        prompt_yn "stow cursors (retrosmart win-ish XCursor themes)?" y && DO_CURSORS=1 || DO_CURSORS=0
      else
        info "sh skipped — FreeBSD /bin/sh config only"
        info "foot skipped — Wayland terminal, FreeBSD/Linux only"
        info "sway skipped — Wayland window manager, FreeBSD/Linux only"
        info "quickshell skipped — sway/Wayland package, FreeBSD only"
        info "ly skipped — FreeBSD display manager, FreeBSD only"
      fi
    fi 

    # —— run stow —————————————————————————————————————————————————————————————
    [ "$DO_SH"         = "1" ] && stow_pkg sh
    [ "$DO_FOOT"       = "1" ] && stow_pkg foot
    [ "$DO_SWAY"       = "1" ] && stow_pkg sway
    [ "$DO_CURSORS"    = "1" ] && stow_pkg cursors
    [ "$DO_QUICKSHELL" = "1" ] && stow_pkg quickshell
    [ "$DO_MPV"        = "1" ] && stow_pkg mpv
    [ "$DO_PULSEAUDIO" = "1" ] && stow_pkg pulseaudio
    [ "$DO_LY"         = "1" ] && stow_root ly

    # —— vt font install ——————————————————————————————————————————————————————
    if [ "$DO_VT" = "1" ]; then
      detect_sudo
      if [ -z "$SUDO" ]; then
        die "doas or sudo required to install the vt console font"
      fi
      if ${SUDO} cp "$REPO_DIR/vt/boot/fonts/12x22.fnt.gz" /boot/fonts/12x22.fnt.gz \
        && ${SUDO} cp "$REPO_DIR/vt/boot/fonts/INDEX.fonts" /boot/fonts/INDEX.fonts; then
        ok "vt console font copied to /boot/fonts/"
      else
        die "vt console font copy failed"
      fi
    fi
}

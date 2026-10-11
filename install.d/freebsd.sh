#!/bin/sh
# install.d/freebsd.sh — FreeBSD-specific setup: doas/doas.conf, keychain,
# mpv/mpv-mpris/python3 (music playback deps). sourced only, never executed
# directly. requires: common.sh already sourced, $PLATFORM set.
# no-op on macOS/Linux — callers should only invoke freebsd_setup_main when
# $PLATFORM = "freebsd" (install.sh guards the call site, matching the
# original script's own platform gating).

freebsd_setup_main() {
    # ── doas ──────────────────────────────────────────────────────────────────
    # doas is the privilege escalation tool used on FreeBSD. install.sh itself
    # uses it for the vt font install and any pkg installs. check early so the
    # rest of the script can rely on it being present.
    printf '\n  checking doas...\n\n'
    if command -v doas >/dev/null 2>&1; then
      ok "doas found"
      # confirm /usr/local/etc/doas.conf exists — without it doas blocks everything
      if [ -f /usr/local/etc/doas.conf ]; then
        ok "doas.conf found"
      else
        warn "doas is installed but /usr/local/etc/doas.conf does not exist"
        info "minimal config to allow wheel group: permit persist :wheel"
        if prompt_yn "write a minimal doas.conf now? (requires sudo)" n; then
          printf 'permit persist :wheel\n' | sudo tee /usr/local/etc/doas.conf >/dev/null
          chmod 640 /usr/local/etc/doas.conf
          ok "wrote /usr/local/etc/doas.conf"
        else
          warn "doas will not work until doas.conf is created — run as root:"
          info "  printf 'permit persist :wheel\\n' > /usr/local/etc/doas.conf"
          info "  chmod 640 /usr/local/etc/doas.conf"
        fi
      fi
    else
      warn "doas not found"
      if prompt_yn "install doas via pkg? (requires sudo)" y; then
        sudo pkg install -y doas
        ok "doas installed"
        if [ ! -f /usr/local/etc/doas.conf ]; then
          printf 'permit persist :wheel\n' | sudo tee /usr/local/etc/doas.conf >/dev/null
          chmod 640 /usr/local/etc/doas.conf
          ok "wrote /usr/local/etc/doas.conf"
        fi
      else
        warn "doas is required for vt font install and pkg operations — install it manually"
      fi
    fi

    # ── keychain ──────────────────────────────────────────────────────────────
    if ! pkg info -e keychain > /dev/null 2>&1; then
      if prompt_yn "Install keychain (persistent ssh-agent)?" y; then
        doas pkg install -y keychain
      fi
    fi

    # ── music playback deps ───────────────────────────────────────────────────
    for pkg in mpv mpv-mpris python3; do
      if ! pkg info -e "$pkg" >/dev/null 2>&1; then
        if prompt_yn "install $pkg (required for music playback)?" y; then
          doas pkg install -y "$pkg"
        fi
      fi
    done
}

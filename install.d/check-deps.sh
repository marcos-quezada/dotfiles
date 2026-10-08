#!/bin/sh
# install.d/check-deps.sh — dependency checks: stow, core/font/optional deps,
# shell dev tools. sourced only, never executed directly.
# requires: common.sh already sourced (ok/warn/die/prompt_yn/check_cmd
# install_pkg/pkg_name), $PLATFORM set.

check_deps_main() {
    # ── stow check ────────────────────────────────────────────────────────────
    if ! command -v stow >/dev/null 2>&1; then
      warn "stow not found"
      if prompt_yn "install stow now?" y; then
        install_pkg "$(pkg_name stow stow stow)"
      else
        die "stow is required — install it and re-run"
      fi
    else
      ok "stow found"
    fi

    # yt-dlp deliberately NOT pkg-managed — installed per official wiki instructions
    # specifically so it can self update (yt-dlp -U) independent of pkg's release
    # cadence. check presence, don't try to install/manage it here.
    if ! command -v yt-dlp > /dev/null 2>&1; then
      warn "yt-dlp not found — install per https://github.com/yt-dlp/yt-dlp/wiki/Installation"
    fi

    # ── core deps ─────────────────────────────────────────────────────────────
    printf '\n  checking core dependencies...\n\n'
    MISSING_CORE=""

    check_cmd curl "$(pkg_name curl curl curl)" || MISSING_CORE="$MISSING_CORE curl"
    check_cmd jq   "$(pkg_name jq jq jq)"       || MISSING_CORE="$MISSING_CORE jq"
    check_cmd awk  "built into base system"

    # bat is required on FreeBSD (powers the clue alias); optional elsewhere
    if [ "$PLATFORM" = "freebsd" ]; then
      check_cmd bat "bat" || MISSING_CORE="$MISSING_CORE bat"
    fi

    # w3m is required on FreeBSD (powers the handbook alias)
    if [ "$PLATFORM" = "freebsd" ]; then
      check_cmd w3m "w3m" || MISSING_CORE="$MISSING_CORE w3m"
    fi

    if [ -n "$MISSING_CORE" ]; then
      printf '\n'
      warn "missing required tools:$MISSING_CORE"
      if prompt_yn "install them now?" y; then
        # shellcheck disable=SC2086
        install_pkg $MISSING_CORE
      else
        warn "some features will not work correctly without the above tools"
      fi
    fi

    # ── font deps (FreeBSD) ───────────────────────────────────────────────────
    # foot.ini uses Spleen 8x16 and Symbols NerdFont Mono; check via fc-list.
    if [ "$PLATFORM" = "freebsd" ]; then
      printf '\n  checking fonts...\n\n'
      MISSING_FONTS=""

      if command -v fc-list >/dev/null 2>&1; then
        check_font() {
          # check_font "grep pattern" "display name" "pkg if missing"
          if fc-list | grep -qi "$1"; then
            ok "$2 found"
          else
            warn "$2 not found — required by foot.ini"
            MISSING_FONTS="$MISSING_FONTS $3"
          fi
        }
        check_font "spleen" "Spleen" spleen
        # nerd-fonts is the FreeBSD port; covers all Nerd Font families
        check_font "symbols nerd font" "Symbols Nerd Font Mono" nerd-fonts
      else
        warn "fc-list not available — skipping font check (install fontconfig)"
      fi

      if [ -n "$MISSING_FONTS" ]; then
        printf '\n'
        if prompt_yn "install missing fonts now?" y; then
          # shellcheck disable=SC2086
          install_pkg $MISSING_FONTS
        else
          warn "foot terminal will not render correctly without the above fonts"
        fi
      fi
    fi

    # ── optional deps ─────────────────────────────────────────────────────────
    printf '\n  checking optional dependencies...\n\n'

    if ! check_cmd notify-send "$(pkg_name terminal-notifier libnotify libnotify-bin) — desktop notifications"; then
      warn "desktop notifications will fallback to stdout"
    fi

    if ! check_cmd magick "" && ! check_cmd convert ""; then
      warn "ImageMagick not found — map overlays will be skipped"
      info "to install: $(pkg_name 'brew install imagemagick' 'pkg install ImageMagick7' 'apt-get install imagemagick')"
    fi

    # bat on non-FreeBSD is optional; clue falls back to cat
    if [ "$PLATFORM" != "freebsd" ]; then
      if ! check_cmd bat "$(pkg_name bat bat bat) — syntax-highlighted cheatsheet viewer"; then
        warn "clue alias will fall back to cat"
      fi
    fi

    # ── dev tools (optional) ──────────────────────────────────────────────────
    # these tools are only needed when hacking on the shell scripts themselves.
    # not required for normal dotfiles use.
    if prompt_yn "install shell dev tools (shellchecks, shfmt, bats-core)?" n; then
      printf '\n    checking shell dev tools...\n\n'
      MISSING_DEV=""
      _pkg="$(pkg_name shellcheck hs-ShellCheck shellcheck)"
      check_cmd shellchech "$_pkg" || MISSING_DEV="$MISSING_DEV $_pkg"
      _pkg="$(pkg_name shfmt shfmt shfmt)"
      check_cmd shfmt "$_pkg" || MISSING_DEV="$MISSING_DEV $_pkg"
      _pkg="$(pkg_name bats-core bats-core bats-core)"
      check_cmd bats "$_pkg" || MISSING_DEV="$MISSING_DEV $_pkg"
      if [ -n "$MISSING_DEV" ]; then
        printf '\n'
        # shellcheck disable=SC2086   # word-split is intentional — space-delimited pkg list
        install_pkg $MISSING_DEV
      fi
    fi
}

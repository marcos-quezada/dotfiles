# .git-worktree-functions.zsh — zsh layer on top of gwt.sh
#
# sources the POSIX sh core (gwt.sh) which provides all command logic, then
# overrides with zsh-specific behaviour:
#   - colour print helpers
#   - _gwt_hook_post_add  (direnv, pnpm, generate-*, push, open editors)
#   - _gwt_hook_post_rm   (no-op override)
#   - _gwt_pr             (gh CLI)
#   - gwt dispatcher extended with pr)
#   - tab completions
#
# commands:
#   gwt add   <branch> [base]  — create worktree, install deps, build, open editors
#   gwt rm    <branch>         — remove worktree, prompt to delete local branch
#   gwt ls                     — list worktrees
#   gwt go    <query>          — cd into first matching worktree
#   gwt clean                  — remove merged/gone worktrees
#   gwt pr    [branch]         — open or create a GitHub PR for the branch

# ── core ──────────────────────────────────────────────────────────────────────
# shellcheck disable=SC1090  # dynamic path resolved at runtime
. ~/.config/sh/gwt.sh

# ── colour print overrides ────────────────────────────────────────────────────
# redefine the plain printf versions from gwt.sh with zsh colour variants.
_gwt_info() { print -P "%F{cyan}[gwt]%f $*" }
_gwt_ok()   { print -P "%F{green}[gwt ✓]%f $*" }
_gwt_warn() { print -P "%F{yellow}[gwt !]%f $*" >&2 }
_gwt_err()  { print -P "%F{red}[gwt ✗]%f $*" >&2 }

# ── editor helper (zsh-only) ──────────────────────────────────────────────────
# opens IDEA and/or VSCode in the background if available.
_gwt_open_editor() {
    local path="$1"
    if command -v idea &>/dev/null; then
        _gwt_info "opening in IntelliJ IDEA..."
        idea "${path}" &
    fi
    if command -v code &>/dev/null; then
        _gwt_info "opening in VS Code..."
        code "${path}" &
    fi
}

# ── post-add hook override ────────────────────────────────────────────────────
# redefines the no-op stub from gwt.sh with full project automation.
# called by _gwt_add after cd into the new worktree.
# $1 = branch name, $2 = worktree path
_gwt_hook_post_add() {
    local branch="$1"
    local wt_path="$2"

    # direnv: allow at bare root — inherited by all worktrees beneath it
    local bare_root
    bare_root="$(_gwt_bare_root 2>/dev/null)"
    direnv allow "${bare_root}" 2>/dev/null && _gwt_info "direnv allowed (bare root)."

    # pnpm install if package.json present
    if [[ -f "package.json" ]]; then
        _gwt_info "installing dependencies with pnpm..."
        pnpm install --frozen-lockfile 2>/dev/null || pnpm install
        _gwt_ok "pnpm install done."
    fi

    # run any generate-routes / icons / generate-i18n scripts that exist
    if [[ -f "package.json" ]]; then
        local scripts
        scripts="$(python3 -c "import json,sys; d=json.load(open('package.json')); print(' '.join(d.get('scripts',{}).keys()))" 2>/dev/null)"
        for step in "generate-routes" "icons" "generate-i18n"; do
            if echo "${scripts}" | grep -qw "${step}"; then
                _gwt_info "running pnpm ${step}..."
                pnpm run "${step}" && _gwt_ok "${step} done." || _gwt_warn "${step} failed (continuing)."
            fi
        done
    fi

    # push new branch to origin
    _gwt_info "pushing branch '${branch}' to origin..."
    git push --set-upstream origin "${branch}" 2>/dev/null \
        && _gwt_ok "branch pushed to origin." \
        || _gwt_warn "push failed (branch may already exist remotely)."

    _gwt_open_editor "${wt_path}"
}

# ── post-rm hook override ─────────────────────────────────────────────────────
# no additional cleanup needed after removal; keep as explicit no-op.
_gwt_hook_post_rm() { : }

# ── gwt pr ────────────────────────────────────────────────────────────────────
# open or create a GitHub PR for the branch.
_gwt_pr() {
    local branch="${1}"

    local bare_root
    bare_root="$(_gwt_bare_root)" || {
        _gwt_err "not inside a bare-worktree repository."
        return 1
    }

    if [[ -z "${branch}" ]]; then
        branch="$(git -C "${PWD}" branch --show-current 2>/dev/null)"
    fi

    if [[ -z "${branch}" ]]; then
        _gwt_err "usage: gwt pr <branch>  (or run from inside a worktree)"
        return 1
    fi

    if ! command -v gh &>/dev/null; then
        _gwt_err "'gh' CLI not found — install with: brew install gh"
        return 1
    fi

    local pr_url
    pr_url="$(gh pr view "${branch}" --json url -q .url 2>/dev/null)"

    if [[ -n "${pr_url}" ]]; then
        _gwt_info "PR already exists: ${pr_url}"
        gh pr view "${branch}" --web
    else
        _gwt_info "creating PR for branch '${branch}'..."
        gh pr create --base main --head "${branch}" --fill --web
    fi
}

# ── dispatcher (extends gwt from gwt.sh with pr) ──────────────────────────────
gwt() {
    local subcommand="${1}"
    shift 2>/dev/null
    case "${subcommand}" in
        pr) _gwt_pr "$@" ;;
        *)
            # delegate everything else to the POSIX dispatcher
            # call the function-level logic directly to preserve zsh overrides
            case "${subcommand}" in
                add)   _gwt_add   "$@" ;;
                rm)    _gwt_rm    "$@" ;;
                ls)    _gwt_ls         ;;
                go)    _gwt_go    "$@" ;;
                clean) _gwt_clean      ;;
                *)
                    print -P "
%F{cyan}gwt%f — git worktree workflow helper

%B%F{white}usage:%f%b
  %F{green}gwt add%f   <branch> [base]   create worktree, install deps, build, push, open editors
  %F{green}gwt rm%f    <branch>           remove worktree (prompt to delete local branch)
  %F{green}gwt ls%f                       list all worktrees
  %F{green}gwt go%f    <query>            cd into first matching worktree
  %F{green}gwt clean%f                    remove merged/gone worktrees
  %F{green}gwt pr%f    [branch]           open or create GitHub PR for the branch

%B%F{white}examples:%f%b
  gwt add UAS-1234_my-feature          # new branch from main
  gwt add UAS-1234_my-feature develop  # new branch from develop
  gwt go  1234                         # jump into UAS-1234_* worktree
  gwt rm  UAS-1234_my-feature
  gwt clean
"
                    ;;
            esac
            ;;
    esac
}

# ── tab completions ───────────────────────────────────────────────────────────
_gwt_completions() {
    local -a subcommands worktrees
    subcommands=(add rm ls go clean pr)

    if [[ ${CURRENT} -eq 2 ]]; then
        _describe 'subcommand' subcommands
    elif [[ ${CURRENT} -ge 3 && ( "${words[2]}" == "rm" || "${words[2]}" == "go" || "${words[2]}" == "pr" ) ]]; then
        local bare_root
        bare_root="$(_gwt_bare_root 2>/dev/null)"
        if [[ -n "${bare_root}" ]]; then
            local wt_list
            while IFS= read -r line; do
                local dir="${line#worktree }"
                [[ "${dir}" == "${bare_root}" ]] && continue
                worktrees+=("${dir##*/}")
            done < <(git -C "${bare_root}" worktree list --porcelain 2>/dev/null | grep "^worktree ")
            _describe 'worktree' worktrees
        fi
    fi
}

compdef _gwt_completions gwt

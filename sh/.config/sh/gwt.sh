# shellcheck shell=sh
# gwt.sh — git bare-worktree helpers for /bin/sh (FreeBSD)
# source from .shrc:  . ~/.config/sh/gwt.sh
#
# commands:
#   gwt add  <branch> [base]  — fetch, create worktree, cd, open $EDITOR
#   gwt rm   <branch>         — remove worktree, prune, prompt to delete branch
#   gwt ls                    — list worktrees with branch and short HEAD
#   gwt go   <query>          — cd into first worktree matching query
#   gwt clean                 — remove worktrees for merged/gone branches

# ── internal helpers ──────────────────────────────────────────────────────────

# walk up from $PWD looking for the bare-worktree hub:
#   hub/
#     .bare/   ← GIT_DIR
#     .git     ← contains "gitdir: ./.bare"
#     main/
#     feature-x/
#
# also handles being inside a linked worktree — .git is a file pointing into
# .bare/worktrees/<name>; we strip everything from ".bare" onward to find hub.
_gwt_bare_root() {
    _gd="$PWD"
    while [ "$_gd" != "/" ]; do
        if [ -d "$_gd/.bare" ] && [ -f "$_gd/.git" ]; then
            echo "$_gd"
            unset _gd
            return 0
        fi
        if [ -f "$_gd/.git" ]; then
            # read the gitdir pointer and strip the "gitdir: " prefix
            _ptr=$(sed 's/^gitdir: //' "$_gd/.git" 2>/dev/null)
            case "$_ptr" in
                */.bare/worktrees/*)
                    # resolve to absolute path then strip from /.bare onward
                    _abs=$(cd "$_gd" && cd "$(dirname "$_ptr")/../../../.." 2>/dev/null && pwd)
                    if [ -d "$_abs/.bare" ]; then
                        echo "$_abs"
                        unset _gd _ptr _abs
                        return 0
                    fi
                    ;;
            esac
            unset _ptr
        fi
        _gd=$(dirname "$_gd")
    done
    unset _gd
    return 1
}

_gwt_info()  { printf '[gwt] %s\n'   "$*"; }
_gwt_ok()    { printf '[gwt ✓] %s\n' "$*"; }
_gwt_warn()  { printf '[gwt !] %s\n' "$*" >&2; }
_gwt_err()   { printf '[gwt ✗] %s\n' "$*" >&2; }

# ── gwt add ───────────────────────────────────────────────────────────────────
# fetch, create worktree from base, cd into it, open $EDITOR.
# if the worktree directory already exists, jump straight into it.
_gwt_add() {
    _branch="$1"
    _base="${2:-main}"

    if [ -z "$_branch" ]; then
        _gwt_err "usage: gwt add <branch> [base]"
        unset _branch _base
        return 1
    fi

    _root=$(_gwt_bare_root) || {
        _gwt_err "not inside a bare-worktree repository"
        unset _branch _base
        return 1
    }

    _wt="$_root/$_branch"

    # already exists — just jump in
    if [ -d "$_wt" ]; then
        _gwt_info "worktree already exists — jumping in"
        cd "$_wt" || { unset _branch _base _root _wt; return 1; }
        unset _branch _base _root _wt
        return 0
    fi

    _gwt_info "fetching origin..."
    git -C "$_root/.bare" fetch --prune origin

    _gwt_info "creating worktree '$_branch' from '$_base'..."

    # local branch already exists
    if git -C "$_root/.bare" show-ref --verify --quiet "refs/heads/$_branch"; then
        git -C "$_root" worktree add "$_wt" "$_branch"
    # remote tracking branch exists — check it out tracking origin
    elif git -C "$_root/.bare" show-ref --verify --quiet "refs/remotes/origin/$_branch"; then
        git -C "$_root" worktree add --track -b "$_branch" "$_wt" "origin/$_branch"
    # brand new branch from base
    else
        git -C "$_root" worktree add -b "$_branch" "$_wt" "$_base"
    fi

    cd "$_wt" || { unset _branch _base _root _wt; return 1; }
    _gwt_ok "worktree '$_branch' ready at: $_wt"

    # open in $EDITOR — falls back to vi if EDITOR is unset
    ${EDITOR:-vi} .

    unset _branch _base _root _wt
}

# ── gwt rm ────────────────────────────────────────────────────────────────────
# remove the worktree, prune stale entries, ask to delete the local branch.
_gwt_rm() {
    _branch="$1"
    if [ -z "$_branch" ]; then
        _gwt_err "usage: gwt rm <branch>"
        return 1
    fi

    _root=$(_gwt_bare_root) || {
        _gwt_err "not inside a bare-worktree repository"
        unset _branch
        return 1
    }

    _wt="$_root/$_branch"
    if [ ! -d "$_wt" ]; then
        _gwt_err "worktree not found: $_wt"
        unset _branch _root _wt
        return 1
    fi

    # move out first if we are inside the target worktree
    case "$PWD" in
        "$_wt"*)
            _gwt_info "leaving '$_branch' first..."
            cd "$_root" || { unset _branch _root _wt; return 1; }
            ;;
    esac

    _gwt_info "removing worktree '$_branch'..."
    if git -C "$_root" worktree remove --force "$_wt"; then
        _gwt_ok "worktree removed"
    else
        _gwt_err "git worktree remove failed"
        unset _branch _root _wt
        return 1
    fi

    git -C "$_root" worktree prune

    printf '[gwt] delete local branch "%s"? [y/N] ' "$_branch"
    read -r _reply
    case "$_reply" in
        [Yy])
            if git -C "$_root/.bare" branch -D "$_branch"; then
                _gwt_ok "local branch deleted"
            else
                _gwt_warn "could not delete branch (may already be gone)"
            fi
            ;;
    esac

    unset _branch _root _wt _reply
}

# ── gwt ls ────────────────────────────────────────────────────────────────────
_gwt_ls() {
    _root=$(_gwt_bare_root) || {
        _gwt_err "not inside a bare-worktree repository"
        return 1
    }

    printf '\nWorktrees in: %s\n\n' "$_root"
    printf '%-55s %-40s %s\n' "PATH" "BRANCH" "HEAD"
    printf '%-55s %-40s %s\n' \
        "-------------------------------------------------------" \
        "----------------------------------------" \
        "-------"

    git -C "$_root" worktree list --porcelain | awk '
        /^worktree / { wt = $2 }
        /^branch /   { branch = substr($0, index($0, $2)); gsub("refs/heads/", "", branch) }
        /^HEAD /     { head = substr($2, 1, 7) }
        /^$/ {
            if (wt != "") {
                status = (branch == "") ? "(detached)" : branch
                printf "%-55s %-40s %s\n", wt, status, head
                wt = ""; branch = ""; head = ""
            }
        }
    '
    printf '\n'
    unset _root
}

# ── gwt go ────────────────────────────────────────────────────────────────────
# cd into the first worktree whose path contains the query string.
_gwt_go() {
    _query="$1"
    if [ -z "$_query" ]; then
        _gwt_err "usage: gwt go <query>"
        return 1
    fi

    _root=$(_gwt_bare_root) || {
        _gwt_err "not inside a bare-worktree repository"
        unset _query
        return 1
    }

    _match=""
    while IFS= read -r _line; do
        _dir="${_line#worktree }"
        [ "$_dir" = "$_root" ] && continue
        case "$_dir" in
            *"$_query"*)
                # take the first match; report ambiguity if more than one
                if [ -z "$_match" ]; then
                    _match="$_dir"
                else
                    _gwt_warn "multiple matches — taking first: $_match"
                    break
                fi
                ;;
        esac
    done << EOF
$(git -C "$_root" worktree list --porcelain | grep "^worktree ")
EOF

    if [ -z "$_match" ]; then
        _gwt_err "no worktree matching '$_query'"
        unset _query _root _match _line _dir
        return 1
    fi

    _gwt_info "→ $_match"
    cd "$_match" || { unset _query _root _match _line _dir; return 1; }
    unset _query _root _match _line _dir
}

# ── gwt clean ─────────────────────────────────────────────────────────────────
# remove worktrees for branches that are merged into main or whose remote is gone.
_gwt_clean() {
    _root=$(_gwt_bare_root) || {
        _gwt_err "not inside a bare-worktree repository"
        return 1
    }

    _gwt_info "fetching and pruning origin..."
    git -C "$_root/.bare" fetch --prune origin

    # collect merged branches (excluding main itself)
    _merged=$(git -C "$_root/.bare" branch --merged main 2>/dev/null \
        | sed 's/^[* ]*//' \
        | grep -v '^main$' \
        | grep -v '^$')

    # collect branches whose remote tracking ref is gone
    _gone=$(git -C "$_root/.bare" branch -vv 2>/dev/null \
        | grep '\[.*: gone\]' \
        | sed 's/^[* ]*//' \
        | awk '{print $1}')

    # combine and deduplicate with a portable approach
    _candidates=$(printf '%s\n%s\n' "$_merged" "$_gone" \
        | grep -v '^$' \
        | sort -u)

    if [ -z "$_candidates" ]; then
        _gwt_ok "nothing to clean up"
        unset _root _merged _gone _candidates
        return 0
    fi

    _gwt_info "branches eligible for cleanup:"
    printf '%s\n' "$_candidates" | while IFS= read -r _b; do
        printf '  • %s\n' "$_b"
    done

    printf '\n[gwt] remove all of the above worktrees and branches? [y/N] '
    read -r _reply
    case "$_reply" in
        [Yy]) ;;
        *) _gwt_info "aborted"; unset _root _merged _gone _candidates _reply; return 0 ;;
    esac

    printf '%s\n' "$_candidates" | while IFS= read -r _b; do
        _wt="$_root/$_b"
        if [ -d "$_wt" ]; then
            case "$PWD" in
                "$_wt"*)
                    _gwt_info "leaving '$_b' first..."
                    cd "$_root" || return 1
                    ;;
            esac
            if git -C "$_root" worktree remove --force "$_wt"; then
                _gwt_ok "removed worktree: $_b"
            else
                _gwt_warn "could not remove worktree: $_b"
            fi
        fi
        if git -C "$_root/.bare" branch -D "$_b" 2>/dev/null; then
            _gwt_ok "deleted local branch: $_b"
        else
            _gwt_warn "branch '$_b' not found locally (already cleaned)"
        fi
    done

    git -C "$_root" worktree prune
    _gwt_ok "cleanup complete"
    unset _root _merged _gone _candidates _reply _wt _b
}

# ── dispatcher ────────────────────────────────────────────────────────────────
gwt() {
    _sub="$1"
    shift 2>/dev/null
    case "$_sub" in
        add)   _gwt_add   "$@" ;;
        rm)    _gwt_rm    "$@" ;;
        ls)    _gwt_ls         ;;
        go)    _gwt_go    "$@" ;;
        clean) _gwt_clean      ;;
        *)
            printf 'gwt — git worktree helper\n\n'
            printf 'usage:\n'
            # shellcheck disable=SC2016  # $EDITOR is literal help text, not an expansion
            printf '  gwt add   <branch> [base]   create worktree, cd, open $EDITOR\n'
            printf '  gwt rm    <branch>           remove worktree (prompt to delete branch)\n'
            printf '  gwt ls                       list all worktrees\n'
            printf '  gwt go    <query>            cd into first matching worktree\n'
            printf '  gwt clean                    remove merged/gone worktrees\n'
            printf '\nexamples:\n'
            printf '  gwt add feature-x            # new branch from main\n'
            printf '  gwt add feature-x develop    # new branch from develop\n'
            printf '  gwt go  feature              # jump into first matching worktree\n'
            printf '  gwt rm  feature-x\n'
            printf '  gwt clean\n'
            ;;
    esac
    # preserve the subcommand's exit code — unset must not clobber it
    _gwt_rc=$?
    unset _sub
    return $_gwt_rc
}

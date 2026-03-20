#
# ~/.git-worktree-functions.zsh
#
# Git worktree workflow helpers for bare-repo + linked-worktrees setup.
#
# Functions:
#   gwt add   <branch> [base]  — create worktree, install deps, build, open editors, push
#   gwt rm    <branch>         — remove worktree and delete local branch
#   gwt ls                     — list all worktrees with their branch and status
#   gwt go    <branch>         — cd into a worktree by branch/dir name (fuzzy)
#   gwt clean                  — remove all worktrees whose branch is merged/gone
#   gwt pr    <branch>         — open GitHub PR for the worktree branch (gh cli)
#
# Usage:
#   gwt add UAS-1234_my-feature        # branch from current HEAD (main)
#   gwt add UAS-1234_my-feature main   # branch explicitly from main
#   gwt rm  UAS-1234_my-feature
#   gwt ls
#   gwt go  1234                       # fuzzy: matches UAS-1234_*
#   gwt clean
#

# ─────────────────────────────────────────────────────────────────────────────
# Internal helpers
# ─────────────────────────────────────────────────────────────────────────────

# Detect the bare repo root (the directory that contains .bare/ and .git file)
_gwt_bare_root() {
  local dir="${PWD}"
  while [[ "${dir}" != "/" ]]; do
    # Pattern 1: directory has a .bare/ subdir  (our bare-worktree layout)
    if [[ -d "${dir}/.bare" && -f "${dir}/.git" ]]; then
      echo "${dir}"
      return 0
    fi
    # Pattern 2: we are already inside a linked worktree — .git is a file
    # pointing into .bare/worktrees/<name>; walk up to find the hub
    if [[ -f "${dir}/.git" ]]; then
      local gitdir
      gitdir="$(< "${dir}/.git")"
      gitdir="${gitdir#gitdir: }"
      # If it points into a .bare/worktrees/... path, resolve the hub
      local hub
      hub="$(python3 -c "import os,sys; p=os.path.normpath(os.path.join('${dir}', '${gitdir}')); parts=p.split(os.sep); i=next((j for j,x in enumerate(parts) if x=='.bare'), -1); print(os.sep.join(parts[:i+1]) if i>=0 else '') " 2>/dev/null)"
      if [[ -n "${hub}" ]]; then
        echo "$(dirname "${hub}")"
        return 0
      fi
    fi
    dir="$(dirname "${dir}")"
  done
  return 1
}

# Print a coloured message
_gwt_info()    { print -P "%F{cyan}[gwt]%f $*" }
_gwt_ok()      { print -P "%F{green}[gwt ✓]%f $*" }
_gwt_warn()    { print -P "%F{yellow}[gwt !]%f $*" >&2 }
_gwt_err()     { print -P "%F{red}[gwt ✗]%f $*" >&2 }

# Detect which editor launchers are available (idea → code → fallback)
_gwt_open_editor() {
  local path="$1"
  if command -v idea &>/dev/null; then
    _gwt_info "Opening in IntelliJ IDEA…"
    idea "${path}" &
  fi
  if command -v code &>/dev/null; then
    _gwt_info "Opening in VS Code…"
    code "${path}" &
  fi
}

# Detect the node flake .envrc at the bare root and return its content
_gwt_envrc_content() {
  local bare_root="$1"
  if [[ -f "${bare_root}/.envrc" ]]; then
    cat "${bare_root}/.envrc"
  else
    echo "# Add your direnv config here"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# gwt add  <branch> [base-branch]
# ─────────────────────────────────────────────────────────────────────────────
_gwt_add() {
  local branch="${1}"
  local base="${2:-main}"

  if [[ -z "${branch}" ]]; then
    _gwt_err "Usage: gwt add <branch-name> [base-branch]"
    return 1
  fi

  local bare_root
  bare_root="$(_gwt_bare_root)" || {
    _gwt_err "Not inside a bare-worktree repository. cd into your project first."
    return 1
  }

  local worktree_path="${bare_root}/${branch}"

  if [[ -d "${worktree_path}" ]]; then
    _gwt_warn "Directory '${worktree_path}' already exists."
    _gwt_info "Jumping into it instead…"
    cd "${worktree_path}"
    return 0
  fi

  # ── 1. Fetch latest so base is up to date ──────────────────────────────────
  _gwt_info "Fetching origin…"
  git -C "${bare_root}/.bare" fetch --prune origin

  # ── 2. Create the worktree ─────────────────────────────────────────────────
  _gwt_info "Creating worktree '${branch}' from '${base}'…"

  # Does a local branch already exist?
  if git -C "${bare_root}/.bare" show-ref --verify --quiet "refs/heads/${branch}"; then
    git -C "${bare_root}" worktree add "${worktree_path}" "${branch}"
  else
    # Does a remote tracking branch exist?
    if git -C "${bare_root}/.bare" show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
      git -C "${bare_root}" worktree add --track -b "${branch}" "${worktree_path}" "origin/${branch}"
    else
      # Brand new branch
      git -C "${bare_root}" worktree add -b "${branch}" "${worktree_path}" "${base}"
    fi
  fi

  # ── 3. Allow direnv at the bare root (inherits down into all worktrees) ───
  # direnv walks up the directory tree, so a single .envrc at the bare root
  # is picked up by every worktree beneath it — no per-worktree copy needed.
  direnv allow "${bare_root}" 2>/dev/null && _gwt_info "direnv allowed (bare root)."

  # ── 4. cd into the worktree ───────────────────────────────────────────────
  cd "${worktree_path}"

  # ── 5. Install dependencies ────────────────────────────────────────────────
  if [[ -f "package.json" ]]; then
    _gwt_info "Installing dependencies with pnpm…"
    pnpm install --frozen-lockfile 2>/dev/null || pnpm install
    _gwt_ok "pnpm install done."
  fi

  # ── 6. Run build prerequisites (wireit: routes, icons, i18n) ──────────────
  if [[ -f "package.json" ]]; then
    local scripts
    scripts="$(python3 -c "import json,sys; d=json.load(open('package.json')); print(' '.join(d.get('scripts',{}).keys()))" 2>/dev/null)"

    # Only run if the relevant pnpm scripts exist
    for step in "generate-routes" "icons" "generate-i18n"; do
      if echo "${scripts}" | grep -qw "${step}"; then
        _gwt_info "Running pnpm ${step}…"
        pnpm run "${step}" && _gwt_ok "${step} done." || _gwt_warn "${step} failed (continuing)."
      fi
    done
  fi

  # ── 7. Push the new branch to origin ──────────────────────────────────────
  _gwt_info "Pushing branch '${branch}' to origin…"
  git push --set-upstream origin "${branch}" 2>/dev/null \
    && _gwt_ok "Branch pushed to origin." \
    || _gwt_warn "Push failed (maybe branch already exists remotely — that's fine)."

  # ── 8. Open editors ────────────────────────────────────────────────────────
  _gwt_open_editor "${worktree_path}"

  _gwt_ok "Worktree '${branch}' ready at: ${worktree_path}"
}

# ─────────────────────────────────────────────────────────────────────────────
# gwt rm  <branch>
# ─────────────────────────────────────────────────────────────────────────────
_gwt_rm() {
  local branch="${1}"
  if [[ -z "${branch}" ]]; then
    _gwt_err "Usage: gwt rm <branch-name>"
    return 1
  fi

  local bare_root
  bare_root="$(_gwt_bare_root)" || {
    _gwt_err "Not inside a bare-worktree repository."
    return 1
  }

  local worktree_path="${bare_root}/${branch}"

  if [[ ! -d "${worktree_path}" ]]; then
    _gwt_err "Worktree directory not found: ${worktree_path}"
    return 1
  fi

  # Safety: don't remove the worktree we're currently in
  if [[ "${PWD}" == "${worktree_path}"* ]]; then
    _gwt_info "You are inside '${branch}'. Moving to bare root first…"
    cd "${bare_root}"
  fi

  _gwt_info "Removing worktree '${branch}'…"
  git -C "${bare_root}" worktree remove --force "${worktree_path}" \
    && _gwt_ok "Worktree removed." \
    || { _gwt_err "git worktree remove failed."; return 1; }

  # Prune stale worktree entries
  git -C "${bare_root}" worktree prune

  # Ask before deleting the local branch
  print -n "%F{yellow}[gwt]%f Delete local branch '${branch}'? [y/N] "
  read -r reply
  if [[ "${reply}" =~ ^[Yy]$ ]]; then
    git -C "${bare_root}/.bare" branch -D "${branch}" \
      && _gwt_ok "Local branch deleted." \
      || _gwt_warn "Could not delete branch (may have already been deleted)."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# gwt ls
# ─────────────────────────────────────────────────────────────────────────────
_gwt_ls() {
  local bare_root
  bare_root="$(_gwt_bare_root)" || {
    _gwt_err "Not inside a bare-worktree repository."
    return 1
  }

  print -P "\n%F{cyan}Worktrees in: ${bare_root}%f\n"
  printf "%-55s %-40s %s\n" "PATH" "BRANCH" "STATUS"
  printf "%-55s %-40s %s\n" "────────────────────────────────────────────────────" "────────────────────────────────────" "──────────"

  git -C "${bare_root}" worktree list --porcelain | awk '
    /^worktree / { wt=$2 }
    /^branch /   { branch=substr($0, index($0,$2)); gsub("refs/heads/","",branch) }
    /^HEAD /     { head=substr($2,1,7) }
    /^$/         {
      if (wt != "") {
        status = (branch == "") ? "(detached)" : branch
        printf "%-55s %-40s %s\n", wt, status, head
        wt=""; branch=""; head=""
      }
    }
  '
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# gwt go  <fuzzy-branch-name>
# ─────────────────────────────────────────────────────────────────────────────
_gwt_go() {
  local query="${1}"
  if [[ -z "${query}" ]]; then
    _gwt_err "Usage: gwt go <branch-or-pattern>"
    return 1
  fi

  local bare_root
  bare_root="$(_gwt_bare_root)" || {
    _gwt_err "Not inside a bare-worktree repository."
    return 1
  }

  # Collect worktree dirs (exclude the bare root itself)
  local matches=()
  while IFS= read -r line; do
    local dir="${line#worktree }"
    [[ "${dir}" == "${bare_root}" ]] && continue
    [[ "${dir}" == *"${query}"* ]] && matches+=("${dir}")
  done < <(git -C "${bare_root}" worktree list --porcelain | grep "^worktree ")

  if [[ ${#matches[@]} -eq 0 ]]; then
    _gwt_err "No worktree matching '${query}' found."
    return 1
  elif [[ ${#matches[@]} -eq 1 ]]; then
    _gwt_info "→ ${matches[1]}"
    cd "${matches[1]}"
  else
    _gwt_info "Multiple matches — pick one:"
    select chosen in "${matches[@]}"; do
      [[ -n "${chosen}" ]] && cd "${chosen}" && break
    done
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# gwt clean  — remove worktrees for merged/deleted remote branches
# ─────────────────────────────────────────────────────────────────────────────
_gwt_clean() {
  local bare_root
  bare_root="$(_gwt_bare_root)" || {
    _gwt_err "Not inside a bare-worktree repository."
    return 1
  }

  _gwt_info "Fetching and pruning origin…"
  git -C "${bare_root}/.bare" fetch --prune origin

  # Merged into main
  local merged_branches=()
  while IFS= read -r branch; do
    branch="${branch//[[:space:]]/}"
    branch="${branch#\*}"   # strip leading * for current branch
    [[ -z "${branch}" || "${branch}" == "main" ]] && continue
    merged_branches+=("${branch}")
  done < <(git -C "${bare_root}/.bare" branch --merged main 2>/dev/null)

  # Remote-gone branches (fetch --prune sets them as "gone")
  local gone_branches=()
  while IFS= read -r line; do
    if [[ "${line}" == *": gone]"* ]]; then
      local b="${line%%[*}"
      b="${b//[[:space:]]/}"
      gone_branches+=("${b}")
    fi
  done < <(git -C "${bare_root}/.bare" branch -vv 2>/dev/null)

  local candidates=("${merged_branches[@]}" "${gone_branches[@]}")
  # Deduplicate
  local seen=()
  local unique=()
  for c in "${candidates[@]}"; do
    if [[ ! " ${seen[*]} " =~ " ${c} " ]]; then
      seen+=("${c}")
      unique+=("${c}")
    fi
  done

  if [[ ${#unique[@]} -eq 0 ]]; then
    _gwt_ok "Nothing to clean up."
    return 0
  fi

  _gwt_info "Branches eligible for cleanup:"
  for b in "${unique[@]}"; do
    echo "  • ${b}"
  done

  print -n "\n%F{yellow}[gwt]%f Remove all of the above worktrees and branches? [y/N] "
  read -r reply
  [[ ! "${reply}" =~ ^[Yy]$ ]] && { _gwt_info "Aborted."; return 0; }

  for branch in "${unique[@]}"; do
    local wt_path="${bare_root}/${branch}"
    if [[ -d "${wt_path}" ]]; then
      if [[ "${PWD}" == "${wt_path}"* ]]; then
        _gwt_info "Leaving '${branch}' first…"
        cd "${bare_root}"
      fi
      git -C "${bare_root}" worktree remove --force "${wt_path}" \
        && _gwt_ok "Removed worktree: ${branch}" \
        || _gwt_warn "Could not remove worktree: ${branch}"
    fi
    git -C "${bare_root}/.bare" branch -D "${branch}" 2>/dev/null \
      && _gwt_ok "Deleted local branch: ${branch}" \
      || _gwt_warn "Branch '${branch}' not found locally (already cleaned)."
  done

  git -C "${bare_root}" worktree prune
  _gwt_ok "Cleanup complete."
}

# ─────────────────────────────────────────────────────────────────────────────
# gwt pr  <branch>   — open or create a GitHub PR for the branch
# ─────────────────────────────────────────────────────────────────────────────
_gwt_pr() {
  local branch="${1}"

  local bare_root
  bare_root="$(_gwt_bare_root)" || {
    _gwt_err "Not inside a bare-worktree repository."
    return 1
  }

  if [[ -z "${branch}" ]]; then
    # Infer branch from cwd if we are inside a worktree
    branch="$(git -C "${PWD}" branch --show-current 2>/dev/null)"
  fi

  if [[ -z "${branch}" ]]; then
    _gwt_err "Usage: gwt pr <branch-name>  (or run from inside a worktree)"
    return 1
  fi

  if ! command -v gh &>/dev/null; then
    _gwt_err "'gh' CLI not found. Install it with: nix-env -iA nixpkgs.gh"
    return 1
  fi

  local wt_path="${bare_root}/${branch}"
  [[ ! -d "${wt_path}" ]] && wt_path="${PWD}"

  # If PR already exists, open it; otherwise create it
  local pr_url
  pr_url="$(gh pr view "${branch}" --json url -q .url 2>/dev/null)"

  if [[ -n "${pr_url}" ]]; then
    _gwt_info "PR already exists: ${pr_url}"
    gh pr view "${branch}" --web
  else
    _gwt_info "Creating PR for branch '${branch}'…"
    gh pr create --base main --head "${branch}" --fill --web
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# gwt — main dispatcher
# ─────────────────────────────────────────────────────────────────────────────
gwt() {
  local subcommand="${1}"
  shift 2>/dev/null

  case "${subcommand}" in
    add)    _gwt_add "$@" ;;
    rm)     _gwt_rm "$@" ;;
    ls)     _gwt_ls "$@" ;;
    go)     _gwt_go "$@" ;;
    clean)  _gwt_clean "$@" ;;
    pr)     _gwt_pr "$@" ;;
    *)
      print -P "
%F{cyan}gwt%f — git worktree workflow helper

%B%F{white}Usage:%f%b
  %F{green}gwt add%f  <branch> [base]   Create worktree, install, build, push & open editors
  %F{green}gwt rm%f   <branch>           Remove worktree (and optionally the local branch)
  %F{green}gwt ls%f                      List all worktrees with branch and HEAD
  %F{green}gwt go%f   <query>            cd into a worktree (fuzzy match on name)
  %F{green}gwt clean%f                   Remove worktrees for merged/gone branches
  %F{green}gwt pr%f   [branch]           Open or create a GitHub PR for the branch

%B%F{white}Examples:%f%b
  gwt add UAS-1234_my-feature          # new branch from main
  gwt add UAS-1234_my-feature develop  # new branch from develop
  gwt go  1234                         # jump into UAS-1234_* worktree
  gwt rm  UAS-1234_my-feature
  gwt clean
"
      ;;
  esac
}

# Tab completion for gwt
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

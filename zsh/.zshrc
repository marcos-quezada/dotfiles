# .zshrc — macOS zsh config

# colors
unset LSCOLORS
export CLICOLOR=1
export CLICOLOR_FORCE=1

# don't require escaping globbing characters in zsh
unsetopt nomatch

# prompt
export PS1=$'\n'"%F{green}ℵ₀ %*%F %3~ %F{white}"$'\n'"λ❯ "

# path — homebrew, cargo, go, composer; rest inherited from .zprofile
export PATH="$HOME/.cargo/bin:$HOME/go/bin:$HOME/.composer/vendor/bin:$PATH"

# time output format (bash-style)
export TIMEFMT=$'\nreal\t%*E\nuser\t%*U\nsys\t%*S'

# homebrew — don't autoupdate on every invocation
export HOMEBREW_AUTO_UPDATE_SECS=604800

# composer
export COMPOSER_MEMORY_LIMIT=-1

# ── completions ───────────────────────────────────────────────────────────────
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list \
  'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' \
  'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*' \
  'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*' \
  'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*'

# ── history substring search ──────────────────────────────────────────────────
# requires zsh-history-substring-search (brew install zsh-history-substring-search)
_zsh_hss_path="$(brew --prefix 2>/dev/null)/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
if [ -f "$_zsh_hss_path" ]; then
  source "$_zsh_hss_path"
  bindkey "^[[A" history-substring-search-up
  bindkey "^[[B" history-substring-search-down
fi

# ── aliases ───────────────────────────────────────────────────────────────────
[ -f ~/.aliases ] && source ~/.aliases

# git
alias gs='git status'
alias gc='git commit'
alias gp='git pull --rebase'
alias gcam='git commit -am'
alias gl='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'

# ── functions ─────────────────────────────────────────────────────────────────

# sync a branch with upstream and push to origin
gsync() {
  if [ -z "$1" ]; then
    echo "usage: gsync <branch>"
    return 1
  fi
  git branch --list "$1" | grep -q . || { echo "branch $1 does not exist"; return 1; }
  git checkout "$1" && git pull upstream "$1" && git push origin "$1"
}

# run a docker container one-shot for testing ansible roles etc.
dockrun() {
  docker run -it "geerlingguy/docker-${1:-ubuntu1604}-ansible" /bin/bash
}

# enter a running container
denter() {
  if [ -z "$1" ]; then
    echo "usage: denter <container-id-or-name>"
    return 1
  fi
  docker exec -it "$1" bash
}

# remove a line from ~/.ssh/known_hosts by line number
knownrm() {
  case "$1" in
    ''|*[!0-9]*) echo "error: line number required" >&2; return 1 ;;
  esac
  sed -i '' "${1}d" ~/.ssh/known_hosts
}

# ── tool integrations ─────────────────────────────────────────────────────────
# mise — runtime version manager (replaces asdf)
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

# direnv
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# git worktree helpers
[ -f ~/.git-worktree-functions.zsh ] && source ~/.git-worktree-functions.zsh

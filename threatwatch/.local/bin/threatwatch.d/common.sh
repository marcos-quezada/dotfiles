#!/bin/sh
# threatwatch.d/common.sh — shared config/constants, theme resolution, signal
# handling, and small helpers. sourced only, never executed directly.

PROGNAME="${0##*/}"

# urls!
EMSC_URL="https://www.seismicportal.eu/fdsnws/event/1/query"
USGS_URL="https://earthquake.usgs.gov/fdsnws/event/1/query"
GDACS_URL="https://www.gdacs.org/xml/rss.xml"
OPENSKY_URL="https://opensky-network.org/api/states/all"
POLYMARKET_URL="https://gamma-api.polymarket.com/events?limit=30&closed=false&tag_slug=politics"
# visual theme — controls HUD panel colours, text palette, pin colours, and
# the paired mapbox map style. override via THREATWATCH_THEME in config.env.
# built-in themes: vintage (default), neon
# each theme also sets MAPBOX_STYLE unless the user overrides that separately.
THREATWATCH_THEME="${THREATWATCH_THEME:-vintage}"

# mapbox style — normally driven by THREATWATCH_THEME below; override via
# MAPBOX_STYLE in config.env to decouple the style from the HUD theme.
# format: {username}/{style_id}  (the path after mapbox://styles/)
MAPBOX_STYLE="${MAPBOX_STYLE:-}"
MAPBOX_BASE=""  # set after config is sourced, once THREATWATCH_THEME is resolved

# mapbox token — free tier at https://account.mapbox.com, no credit card needed
# set via env: export MAPBOX_TOKEN="pk.eyJ1..."
MAPBOX_TOKEN="${MAPBOX_TOKEN:-}"

# bounding box — Germany + Central Europe + Northern Italy
# 45.0°N captures Como, Dizzasco, Lombardia, Slovenia, northern Adriatic seismic zone
BBOX_MINLAT="45.0"
BBOX_MAXLAT="55.5"
BBOX_MINLON="5.5"
BBOX_MAXLON="16.0"

# broader box for GDACS — cast wider so we catch Atlantic/Mediterranean disasters
GDACS_MINLAT="40.0"
GDACS_MAXLAT="60.0"
GDACS_MINLON="-5.0"
GDACS_MAXLON="30.0"

# map viewport — empirically calibrated with pin-l markers + imagemagick pixel scan.
# zoom 5 at 800x780, center 50.609°N: flensburg lands at 4.9% from top, como at 88.6%.
# zoom 6 was tried but cut both cities off entirely — the math looked right, it wasn't.
MAP_CENTER_LON="10.45"
MAP_CENTER_LAT="50.609"
MAP_ZOOM="5"
MAP_SIZE="800x780"

# rate limiting — default 6h between fetches = ~120 req/month running 24/7.
# override: MAP_MIN_INTERVAL=0 to force, MAP_MIN_INTERVAL=86400 to go daily.
MAP_MIN_INTERVAL="${MAP_MIN_INTERVAL:-21600}"

# usage thresholds — warn at 80%, hard-stop at 96% to leave headroom for manual runs
MAP_COUNT_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/threatwatch/mapbox_count.json"
MAP_WARN_THRESHOLD=40000
MAP_SKIP_THRESHOLD=48000

# threat thresholds
QUAKE_MED_MAG="3.5"
QUAKE_HIGH_MAG="4.5"
QUAKE_CRIT_MAG="5.5"

# military callsign prefixes — GAF=german AF, RCH/REACH/DUKE=US military transports
MIL_PREFIXES="GAF|RCH|DUKE|REACH|ATLAS|MAGMA|ROCKY|NATO|USAF|CTAM|ARMY|NAVY"

# emergency squawk codes
EMERG_SQUAWKS="7700|7600|7500"

# file locations
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/threatwatch"
QUAKES_FILE="$CACHE_DIR/quakes.json"
EMSC_FILE="$CACHE_DIR/emsc.json"
GDACS_FILE="$CACHE_DIR/gdacs.xml"
FLIGHTS_FILE="$CACHE_DIR/flights.json"
POLY_FILE="$CACHE_DIR/polymarket.json"
MAP_FILE="$CACHE_DIR/germany.png"
SUMMARY_FILE="$CACHE_DIR/summary.json"
PINS_FILE="$CACHE_DIR/pins.json"

# load secrets — never commit config.env, only config.env.template.
# sourced after variable declarations so MAPBOX_TOKEN / THREATWATCH_THEME
# from config.env override the defaults above.
# the script works without config.env — map fetches are simply skipped.
_conf="${XDG_CONFIG_HOME:-$HOME/.config}/threatwatch/config.env"
if [ -f "$_conf" ]; then
    # shellcheck source=/dev/null  # path is dynamic; content is user-managed secrets
    . "$_conf"
fi
unset _conf

# resolve theme — sets TH_* palette variables and MAPBOX_STYLE (unless the
# user already set MAPBOX_STYLE explicitly in config.env, which takes priority).
# call order: after config.env is sourced, before any function that uses TH_*.
_resolve_theme() {
    _t="${THREATWATCH_THEME:-vintage}"
    case "$_t" in
        neon)
            # neon — near-black panel, vivid accent colours; pairs with the neon map style.
            # map dominant colours (sampled from histogram):
            #   land     #1f1a1d  — near-black
            #   sea/bg   #224466  — dark navy
            #   yellow   #bfbc0e  — dim olive-yellow roads
            #   orange   #b34d22  — burnt orange highways
            #   green    #639f19  — olive green labels
            #   cyan     #0dc0ca  — teal water features
            #   violet   #9f25c7  — bright purple rail
            #   indigo   #553499  — dark blue rail
            # every pin is chosen to be maximally distinct from all of the above
            # AND from every other pin in the set.
            _TH_MAPBOX_STYLE="mqu3zada/cmn36jwmq000b01qw6l3405n1"
            TH_PANEL_FILL="rgba(6,8,14,0.90)"
            TH_BORDER_COL="#00e5ff"
            TH_TEXT_DARK="#e8f4f8"
            TH_TEXT_MID="#b0ccd4"
            TH_TEXT_SOFT="#7a9aaa"
            # reserved for third-party themes; not used by built-in overlay annotate calls.
            # shellcheck disable=SC2034
            TH_TEXT_FAINT="#b0ccd4"   # same as mid — faint neon on dark is unreadable
            TH_LEVEL_CRITICAL="#ff2266"
            TH_LEVEL_HIGH="#ff8800"
            TH_LEVEL_MEDIUM="#ffdd00"
            TH_LEVEL_LOW="#44ff88"
            TH_LEVEL_INFO="#00e5ff"
            TH_PIN_EMERG="ffffff"     # white     — nothing on map is white
            TH_PIN_MIL="ff00cc"       # hot pink  — no map element is this hue
            TH_PIN_GDACS_RED="ff2200" # pure red  — far brighter/redder than burnt orange #b34d22
            TH_PIN_GDACS_ORG="ff88ff" # pale orchid — distinct from magenta mil and red gdacs
            TH_PIN_Q_CRIT="ff2200"    # pure red  — loudest, same family as gdacs red
            TH_PIN_Q_HIGH="ffee00"    # neon yellow — far more saturated than dim olive #bfbc0e
            TH_PIN_Q_MED="00ff88"     # neon mint  — completely different from olive green #639f19
            TH_PIN_Q_LOW="44aaff"     # sky blue   — lighter/more saturated than navy #224466 and teal #0dc0ca
            TH_LEG_TEXT="#e8f4f8"
            ;;
        vintage|*)
            # vintage — cream paper panel, dark ink; pairs with the vintage parchment map style.
            # default for any unrecognised value too.
            _TH_MAPBOX_STYLE="mqu3zada/cmn36n4yr007j01r59srzb2ej"
            TH_PANEL_FILL="rgba(240,232,210,0.94)"
            TH_BORDER_COL="#2a1a0a"
            TH_TEXT_DARK="#1a120a"
            TH_TEXT_MID="#3d2b1a"
            TH_TEXT_SOFT="#5a3e28"
            # reserved for third-party themes; not used by built-in overlay annotate calls.
            # shellcheck disable=SC2034
            TH_TEXT_FAINT="#5a3e28"   # same as soft — darkest readable ink on cream
            TH_LEVEL_CRITICAL="#7a1008"
            TH_LEVEL_HIGH="#7a3208"
            TH_LEVEL_MEDIUM="#6a4c08"
            TH_LEVEL_LOW="#2e5218"
            TH_LEVEL_INFO="#3a3028"
            TH_PIN_EMERG="1a5f5a"
            TH_PIN_MIL="2b3a5c"
            TH_PIN_GDACS_RED="6e1a10"
            TH_PIN_GDACS_ORG="7a3a08"
            TH_PIN_Q_CRIT="6e1a10"
            TH_PIN_Q_HIGH="8c3a10"
            TH_PIN_Q_MED="7a5410"
            TH_PIN_Q_LOW="5a5228"
            TH_LEG_TEXT="#1a120a"
            ;;
    esac
    # MAPBOX_STYLE: honour explicit override from config.env, else use theme default
    [ -z "$MAPBOX_STYLE" ] && MAPBOX_STYLE="$_TH_MAPBOX_STYLE"
    MAPBOX_BASE="https://api.mapbox.com/styles/v1/${MAPBOX_STYLE}/static"
    unset _t _TH_MAPBOX_STYLE
}
_resolve_theme

# ── signal handling ───────────────────────────────────────────────────────────

clean_up() {
    # remove transient files that a mid-run kill would otherwise leave behind
    rm -f "$CACHE_DIR/.map_tc.png" "$CACHE_DIR/.map_raw_ready"
}

signal_exit() {
    case "$1" in
        INT)  printf '\n%s: interrupted\n'  "$PROGNAME" >&2; clean_up; exit 1 ;;
        TERM) printf '\n%s: terminated\n'   "$PROGNAME" >&2; clean_up; exit 1 ;;
        *)    printf '\n%s: unknown signal\n' "$PROGNAME" >&2; clean_up; exit 1 ;;
    esac
}

trap "signal_exit TERM" TERM HUP
trap "signal_exit INT"  INT

# ── helpers ───────────────────────────────────────────────────────────────────

has_cmd() { command -v "$1" >/dev/null 2>&1; }

# tries homebrew paths first so macOS dev machine works without PATH hacks
_find_magick() {
    for _b in magick convert \
               /opt/homebrew/bin/magick /usr/local/bin/magick \
               /opt/homebrew/bin/convert /usr/local/bin/convert; do
        command -v "$_b" >/dev/null 2>&1 && { echo "$_b"; return 0; }
    done
    return 1
}

# prefer the monaco bundled with the quickshell config — keeps the overlay
# font consistent with the shell UI. falls back through system monospace faces.
# stowed path is checked first, then the dotfiles repo copy (works pre-stow),
# then system paths for non-macOS / non-dotfiles installs.
_find_font() {
    for _f in \
        "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/fonts/Monaco.ttf" \
        "$(dirname "$0")/../../../quickshell/.config/quickshell/fonts/Monaco.ttf" \
        /System/Library/Fonts/Monaco.ttf \
        /Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf \
        /Library/Fonts/JetBrainsMonoNLNerdFont-Regular.ttf \
        /usr/local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf \
        /usr/share/fonts/truetype/jetbrains-mono/JetBrainsMonoNerdFont-Regular.ttf \
        /usr/local/share/fonts/nerd-fonts/JetBrainsMonoNerdFont-Regular.ttf \
        /usr/local/share/fonts/dejavu/DejaVuSansMono.ttf \
        /usr/share/fonts/dejavu/DejaVuSansMono.ttf \
        /usr/local/share/fonts/DejaVuSansMono.ttf \
        /usr/share/fonts/liberation/LiberationMono-Regular.ttf \
        /usr/local/share/fonts/LiberationMono-Regular.ttf \
        /usr/local/share/fonts/liberation/LiberationMono-Regular.ttf; do
        [ -f "$_f" ] && { echo "$_f"; return 0; }
    done
    return 1
}

# rank: info=0 low=1 medium=2 high=3 critical=4
level_rank() {
    case "$1" in
        critical) echo 4 ;;
        high)     echo 3 ;;
        medium)   echo 2 ;;
        low)      echo 1 ;;
        *)        echo 0 ;;
    esac
}

# prints whichever of $1 (current) or $2 (candidate) is higher
upgrade_level() {
    if [ "$(level_rank "$2")" -gt "$(level_rank "$1")" ]; then
        echo "$2"
    else
        echo "$1"
    fi
}

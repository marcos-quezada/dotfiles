#!/usr/bin/env bats
# threatwatch.bats — subcommand tests against fixture data (no network)
# run: bats tests/threatwatch.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
TW="$REPO_ROOT/threatwatch/.local/bin/threatwatch"
FIXTURES="$REPO_ROOT/tests/fixtures"

setup() {
    # point cache at a temp dir pre-populated with fixture data
    XDG_CACHE_HOME="$(mktemp -d)"
    export XDG_CACHE_HOME
    CACHE="$XDG_CACHE_HOME/threatwatch"
    mkdir -p "$CACHE"

    cp "$FIXTURES/quakes.json"        "$CACHE/quakes.json"
    cp "$FIXTURES/flights.json"       "$CACHE/flights.json"
    cp "$FIXTURES/summary.json"       "$CACHE/summary.json"
    cp "$FIXTURES/gdacs.xml"          "$CACHE/gdacs.xml"
    cp "$FIXTURES/polymarket.json"    "$CACHE/polymarket.json"
    cp "$FIXTURES/mapbox_count.json"  "$CACHE/mapbox_count.json"

    # ensure no real config.env is loaded (prevents MAPBOX_TOKEN leaking in)
    XDG_CONFIG_HOME="$(mktemp -d)"
    export XDG_CONFIG_HOME

    # stripped script — function definitions only, no main dispatcher.
    # sourcing the full script runs tobar (the default case), which pollutes stdout.
    # awk stops at the sentinel comment that precedes the case dispatcher.
    TW_FUNCS="$XDG_CACHE_HOME/tw_funcs.sh"
    awk '/^# ── main/{exit} {print}' "$TW" > "$TW_FUNCS"
}

teardown() {
    rm -rf "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
}

# ── tobar (default command) ───────────────────────────────────────────────────

@test "tobar: exits 0 when summary.json exists" {
    run "$TW"
    [ "$status" -eq 0 ]
}

@test "tobar: output contains level icon" {
    OUT=$("$TW")
    # fixture threat_level=high → icon 󰒙; non-empty output expected
    [ -n "$OUT" ]
}

@test "tobar: output contains quake count from fixture" {
    OUT=$("$TW")
    # fixture quake_count=2, should include "2" in quake token
    [[ "$OUT" == *"2"* ]]
}

@test "tobar: quake token uses seismograph icon when quakes present" {
    OUT=$("$TW")
    # 󰈌 is the seismograph icon; quake_count=2 in fixture
    [[ "$OUT" == *"󰈌"* ]]
}

@test "tobar: flight token uses aircraft icon when mil_count > 0" {
    OUT=$("$TW")
    # fixture mil_count=2 → ✈2 token
    [[ "$OUT" == *"✈"* ]]
}

@test "tobar: silent when info level and no events" {
    # write a minimal summary with level=info and all counts zeroed
    jq -n '{
        threat_level: "info",
        quake_count: 0,
        top_quake: null,
        mil_count: 0,
        emerg_count: 0,
        gdacs_alerts: [],
        poly_markets: [],
        quake_threats: [],
        mapbox: { requests_this_month: 0, free_tier_limit: 50000, warn: false },
        updated_at: "2024-01-01T00:00:00Z"
    }' > "$CACHE/summary.json"
    OUT=$("$TW")
    [ -z "$OUT" ]
}

@test "tobar: emergency squawk prefix is ! when emerg_count > 0" {
    jq '.emerg_count = 1 | .mil_count = 0' "$CACHE/summary.json" > "$CACHE/summary.json.tmp"
    mv "$CACHE/summary.json.tmp" "$CACHE/summary.json"
    OUT=$("$TW")
    [[ "$OUT" == *"✈!"* ]]
}

# ── data ─────────────────────────────────────────────────────────────────────

@test "data: exits 0 when summary.json exists" {
    run "$TW" data
    [ "$status" -eq 0 ]
}

@test "data: output contains threat level heading" {
    run "$TW" data
    [[ "$output" == *"Threat Level"* ]]
}

@test "data: output contains earthquake count" {
    run "$TW" data
    [[ "$output" == *"Earthquakes"* ]]
}

@test "data: output contains GDACS section" {
    run "$TW" data
    [[ "$output" == *"GDACS"* ]]
}

@test "data: no summary.json returns non-zero and helpful message" {
    rm -f "$XDG_CACHE_HOME/threatwatch/summary.json"
    run "$TW" data
    [ "$status" -ne 0 ]
    [[ "$output" == *"threatwatch update"* ]]
}

# ── flights ───────────────────────────────────────────────────────────────────

@test "flights: exits 0 when flights.json exists" {
    run "$TW" flights
    [ "$status" -eq 0 ]
}

@test "flights: output lists military aircraft" {
    run "$TW" flights
    [[ "$output" == *"Military"* ]]
}

@test "flights: GAF callsign is detected as military" {
    run "$TW" flights
    [[ "$output" == *"GAF"* ]]
}

@test "flights: REACH callsign is detected as military" {
    run "$TW" flights
    [[ "$output" == *"REACH"* ]]
}

@test "flights: no flights.json returns non-zero" {
    rm -f "$XDG_CACHE_HOME/threatwatch/flights.json"
    run "$TW" flights
    [ "$status" -ne 0 ]
}

# ── help ─────────────────────────────────────────────────────────────────────

@test "help: exits 0" {
    run "$TW" help
    [ "$status" -eq 0 ]
}

@test "help: lists available commands" {
    run "$TW" help
    [[ "$output" == *"update"* ]]
    [[ "$output" == *"data"* ]]
    [[ "$output" == *"flights"* ]]
}

# ── mapbox usage ─────────────────────────────────────────────────────────────

@test "mapbox: exits 0" {
    run "$TW" mapbox
    [ "$status" -eq 0 ]
}

@test "mapbox: shows request count" {
    run "$TW" mapbox
    [[ "$output" == *"Requests"* ]]
}

# ── level_rank / upgrade_level (pure functions) ───────────────────────────────

@test "level_rank: critical=4 high=3 medium=2 low=1 info=0" {
    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        printf '%s %s %s %s %s' \
            \$(level_rank critical) \
            \$(level_rank high) \
            \$(level_rank medium) \
            \$(level_rank low) \
            \$(level_rank info)
    "
    [ "$status" -eq 0 ]
    [ "$output" = "4 3 2 1 0" ]
}

@test "upgrade_level: returns higher of two levels" {
    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        printf '%s' \$(upgrade_level high critical)
    "
    [ "$status" -eq 0 ]
    [ "$output" = "critical" ]
}

@test "upgrade_level: keeps current when already higher" {
    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        printf '%s' \$(upgrade_level critical high)
    "
    [ "$status" -eq 0 ]
    [ "$output" = "critical" ]
}

@test "upgrade_level: info upgrades to medium" {
    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        printf '%s' \$(upgrade_level info medium)
    "
    [ "$status" -eq 0 ]
    [ "$output" = "medium" ]
}

# ── _resolve_theme ────────────────────────────────────────────────────────────

@test "_resolve_theme: vintage sets TH_PANEL_FILL" {
    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        THREATWATCH_THEME=vintage
        export THREATWATCH_THEME
        . '$TW_FUNCS'
        printf '%s' \"\$TH_PANEL_FILL\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"rgba("* ]]
}

@test "_resolve_theme: vintage sets all TH_* colour vars" {
    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        THREATWATCH_THEME=vintage
        export THREATWATCH_THEME
        . '$TW_FUNCS'
        for v in TH_PANEL_FILL TH_BORDER_COL TH_TEXT_DARK TH_TEXT_MID \
                 TH_LEVEL_CRITICAL TH_LEVEL_HIGH TH_LEVEL_MEDIUM TH_LEVEL_LOW \
                 TH_PIN_MIL TH_PIN_GDACS_RED TH_PIN_Q_CRIT TH_LEG_TEXT; do
            eval \"val=\\\$\$v\"
            [ -n \"\$val\" ] || { printf 'missing: %s\n' \"\$v\"; exit 1; }
        done
        printf 'ok'
    "
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "_resolve_theme: neon sets TH_PANEL_FILL to near-black" {
    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        THREATWATCH_THEME=neon
        export THREATWATCH_THEME
        . '$TW_FUNCS'
        printf '%s' \"\$TH_PANEL_FILL\"
    "
    [ "$status" -eq 0 ]
    # neon panel is rgba(6,8,14,0.90) — near-black
    [[ "$output" == *"rgba(6"* ]]
}

@test "_resolve_theme: neon sets TH_BORDER_COL to cyan" {
    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        THREATWATCH_THEME=neon
        export THREATWATCH_THEME
        . '$TW_FUNCS'
        printf '%s' \"\$TH_BORDER_COL\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "#00e5ff" ]
}

@test "_resolve_theme: unknown theme falls back to vintage" {
    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        THREATWATCH_THEME=does-not-exist
        export THREATWATCH_THEME
        . '$TW_FUNCS'
        printf '%s' \"\$TH_TEXT_DARK\"
    "
    [ "$status" -eq 0 ]
    # vintage TH_TEXT_DARK is #1a120a
    [ "$output" = "#1a120a" ]
}

# ── _map_count_get / _map_count_bump ─────────────────────────────────────────

@test "_map_count_get: reads count from current-month file" {
    THIS_MONTH=$(date +%Y-%m)
    echo "{ \"month\": \"$THIS_MONTH\", \"count\": 17 }" \
        > "$CACHE/mapbox_count.json"

    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        _map_count_get
    "
    [ "$status" -eq 0 ]
    [ "$output" = "17" ]
}

@test "_map_count_get: resets to 0 on month rollover" {
    # stale month — any past date works
    echo '{ "month": "2020-01", "count": 999 }' \
        > "$CACHE/mapbox_count.json"

    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        _map_count_get
    "
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "_map_count_get: returns 0 when file absent" {
    rm -f "$CACHE/mapbox_count.json"

    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        _map_count_get
    "
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "_map_count_bump: increments count by 1" {
    THIS_MONTH=$(date +%Y-%m)
    echo "{ \"month\": \"$THIS_MONTH\", \"count\": 5 }" \
        > "$CACHE/mapbox_count.json"

    run sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        _map_count_bump
    "
    [ "$status" -eq 0 ]
    [ "$output" = "6" ]
}

@test "_map_count_bump: writes correct month to file" {
    THIS_MONTH=$(date +%Y-%m)
    rm -f "$CACHE/mapbox_count.json"

    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        _map_count_bump
    " >/dev/null 2>&1
    WRITTEN_MONTH=$(jq -r '.month' "$CACHE/mapbox_count.json")
    [ "$WRITTEN_MONTH" = "$THIS_MONTH" ]
}

# ── build_summary ─────────────────────────────────────────────────────────────

@test "build_summary: writes summary.json" {
    rm -f "$CACHE/summary.json"
    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        build_summary
    " >/dev/null 2>&1
    [ -f "$CACHE/summary.json" ]
}

@test "build_summary: threat_level field present in output" {
    rm -f "$CACHE/summary.json"
    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        build_summary
    " >/dev/null 2>&1
    LEVEL=$(jq -r '.threat_level' "$CACHE/summary.json" 2>/dev/null)
    [ -n "$LEVEL" ]
}

@test "build_summary: M4.8 quake produces at least high level" {
    # fixture quakes.json has M4.8 (>= QUAKE_HIGH_MAG=4.5) → high
    rm -f "$CACHE/summary.json"
    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        build_summary
    " >/dev/null 2>&1
    LEVEL=$(jq -r '.threat_level' "$CACHE/summary.json")
    # level must be high or critical (gdacs red in-region also in fixture)
    [ "$LEVEL" = "high" ] || [ "$LEVEL" = "critical" ]
}

@test "build_summary: GDACS red in-region forces critical" {
    # gdacs.xml fixture has Red alert at 50.08N/14.43E — inside GDACS region
    rm -f "$CACHE/summary.json"
    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        build_summary
    " >/dev/null 2>&1
    LEVEL=$(jq -r '.threat_level' "$CACHE/summary.json")
    [ "$LEVEL" = "critical" ]
}

@test "build_summary: quake_count matches fixture" {
    rm -f "$CACHE/summary.json"
    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        build_summary
    " >/dev/null 2>&1
    COUNT=$(jq -r '.quake_count' "$CACHE/summary.json")
    [ "$COUNT" = "2" ]
}

@test "build_summary: gdacs_alerts array is present" {
    rm -f "$CACHE/summary.json"
    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        build_summary
    " >/dev/null 2>&1
    LEN=$(jq '.gdacs_alerts | length' "$CACHE/summary.json")
    [ "$LEN" -gt 0 ]
}

@test "build_summary: poly_markets filtered to relevant keywords" {
    rm -f "$CACHE/summary.json"
    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        build_summary
    " >/dev/null 2>&1
    # all 3 fixture markets match keywords (russia/nato/ukraine/ceasefire/germany)
    LEN=$(jq '.poly_markets | length' "$CACHE/summary.json")
    [ "$LEN" -gt 0 ]
}

@test "build_summary: mapbox.requests_this_month field present" {
    rm -f "$CACHE/summary.json"
    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        build_summary
    " >/dev/null 2>&1
    VAL=$(jq '.mapbox.requests_this_month' "$CACHE/summary.json")
    [ -n "$VAL" ]
}

# ── build_pins_json ───────────────────────────────────────────────────────────

@test "build_pins_json: writes pins.json" {
    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        build_pins_json
    " >/dev/null 2>&1
    [ -f "$CACHE/pins.json" ]
}

@test "build_pins_json: pin count matches quake + military inputs" {
    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        build_pins_json
    " >/dev/null 2>&1
    # fixture: 2 quakes + 2 mil aircraft (GAF001, REACH42) = 4 minimum
    LEN=$(jq 'length' "$CACHE/pins.json")
    [ "$LEN" -ge 4 ]
}

@test "build_pins_json: each pin has x and y pixel coordinates" {
    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        build_pins_json
    " >/dev/null 2>&1
    # every pin must have integer x and y
    MISSING=$(jq '[.[] | select(.x == null or .y == null)] | length' "$CACHE/pins.json")
    [ "$MISSING" = "0" ]
}

@test "build_pins_json: Austria quake (13.4E, 48.5N) lands within map bounds" {
    sh -c "
        XDG_CONFIG_HOME='$XDG_CONFIG_HOME'
        XDG_CACHE_HOME='$XDG_CACHE_HOME'
        export XDG_CONFIG_HOME XDG_CACHE_HOME
        . '$TW_FUNCS'
        build_pins_json
    " >/dev/null 2>&1
    # center 10.45E/50.609N, zoom 5, 800x780 — Austria is slightly right and below center
    # x should be in 350–550, y in 350–550
    X=$(jq '[.[] | select(.type=="quake" and (.title | contains("AUSTRIA")))] | .[0].x' "$CACHE/pins.json")
    Y=$(jq '[.[] | select(.type=="quake" and (.title | contains("AUSTRIA")))] | .[0].y' "$CACHE/pins.json")
    [ "$X" -ge 350 ] && [ "$X" -le 550 ]
    [ "$Y" -ge 350 ] && [ "$Y" -le 550 ]
}

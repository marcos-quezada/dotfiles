#!/usr/bin/env bats
# threatwatch.bats — subcommand tests against fixture data (no network)
# run: bats tests/threatwatch.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
TW="$REPO_ROOT/threatwatch/.local/bin/threatwatch"
FIXTURES="$REPO_ROOT/tests/fixtures"

setup() {
    # point cache at a temp dir pre-populated with fixture data
    export XDG_CACHE_HOME="$(mktemp -d)"
    CACHE="$XDG_CACHE_HOME/threatwatch"
    mkdir -p "$CACHE"

    cp "$FIXTURES/quakes.json"  "$CACHE/quakes.json"
    cp "$FIXTURES/flights.json" "$CACHE/flights.json"
    cp "$FIXTURES/summary.json" "$CACHE/summary.json"

    # ensure no real config.env is loaded (prevents MAPBOX_TOKEN leaking in)
    export XDG_CONFIG_HOME="$(mktemp -d)"
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

#!/bin/sh
# threatwatch.d/map-overlay.sh — composites the HUD/legend onto the raw
# mapbox PNG, and the map/overlay-only subcommand entry points.
# sourced only, never executed directly.

# apply overlay onto the raw map fetched by fetch_map.
# called after build_summary so the HUD reflects the current run's data.
# safe to call even if no raw map was fetched this run (flag file check).
apply_map_overlay() {
    FLAG="$CACHE_DIR/.map_raw_ready"
    [ -f "$FLAG" ] || return 0
    MAP_RAW=$(cat "$FLAG")
    rm -f "$FLAG"
    [ -f "$MAP_RAW" ] || return 0
    if _map_overlay "$MAP_RAW" "$MAP_FILE"; then
        printf '  Map: overlay applied → %s\n' "$MAP_FILE"
    else
        cp "$MAP_RAW" "$MAP_FILE"
        printf '  Map: overlay skipped (no magick), raw map saved.\n'
    fi
}

# ── map overlay ───────────────────────────────────────────────────────────────
# composites a top-left HUD + bottom-right legend onto the raw mapbox png.
# HUD is narrow so it doesn't cover southern pins — the old full-width bar did.
# layout at @2x (1600×1560px):
#   top-left HUD:        0..620, 0..265  — threat level, counts, refresh time
#   bottom-right legend: 1260..1600, 1340..1560 — pin colour key

_map_overlay() {
    SRC="$1"
    DST="$2"
    [ -f "$SUMMARY_FILE" ] || { cp "$SRC" "$DST"; return 0; }
    IM=$(_find_magick) || { cp "$SRC" "$DST"; return 1; }
    FONT=$(_find_font) || FONT=""

    # pull values from summary.json
    LEVEL=$(jq -r '.threat_level // "info"'           "$SUMMARY_FILE")
    QCOUNT=$(jq -r '.quake_count // 0'                "$SUMMARY_FILE")
    TOPQ=$(jq -r '
        .top_quake
        | if . == null then "none"
          else "M\(.mag) \(.place[:24])"
          end' "$SUMMARY_FILE" 2>/dev/null || echo "none")
    MIL=$(jq -r '.mil_count // 0'                     "$SUMMARY_FILE")
    EMERG=$(jq -r '.emerg_count // 0'                 "$SUMMARY_FILE")
    MAPUSE=$(jq -r '.mapbox.requests_this_month // 0' "$SUMMARY_FILE")

    POLY_TOP=$(jq -r '
        .poly_markets[0]
        | if . == null then "—"
          else "\(.prob_yes | floor)%  \(.title[:38])"
          end' "$SUMMARY_FILE" 2>/dev/null || echo "—")

    GDACS_RGN=$(jq '[.gdacs_alerts[] | select(.in_region==true)] | length' \
        "$SUMMARY_FILE" 2>/dev/null || echo 0)

    # accent bar colour — driven by theme level palette
    case "$LEVEL" in
        critical) LCOL="$TH_LEVEL_CRITICAL" ;;
        high)     LCOL="$TH_LEVEL_HIGH"     ;;
        medium)   LCOL="$TH_LEVEL_MEDIUM"   ;;
        low)      LCOL="$TH_LEVEL_LOW"      ;;
        *)        LCOL="$TH_LEVEL_INFO"     ;;
    esac
    LEVEL_UP=$(printf '%s' "$LEVEL" | tr '[:lower:]' '[:upper:]')

    # geometry — all values in @2x pixels (1600×1560 output)
    IMG_W=1600
    IMG_H=1560

    HUD_X2=620
    HUD_Y2=265
    ACCENT=6          # coloured left accent bar width
    PAD=18            # text left padding inside panel
    TEXT_X=$(( ACCENT + PAD ))

    FONT_LG=28        # threat level line
    FONT_MD=22        # quake / flight lines
    FONT_SM=19        # market line
    FONT_XS=16        # timestamp / mapbox line

    # line Y positions — imagemagick annotate Y is baseline, not top-of-glyph
    L1Y=40
    L2Y=85
    L3Y=128
    L4Y=168
    L5Y=207
    L6Y=248

    LEG_X1=$(( IMG_W - 340 ))
    LEG_Y1=$(( IMG_H - 220 ))
    LEG_X2=$IMG_W
    LEG_Y2=$IMG_H
    LEG_PAD=12
    LEG_DOT=18
    LEG_ROW=32
    LEG_TXT_X=$(( LEG_X1 + LEG_PAD + LEG_DOT + 10 ))
    LEG_FONT=18

    FONT_ARG=""
    [ -n "$FONT" ] && FONT_ARG="-font ${FONT}"

    # HUD text lines
    L1="${LEVEL_UP}  ${TOPQ}"
    L2="Quakes: ${QCOUNT}  in bbox"
    if [ "$EMERG" -gt 0 ]; then
        L3="Flights: ${MIL} mil  ${EMERG} EMERGENCY squawk"
    else
        L3="Flights: ${MIL} military  GDACS rgn: ${GDACS_RGN}"
    fi
    L4="Mkt: ${POLY_TOP}"
    REFRESH_TIME=$(jq -r '.updated_at // ""' "$SUMMARY_FILE" 2>/dev/null \
        | sed 's/.*T\([0-9][0-9]:[0-9][0-9]\).*/\1/')
    REFRESH_DATE=$(jq -r '.updated_at // ""' "$SUMMARY_FILE" 2>/dev/null \
        | sed 's/T.*//')
    L5="Last refresh: ${REFRESH_DATE}  ${REFRESH_TIME} UTC"
    L6="Mapbox: ${MAPUSE}/50000 req this month"

    # legend row baselines
    R1=$(( LEG_Y1 + LEG_PAD + LEG_DOT ))
    R2=$(( R1 + LEG_ROW ))
    R3=$(( R2 + LEG_ROW ))
    R4=$(( R3 + LEG_ROW ))
    R5=$(( R4 + LEG_ROW ))
    R6=$(( R5 + LEG_ROW ))

    SW_X1=$(( LEG_X1 + LEG_PAD ))
    SW_X2=$(( SW_X1 + LEG_DOT ))

    # pass 1: palette/indexed PNG from mapbox must be converted to TrueColorAlpha
    # first or IM7 defers the type change and the first rgba() fill loses its alpha.
    # write to a temp file so pass 2 can draw on a guaranteed 32-bit canvas.
    TC_TMP="${CACHE_DIR}/.map_tc.png"
    "$IM" "$SRC" -type TrueColorAlpha -define png:color-type=6 "$TC_TMP" 2>/dev/null \
        || { cp "$SRC" "$DST"; return 1; }

    # FONT_ARG is intentionally unquoted below — it's either empty (zero words)
    # or "-font /path/to/font" (two words). Quoting would pass an empty arg when unset.
    # shellcheck disable=SC2086
    # pass 2: all draw / annotate ops on the TrueColor temp file
    "$IM" "$TC_TMP" \
        \
        -fill "${TH_PANEL_FILL}" \
        -draw "roundrectangle 0,0 ${HUD_X2},${HUD_Y2} 0,0" \
        -fill "none" -strokewidth 3 -stroke "${TH_BORDER_COL}" \
        -draw "rectangle 1,1 ${HUD_X2},${HUD_Y2}" \
        -stroke "none" \
        \
        -fill "${LCOL}" \
        -draw "rectangle 0,0 ${ACCENT},${HUD_Y2}" \
        \
        ${FONT_ARG} -pointsize "${FONT_LG}" \
        -fill "${LCOL}"            -annotate "+${TEXT_X}+${L1Y}" "${L1}" \
        ${FONT_ARG} -pointsize "${FONT_MD}" \
        -fill "${TH_TEXT_DARK}"    -annotate "+${TEXT_X}+${L2Y}" "${L2}" \
        -fill "${TH_TEXT_DARK}"    -annotate "+${TEXT_X}+${L3Y}" "${L3}" \
        ${FONT_ARG} -pointsize "${FONT_SM}" \
        -fill "${TH_TEXT_MID}"     -annotate "+${TEXT_X}+${L4Y}" "${L4}" \
        ${FONT_ARG} -pointsize "${FONT_XS}" \
        -fill "${TH_TEXT_SOFT}"    -annotate "+${TEXT_X}+${L5Y}" "${L5}" \
        -fill "${TH_TEXT_MID}"     -annotate "+${TEXT_X}+${L6Y}" "${L6}" \
        \
        -fill "${TH_PANEL_FILL}" \
        -draw "rectangle ${LEG_X1},${LEG_Y1} ${LEG_X2},${LEG_Y2}" \
        -fill "none" -strokewidth 3 -stroke "${TH_BORDER_COL}" \
        -draw "rectangle ${LEG_X1},${LEG_Y1} $(( LEG_X2 - 1 )),$(( LEG_Y2 - 1 ))" \
        -stroke "none" \
        \
        -fill "#${TH_PIN_Q_CRIT}" \
        -draw "rectangle ${SW_X1},$(( R1 - LEG_DOT )) ${SW_X2},${R1}" \
        ${FONT_ARG} -pointsize "${LEG_FONT}" \
        -fill "${TH_LEG_TEXT}" -annotate "+${LEG_TXT_X}+${R1}" "Crit quake (M5.5+)" \
        \
        -fill "#${TH_PIN_Q_HIGH}" \
        -draw "rectangle ${SW_X1},$(( R2 - LEG_DOT )) ${SW_X2},${R2}" \
        -fill "${TH_LEG_TEXT}" -annotate "+${LEG_TXT_X}+${R2}" "High quake (M4.5+)" \
        \
        -fill "#${TH_PIN_Q_MED}" \
        -draw "rectangle ${SW_X1},$(( R3 - LEG_DOT )) ${SW_X2},${R3}" \
        -fill "${TH_LEG_TEXT}" -annotate "+${LEG_TXT_X}+${R3}" "Med quake (M4.0+)" \
        \
        -fill "#${TH_PIN_Q_LOW}" \
        -draw "rectangle ${SW_X1},$(( R4 - LEG_DOT )) ${SW_X2},${R4}" \
        -fill "${TH_LEG_TEXT}" -annotate "+${LEG_TXT_X}+${R4}" "Low quake (M3.0+)" \
        \
        -fill "#${TH_PIN_EMERG}" \
        -draw "rectangle ${SW_X1},$(( R5 - LEG_DOT )) ${SW_X2},${R5}" \
        -fill "${TH_LEG_TEXT}" -annotate "+${LEG_TXT_X}+${R5}" "Emergency squawk" \
        \
        -fill "#${TH_PIN_MIL}" \
        -draw "rectangle ${SW_X1},$(( R6 - LEG_DOT )) ${SW_X2},${R6}" \
        -fill "${TH_LEG_TEXT}" -annotate "+${LEG_TXT_X}+${R6}" "Military aircraft" \
        \
        "$DST" 2>/dev/null
    _rc=$?
    rm -f "$TC_TMP"
    return $_rc
}

# ── map only ──────────────────────────────────────────────────────────────────

map_only() {
    mkdir -p "$CACHE_DIR"
    # --force bypasses the interval guard — useful for one-off test fetches
    if [ "${1:-}" = "--force" ]; then
        MAP_MIN_INTERVAL=0
    fi
    fetch_map
    apply_map_overlay
}

# ── overlay only ─────────────────────────────────────────────────────────────
# re-renders the HUD onto the existing raw map — no Mapbox call, no rate limit hit.
# useful when only the theme or data has changed.

overlay_only() {
    mkdir -p "$CACHE_DIR"
    MAP_RAW="$CACHE_DIR/germany_raw.png"
    if [ ! -f "$MAP_RAW" ]; then
        printf '  Overlay: no raw map found at %s — run: threatwatch map --force\n' "$MAP_RAW"
        return 1
    fi
    if _map_overlay "$MAP_RAW" "$MAP_FILE"; then
        printf '  Map: overlay applied → %s\n' "$MAP_FILE"
    else
        cp "$MAP_RAW" "$MAP_FILE"
        printf '  Map: overlay skipped (no magick), raw map saved.\n'
    fi
}

#!/bin/sh
# threatwatch.d/fetch.sh — all five source fetchers (earthquakes, GDACS,
# flights, Polymarket, map) and the Mapbox monthly usage counter.
# sourced only, never executed directly.

# ── fetch: earthquakes ────────────────────────────────────────────────────────

fetch_earthquakes() {
    # EMSC is primary — far better Central Europe coverage than USGS.
    # USGS only called when EMSC returns fewer than 5 events (quiet period or outage).
    printf 'Fetching earthquakes (EMSC — primary)...\n'
    curl -sf --max-time 15 \
        "${EMSC_URL}?limit=20&minmag=${QUAKE_MED_MAG}&minlat=${BBOX_MINLAT}&maxlat=${BBOX_MAXLAT}&minlon=${BBOX_MINLON}&maxlon=${BBOX_MAXLON}&format=json&orderby=time-asc" \
        -o "$QUAKES_FILE" 2>/dev/null \
        && printf '  EMSC: %d events\n' "$(jq '.features | length' "$QUAKES_FILE" 2>/dev/null || echo '?')" \
        || printf '  EMSC: fetch failed\n'

    EMSC_COUNT=$(jq '.features | length' "$QUAKES_FILE" 2>/dev/null || echo 0)
    if [ "$EMSC_COUNT" -lt 5 ]; then
        printf 'Fetching earthquakes (USGS — supplementary, EMSC only had %d events)...\n' "$EMSC_COUNT"
        curl -sf --max-time 15 \
            "${USGS_URL}?format=geojson&minmagnitude=${QUAKE_MED_MAG}&minlatitude=${BBOX_MINLAT}&maxlatitude=${BBOX_MAXLAT}&minlongitude=${BBOX_MINLON}&maxlongitude=${BBOX_MAXLON}&limit=20&orderby=time" \
            -o "$EMSC_FILE" 2>/dev/null \
            && printf '  USGS: %d events\n' "$(jq '.features | length' "$EMSC_FILE" 2>/dev/null || echo '?')" \
            || printf '  USGS: fetch failed\n'

        # merge both geojson feature arrays, sort by magnitude, drop duplicates within 0.4°
        jq -sc '
            [ .[0].features // [], .[1].features // [] ]
            | add
            | sort_by(
                -( .properties.mag // .properties.ml // 0 )
              )
            | reduce .[] as $f (
                [];
                . as $acc
                | ($f.geometry.coordinates[0] // 0) as $lon
                | ($f.geometry.coordinates[1] // 0) as $lat
                | if ($acc | any(
                      ((.geometry.coordinates[0] - $lon) | fabs) < 0.4 and
                      ((.geometry.coordinates[1] - $lat) | fabs) < 0.4
                  )) then $acc
                  else $acc + [$f]
                  end
              )
            | { features: ., type: "FeatureCollection" }
        ' "$QUAKES_FILE" "$EMSC_FILE" > "$QUAKES_FILE.merged" 2>/dev/null \
            && mv "$QUAKES_FILE.merged" "$QUAKES_FILE" \
            && printf '  Merged: %d unique events\n' "$(jq '.features | length' "$QUAKES_FILE" 2>/dev/null || echo '?')" \
            || printf '  Merge: skipped (using primary source only)\n'
    else
        printf '  USGS: skipped — EMSC has sufficient coverage (%d events)\n' "$EMSC_COUNT"
    fi
}

# ── fetch: gdacs ──────────────────────────────────────────────────────────────

fetch_gdacs() {
    printf 'Fetching GDACS disaster alerts...\n'
    curl -sf --max-time 15 \
        "$GDACS_URL" \
        -o "$GDACS_FILE" 2>/dev/null \
        && printf '  GDACS: OK\n' \
        || printf '  GDACS: fetch failed\n'
}

# ── fetch: aircraft ───────────────────────────────────────────────────────────

fetch_flights() {
    printf 'Fetching aircraft over Germany (OpenSky)...\n'
    # anonymous opensky — ~400 req/day. state vector index:
    # 0=icao24 1=callsign 2=origin_country 5=lon 6=lat 7=baro_alt(m)
    # 9=velocity(m/s) 10=heading 14=squawk
    curl -sf --max-time 20 \
        "${OPENSKY_URL}?lamin=${BBOX_MINLAT}&lomin=${BBOX_MINLON}&lamax=${BBOX_MAXLAT}&lomax=${BBOX_MAXLON}" \
        -o "$FLIGHTS_FILE" 2>/dev/null \
        && printf '  OpenSky: %d aircraft\n' "$(jq '[.states // [] | length] | .[0]' "$FLIGHTS_FILE" 2>/dev/null || echo '?')" \
        || printf '  OpenSky: fetch failed (rate limit?)\n'
}

# ── fetch: polymarket ─────────────────────────────────────────────────────────

fetch_polymarket() {
    printf 'Fetching Polymarket geopolitical odds...\n'
    # politics tag — we filter for nato/europe/war keywords in build_summary
    curl -sf --max-time 15 \
        "$POLYMARKET_URL" \
        -o "$POLY_FILE" 2>/dev/null \
        && printf '  Polymarket: OK\n' \
        || printf '  Polymarket: fetch failed\n'
}

# ── mapbox usage counter ──────────────────────────────────────────────────────
# rolling monthly counter so we never blow the 50k free tier by accident

_map_count_get() {
    # returns this month's count, resets to 0 if the month has rolled over
    THIS_MONTH=$(date +%Y-%m)
    if [ -f "$MAP_COUNT_FILE" ]; then
        _mc=$(jq -r '(.month // "") + " " + ((.count // 0) | tostring)' \
            "$MAP_COUNT_FILE" 2>/dev/null || echo " 0")
        FILE_MONTH=$(printf '%s' "$_mc" | awk '{print $1}')
        COUNT=$(printf '%s' "$_mc"      | awk '{print $2}')
        if [ "$FILE_MONTH" != "$THIS_MONTH" ]; then
            COUNT=0
        fi
    else
        COUNT=0
    fi
    echo "$COUNT"
}

_map_count_bump() {
    THIS_MONTH=$(date +%Y-%m)
    NEW=$(( $(_map_count_get) + 1 ))
    jq -n --arg month "$THIS_MONTH" --argjson count "$NEW" \
        '{ month: $month, count: $count }' > "$MAP_COUNT_FILE"
    echo "$NEW"
}

# ── fetch: map ────────────────────────────────────────────────────────────────

fetch_map() {
    if [ -z "$MAPBOX_TOKEN" ]; then
        printf '  Map: skipped — set MAPBOX_TOKEN env var\n'
        printf '       Free token: https://account.mapbox.com\n'
        return 0
    fi

    # hard-stop if we're near the monthly ceiling
    CURRENT_COUNT=$(_map_count_get)
    if [ "$CURRENT_COUNT" -ge "$MAP_SKIP_THRESHOLD" ]; then
        printf '  Map: SKIPPED — monthly request count (%d) at/above hard limit (%d/50000 free).\n' \
            "$CURRENT_COUNT" "$MAP_SKIP_THRESHOLD"
        printf '       Increase MAP_MIN_INTERVAL or wait for next month.\n'
        return 0
    fi

    # skip if the cached map is still fresh enough AND was fetched with the same style
    MAP_STYLE_FILE="$CACHE_DIR/.map_style"
    if [ -f "$MAP_FILE" ]; then
        # invalidate immediately if the style has changed since the last fetch
        CACHED_STYLE=$(cat "$MAP_STYLE_FILE" 2>/dev/null || echo "")
        if [ "$CACHED_STYLE" != "$MAPBOX_STYLE" ]; then
            printf '  Map: style changed (%s → %s) — cache invalidated.\n' \
                "$CACHED_STYLE" "$MAPBOX_STYLE"
        else
            # stat -f %m on BSD/macOS, stat -c %Y on Linux
            if stat -f %m "$MAP_FILE" >/dev/null 2>&1; then
                MTIME=$(stat -f %m "$MAP_FILE" 2>/dev/null || echo 0)
            else
                MTIME=$(stat -c %Y "$MAP_FILE" 2>/dev/null || echo 0)
            fi
            NOW=$(date +%s)
            AGE=$(( NOW - MTIME ))
            if [ "$AGE" -lt "$MAP_MIN_INTERVAL" ]; then
                REMAINING=$(( MAP_MIN_INTERVAL - AGE ))
                printf '  Map: skipped — cached map is %ds old (min interval %ds, %ds remaining).\n' \
                    "$AGE" "$MAP_MIN_INTERVAL" "$REMAINING"
                printf '       Use MAP_MIN_INTERVAL=0 to force a refresh.\n'
                return 0
            fi
        fi
    fi

    printf 'Generating map snapshot: Germany + N.Italy (this month: %d requests used)...\n' "$CURRENT_COUNT"

    # ── pin slot budget ───────────────────────────────────────────────────────
    # mapbox caps at 10 pins total. we pre-reserve slots so military/squawk
    # always appear even when there are 10+ quakes in the bbox.
    # icon suffixes restored (-airfield, -danger) — help recognise event type.
    # pin colours come from TH_PIN_* theme variables set by _resolve_theme.
    #   emergency squawks : up to 2  (airfield icon)
    #   military aircraft : up to 3  (airfield icon)
    #   GDACS in-region   : up to 1  (star icon, pin-m)
    #   earthquakes       : whatever's left (danger icon, size-graduated)
    PINS=""
    MAX_PINS=10

    # emergency squawk pins — airfield icon, theme teal, max 2
    EMERG_PINS=""
    if [ -f "$FLIGHTS_FILE" ]; then
        EMERG_PINS=$(jq -r --arg sq "$EMERG_SQUAWKS" --arg col "$TH_PIN_EMERG" '
            .states // []
            | map(select(. != null))
            | map(select( (.[14] // "") | test($sq) ))
            | map(select( .[5] != null and .[6] != null ))
            | .[:2][]
            | "pin-l-airfield+\($col)(\(.[5] | tostring),\(.[6] | tostring))"
        ' "$FLIGHTS_FILE" 2>/dev/null | tr '\n' ',')
    fi

    # military aircraft pins — airfield icon, theme slate, max 3
    MIL_PINS=""
    if [ -f "$FLIGHTS_FILE" ]; then
        MIL_PINS=$(jq -r --arg pats "$MIL_PREFIXES" --arg col "$TH_PIN_MIL" '
            .states // []
            | map(select(. != null))
            | map(select( (.[1] // "" | ltrimstr(" ") | rtrimstr(" ") | ascii_upcase) | test($pats) ))
            | map(select( .[5] != null and .[6] != null ))
            | .[:3][]
            | "pin-l-airfield+\($col)(\(.[5] | tostring),\(.[6] | tostring))"
        ' "$FLIGHTS_FILE" 2>/dev/null | tr '\n' ',')
    fi

    # GDACS in-region alerts — star icon, theme red/orange, max 1
    GDACS_PINS=""
    if [ -f "$SUMMARY_FILE" ]; then
        GDACS_PINS=$(jq -r --arg red "$TH_PIN_GDACS_RED" --arg org "$TH_PIN_GDACS_ORG" '
            .gdacs_alerts // []
            | map(select(.in_region == true and .lat != null and .lon != null))
            | map(select(.level == "red" or .level == "orange"))
            | .[:1][]
            | (.lon | tostring) as $lon
            | (.lat | tostring) as $lat
            | if .level == "red" then "pin-m-star+\($red)(\($lon),\($lat))"
              else "pin-m-star+\($org)(\($lon),\($lat))"
              end
        ' "$SUMMARY_FILE" 2>/dev/null | tr '\n' ',')
    fi

    # count reserved pins by prefix — counting commas is wrong because
    # each pin URL already contains commas inside the coordinate pair
    _count_pins() {
        _cp=$(printf '%s' "$1" | tr ',' '\n' | grep -c '^pin-' 2>/dev/null) || _cp=0
        printf '%d' "${_cp:-0}"
    }
    RESERVED=$(( $(_count_pins "$EMERG_PINS") + $(_count_pins "$MIL_PINS") + $(_count_pins "$GDACS_PINS") ))
    QUAKE_SLOTS=$(( MAX_PINS - RESERVED ))
    [ "$QUAKE_SLOTS" -lt 0 ] && QUAKE_SLOTS=0

    # earthquake pins — fill remaining slots, highest magnitude first
    # size graduation: pin-l (crit) → pin-m (high) → pin-s (med/low)
    # colours come from TH_PIN_Q_* theme variables
    QUAKE_PINS=""
    if [ -f "$QUAKES_FILE" ] && [ "$QUAKE_SLOTS" -gt 0 ]; then
        QUAKE_PINS=$(jq -r \
            --arg crit "$TH_PIN_Q_CRIT" --arg high "$TH_PIN_Q_HIGH" \
            --arg med  "$TH_PIN_Q_MED"  --arg low  "$TH_PIN_Q_LOW"  '
            .features // []
            | sort_by(-( .properties.mag // .properties.ml // 0 ))
            | .[:'"$QUAKE_SLOTS"'][]
            | (.properties.mag // .properties.ml // 0) as $m
            | (.geometry.coordinates[0] | tostring) as $lon
            | (.geometry.coordinates[1] | tostring) as $lat
            | if $m >= '"$QUAKE_CRIT_MAG"' then "pin-l-danger+\($crit)(\($lon),\($lat))"
              elif $m >= '"$QUAKE_HIGH_MAG"' then "pin-m-danger+\($high)(\($lon),\($lat))"
              elif $m >= 4.0 then "pin-s-danger+\($med)(\($lon),\($lat))"
              else "pin-s-danger+\($low)(\($lon),\($lat))"
              end
        ' "$QUAKES_FILE" 2>/dev/null | tr '\n' ',')
    fi

    # assemble — emergency first, then military, gdacs, quakes
    PINS="${EMERG_PINS}${MIL_PINS}${GDACS_PINS}${QUAKE_PINS}"
    PINS=$(printf '%s' "$PINS" | sed 's/,$//')

    if [ -z "$PINS" ]; then
        MAP_URL="${MAPBOX_BASE}/${MAP_CENTER_LON},${MAP_CENTER_LAT},${MAP_ZOOM},0/${MAP_SIZE}@2x?access_token=${MAPBOX_TOKEN}"
    else
        MAP_URL="${MAPBOX_BASE}/${PINS}/${MAP_CENTER_LON},${MAP_CENTER_LAT},${MAP_ZOOM},0/${MAP_SIZE}@2x?access_token=${MAPBOX_TOKEN}"
    fi

    MAP_RAW="$CACHE_DIR/germany_raw.png"
    if curl -sf --max-time 30 "$MAP_URL" -o "$MAP_RAW" 2>/dev/null; then
        NEW_COUNT=$(_map_count_bump)
        printf '  Map: fetched — %d/%d free requests used this month.\n' \
            "$NEW_COUNT" "$MAP_WARN_THRESHOLD"
        if [ "$NEW_COUNT" -ge "$MAP_WARN_THRESHOLD" ]; then
            printf '  Map: WARNING — approaching Mapbox free tier limit (%d/50000).\n' "$NEW_COUNT"
            printf '       Set MAP_MIN_INTERVAL=86400 (daily) to reduce usage.\n'
        fi
        # store the raw path in a flag file so apply_map_overlay knows to run.
        # also write the style fingerprint so the next run can detect style changes.
        printf '%s\n' "$MAP_RAW" > "$CACHE_DIR/.map_raw_ready"
        printf '%s' "$MAPBOX_STYLE" > "$MAP_STYLE_FILE"
    else
        printf '  Map: fetch failed (check MAPBOX_TOKEN or network).\n'
    fi
}

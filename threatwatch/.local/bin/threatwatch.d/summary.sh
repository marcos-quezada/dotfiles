#!/bin/sh
# threatwatch.d/summary.sh — build_summary and build_pins_json: aggregate
# cached fetch data into summary.json and pins.json.
# sourced only, never executed directly.

# ── build summary ─────────────────────────────────────────────────────────────

build_summary() {
    printf 'Building summary...\n'

    LEVEL="info"
    QUAKE_COUNT=0
    TOP_QUAKE="null"
    MIL_COUNT=0
    EMERG_COUNT=0
    GDACS_JSON='[]'
    POLY_JSON='[]'

    # earthquakes
    if [ -f "$QUAKES_FILE" ]; then
        QUAKE_COUNT=$(jq '.features | length' "$QUAKES_FILE" 2>/dev/null || echo 0)

        # .properties.place (USGS) or .properties.flynn_region (EMSC)
        TOP_QUAKE=$(jq '
            .features // []
            | sort_by(-( .properties.mag // .properties.ml // 0 ))
            | .[0]
            | if . == null then null else {
                mag:   (.properties.mag // .properties.ml // 0),
                place: (.properties.place // .properties.flynn_region // "Unknown"),
                lat:   .geometry.coordinates[1],
                lon:   .geometry.coordinates[0],
                url:   (.properties.url // (.properties.unid // "" | "https://www.seismicportal.eu/eventdetails.html?unid=\(.)") ),
                tsunami: ((.properties.tsunami // 0) == 1)
              } end
        ' "$QUAKES_FILE" 2>/dev/null || echo "null")

        TOP_MAG=$(printf '%s' "$TOP_QUAKE" | jq -r '.mag // 0' 2>/dev/null || echo 0)

        if awk "BEGIN{exit !($TOP_MAG >= $QUAKE_CRIT_MAG)}"; then
            LEVEL=$(upgrade_level "$LEVEL" "critical")
        elif awk "BEGIN{exit !($TOP_MAG >= $QUAKE_HIGH_MAG)}"; then
            LEVEL=$(upgrade_level "$LEVEL" "high")
        elif awk "BEGIN{exit !($TOP_MAG >= $QUAKE_MED_MAG)}"; then
            LEVEL=$(upgrade_level "$LEVEL" "medium")
        fi

        QUAKE_THREATS=$(jq -r '
            .features // []
            | sort_by(-( .properties.mag // .properties.ml // 0 ))
            | .[:5][]
            | (.properties.mag // .properties.ml // 0) as $m
            | (.properties.place // .properties.flynn_region // "Unknown") as $place
            | if $m >= '"$QUAKE_CRIT_MAG"' then "CRIT EQ M\($m) \($place)"
              elif $m >= '"$QUAKE_HIGH_MAG"' then "HIGH EQ M\($m) \($place)"
              else "MED  EQ M\($m) \($place)"
              end
        ' "$QUAKES_FILE" 2>/dev/null)
    fi

    # flights
    if [ -f "$FLIGHTS_FILE" ]; then
        MIL_COUNT=$(jq --arg pats "$MIL_PREFIXES" '
            .states // []
            | map(select(. != null))
            | map(select( (.[1] // "" | ltrimstr(" ") | rtrimstr(" ") | ascii_upcase) | test($pats) ))
            | length
        ' "$FLIGHTS_FILE" 2>/dev/null || echo 0)

        EMERG_COUNT=$(jq --arg sq "$EMERG_SQUAWKS" '
            .states // []
            | map(select(. != null))
            | map(select( (.[14] // "") | test($sq) ))
            | length
        ' "$FLIGHTS_FILE" 2>/dev/null || echo 0)

        if [ "$EMERG_COUNT" -gt 0 ]; then
            LEVEL=$(upgrade_level "$LEVEL" "critical")
        fi
        # military presence alone doesn't upgrade level — it's monitoring, not threat
    fi

    # GDACS — awk splits on <item so each event stays in one block.
    # we tried splitting on '<' and it broke field extraction across boundaries.
    if [ -f "$GDACS_FILE" ]; then
        GDACS_JSON=$(awk '
            BEGIN {
                RS="<item"
                GDACS_MINLAT='"$GDACS_MINLAT"'
                GDACS_MAXLAT='"$GDACS_MAXLAT"'
                GDACS_MINLON='"$GDACS_MINLON"'
                GDACS_MAXLON='"$GDACS_MAXLON"'
            }
            NR == 1 { next }
            {
                block = $0
                alert = ""; title = ""; lat = ""; lon = ""

                n = split(block, a, /<\/?gdacs:alertlevel>/)
                if (n >= 2) alert = a[2]

                n = split(block, a, /<\/?title>/)
                if (n >= 2) title = a[2]

                n = split(block, a, /<\/?geo:lat>/)
                if (n >= 2) lat = a[2]

                n = split(block, a, /<\/?geo:long>/)
                if (n >= 2) lon = a[2]

                if (alert == "") next

                gsub(/^[ \t\n]+|[ \t\n]+$/, "", alert)
                gsub(/^[ \t\n]+|[ \t\n]+$/, "", title)
                gsub(/^[ \t\n]+|[ \t\n]+$/, "", lat)
                gsub(/^[ \t\n]+|[ \t\n]+$/, "", lon)

                in_region = "false"
                if (lat != "" && lon != "") {
                    if (lat+0 >= GDACS_MINLAT && lat+0 <= GDACS_MAXLAT &&
                        lon+0 >= GDACS_MINLON && lon+0 <= GDACS_MAXLON)
                        in_region = "true"
                }

                gsub(/"/, "\\\"", title)
                lat_val = (lat == "" ? "null" : lat)
                lon_val = (lon == "" ? "null" : lon)
                printf "{\"level\":\"%s\",\"title\":\"%s\",\"lat\":%s,\"lon\":%s,\"in_region\":%s}\n",
                    tolower(alert), title, lat_val, lon_val, in_region
            }
        ' "$GDACS_FILE" 2>/dev/null | jq -sc '.')

        # one jq pass extracts all three counts we need
        _gdacs_counts=$(printf '%s' "$GDACS_JSON" | jq -r '
            ([.[] | select(.level=="red"    and .in_region==true)] | length | tostring) + " " +
            ([.[] | select(.level=="orange" and .in_region==true)] | length | tostring) + " " +
            ([.[] | select(.level=="red")]                         | length | tostring)
        ' 2>/dev/null || echo "0 0 0")
        RED_IN_REGION=$(printf '%s' "$_gdacs_counts"    | awk '{print $1}')
        ORANGE_IN_REGION=$(printf '%s' "$_gdacs_counts" | awk '{print $2}')
        RED_GLOBAL=$(printf '%s' "$_gdacs_counts"       | awk '{print $3}')

        if [ "$RED_IN_REGION" -gt 0 ]; then
            LEVEL=$(upgrade_level "$LEVEL" "critical")
        elif [ "$ORANGE_IN_REGION" -gt 0 ]; then
            LEVEL=$(upgrade_level "$LEVEL" "high")
        elif [ "$RED_GLOBAL" -gt 0 ]; then
            LEVEL=$(upgrade_level "$LEVEL" "medium")
        fi
    fi

    # polymarket — filter for geopolitically relevant keywords
    if [ -f "$POLY_FILE" ]; then
        KEYWORDS='nato|russia|ukraine|war|nuclear|germany|europe|military|attack|conflict|troops|invasion|missile|ceasefire|escalat'

        POLY_JSON=$(jq --arg kw "$KEYWORDS" '
            . as $events
            | if type == "array" then $events else [] end
            | map(select(.active == true))
            | map(
                . as $ev
                | ($ev.title // "" | ascii_downcase) as $title
                | select($title | test($kw))
                | {
                    title: $ev.title,
                    slug:  $ev.slug,
                    # best "yes" probability across sub-markets
                    prob_yes: (
                        [ $ev.markets // []
                          | .[]
                          | .outcomePrices // "[]"
                          | if type == "string" then (. | fromjson? // []) else . end
                          | .[0] // "0"
                          | tonumber * 100
                        ] | max // 0 | . * 10 | round / 10
                    ),
                    volume: ($ev.volume // 0),
                  }
              )
            | sort_by(-.prob_yes)
            | .[:8]
        ' "$POLY_FILE" 2>/dev/null || echo '[]')

        HIGH_PROB=$(printf '%s' "$POLY_JSON" | jq '[.[] | select(.prob_yes >= 40)] | length' 2>/dev/null || echo 0)
        MED_PROB=$(printf '%s' "$POLY_JSON" | jq '[.[] | select(.prob_yes >= 20 and .prob_yes < 40)] | length' 2>/dev/null || echo 0)

        if [ "$HIGH_PROB" -gt 0 ]; then
            LEVEL=$(upgrade_level "$LEVEL" "high")
        elif [ "$MED_PROB" -gt 0 ]; then
            LEVEL=$(upgrade_level "$LEVEL" "medium")
        fi
    fi

    QUAKE_THREATS_JSON=$(printf '%s\n' "$QUAKE_THREATS" | jq -Rsc 'split("\n") | map(select(. != ""))' 2>/dev/null || echo '[]')

    MAP_REQUESTS=$(_map_count_get 2>/dev/null || echo 0)
    MAP_WARN=false
    [ "$MAP_REQUESTS" -ge "$MAP_WARN_THRESHOLD" ] && MAP_WARN=true

    jq -n \
        --arg     level          "$LEVEL" \
        --argjson quake_count    "${QUAKE_COUNT:-0}" \
        --argjson top_quake      "${TOP_QUAKE:-null}" \
        --argjson mil_count      "${MIL_COUNT:-0}" \
        --argjson emerg_count    "${EMERG_COUNT:-0}" \
        --argjson gdacs          "${GDACS_JSON:-[]}" \
        --argjson poly           "${POLY_JSON:-[]}" \
        --argjson quake_threats  "$QUAKE_THREATS_JSON" \
        --argjson map_requests   "${MAP_REQUESTS:-0}" \
        --argjson map_warn       "$MAP_WARN" \
        --argjson map_limit      "50000" \
        '{
            threat_level:  $level,
            quake_count:   $quake_count,
            top_quake:     $top_quake,
            mil_count:     $mil_count,
            emerg_count:   $emerg_count,
            gdacs_alerts:  $gdacs,
            poly_markets:  $poly,
            quake_threats: $quake_threats,
            mapbox: {
                requests_this_month: $map_requests,
                free_tier_limit:     $map_limit,
                warn:                $map_warn,
            },
            updated_at:    (now | todate),
        }' > "$SUMMARY_FILE" 2>/dev/null \
        && printf '  Summary: level=%s quakes=%d mil=%d mapbox=%d/50000\n' \
            "$LEVEL" "${QUAKE_COUNT:-0}" "${MIL_COUNT:-0}" "${MAP_REQUESTS:-0}" \
        || printf '  Summary: write failed\n'

    # touch trigger file — quickshell FileView watches this to know when to re-read
    touch "$CACHE_DIR/.updated"
}

# ── build pins json ───────────────────────────────────────────────────────────
# reads quakes, flights, and gdacs from summary.json and converts each pin's
# lat/lon into x/y pixel coordinates on the 800x780 QML image using Web Mercator.
# result written to pins.json — quickshell reads this to overlay tooltip zones.
#
# mercator math (512px base tile, zoom 5):
#   global_x = ((lon + 180) / 360) * 512 * 2^5
#   global_y = (1 - ln(tan(lat_rad) + 1/cos(lat_rad)) / pi) * 256 * 2^5
#   image_x  = 400 + (global_x - center_global_x)
#   image_y  = 390 + (global_y - center_global_y)

build_pins_json() {
    [ -f "$SUMMARY_FILE" ] || return 0

    printf 'Building pins.json...\n'

    # raw pin list — one JSON object per line, extracted from summary + flights
    RAW_PINS=""

    # earthquake pins — top 9 by magnitude (leaves slot for military/squawk/gdacs)
    if [ -f "$QUAKES_FILE" ]; then
        QUAKE_PINS_RAW=$(jq -r '
            .features // []
            | sort_by(-( .properties.mag // .properties.ml // 0 ))
            | .[:9][]
            | {
                type:  "quake",
                lon:   .geometry.coordinates[0],
                lat:   .geometry.coordinates[1],
                title: (
                    "M\(.properties.mag // .properties.ml // 0 | . * 10 | round / 10) — \(.properties.place // .properties.flynn_region // "Unknown")"
                ),
                mag: (.properties.mag // .properties.ml // 0)
              }
            | @json
        ' "$QUAKES_FILE" 2>/dev/null)
        RAW_PINS=$(printf '%s\n%s' "$RAW_PINS" "$QUAKE_PINS_RAW")
    fi

    # military aircraft pins — top 3 matching callsign prefixes
    if [ -f "$FLIGHTS_FILE" ]; then
        MIL_PINS_RAW=$(jq -r --arg pats "$MIL_PREFIXES" '
            .states // []
            | map(select(. != null))
            | map(select(
                (.[1] // "" | ltrimstr(" ") | rtrimstr(" ") | ascii_upcase) | test($pats)
              ))
            | map(select(.[5] != null and .[6] != null))
            | .[:3][]
            | {
                type:  "military",
                lon:   .[5],
                lat:   .[6],
                title: (
                    (.[1] | ltrimstr(" ") | rtrimstr(" ")) + " — " +
                    (.[2] // "Unknown") +
                    if .[7] != null then
                        " — " + (.[7] * 3.28084 | floor | tostring) + "ft"
                    else "" end
                )
              }
            | @json
        ' "$FLIGHTS_FILE" 2>/dev/null)
        RAW_PINS=$(printf '%s\n%s' "$RAW_PINS" "$MIL_PINS_RAW")

        # emergency squawk pins — top 2
        EMERG_PINS_RAW=$(jq -r --arg sq "$EMERG_SQUAWKS" '
            .states // []
            | map(select(. != null))
            | map(select((.[14] // "") | test($sq)))
            | map(select(.[5] != null and .[6] != null))
            | .[:2][]
            | {
                type:  "emergency",
                lon:   .[5],
                lat:   .[6],
                title: (
                    "EMERGENCY sq=" + (.[14] // "?") + " — " +
                    (.[1] | ltrimstr(" ") | rtrimstr(" ")) +
                    " (" + (.[2] // "Unknown") + ")"
                )
              }
            | @json
        ' "$FLIGHTS_FILE" 2>/dev/null)
        RAW_PINS=$(printf '%s\n%s' "$RAW_PINS" "$EMERG_PINS_RAW")
    fi

    # GDACS in-region red/orange pins — top 1
    GDACS_PINS_RAW=$(jq -r '
        .gdacs_alerts // []
        | map(select(.in_region == true and .lat != null and .lon != null))
        | map(select(.level == "red" or .level == "orange"))
        | .[:1][]
        | {
            type:  "gdacs",
            lon:   .lon,
            lat:   .lat,
            title: (.level | ascii_upcase) + " GDACS — " + (.title[:60])
          }
        | @json
    ' "$SUMMARY_FILE" 2>/dev/null)
    RAW_PINS=$(printf '%s\n%s' "$RAW_PINS" "$GDACS_PINS_RAW")

    # strip blank lines, collect into a JSON array, apply Mercator projection
    PINS_ARRAY=$(printf '%s\n' "$RAW_PINS" \
        | grep -v '^$' \
        | jq -sc '
            def pi:    3.141592653589793;
            def clon:  10.45;
            def clat:  50.609;
            def zoom:  5;
            def iw:    800;
            def ih:    780;

            # Web Mercator global pixel (512px base tile)
            def gx(lon): ((lon + 180) / 360) * 512 * pow(2; zoom);
            def gy(lat):
                (lat * pi / 180) as $r
                | (1 - ( ((1 + ($r|sin)) / (1 - ($r|sin)) | log) / 2 / pi))
                  * 256 * pow(2; zoom);

            # center anchor in global pixels
            gx(clon) as $cx | gy(clat) as $cy

            | map(
                . as $p
                | (iw / 2 + (gx($p.lon) - $cx) | round) as $ix
                | (ih / 2 + (gy($p.lat) - $cy) | round) as $iy
                | $p + { x: $ix, y: $iy }
              )
        ' 2>/dev/null || echo '[]')

    printf '%s\n' "$PINS_ARRAY" > "$PINS_FILE"
    printf '  pins.json: %d pins written\n' \
        "$(jq 'length' "$PINS_FILE" 2>/dev/null || echo '?')"
}

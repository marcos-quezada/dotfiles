// Utils.qml — pure logic for the threatwatch module.
// no Quickshell imports; all functions are testable with qmltestrunner.
// ThreatWatchModel uses these helpers; tests import this file directly.

import QtQuick

QtObject {
    // level → colour map — all widgets read this via ThreatWatchModel.levelColors.
    // colours chosen for legibility on the light (#d8d8d8) default bar base.
    readonly property var levelColors: ({
        "critical": "#cc0000",
        "high":     "#cc5500",
        "medium":   "#997700",
        "low":      "#336600",
        "info":     "#444444",
    })

    // parse a threat summary JSON string; return an object with the extracted
    // fields, or null if the JSON is invalid or empty.
    function parseSummary(raw) {
        if (!raw) return null
        var s
        try { s = JSON.parse(raw) } catch(e) { return null }
        var mb = s.mapbox || {}
        return {
            level:       s.threat_level || "",
            updatedAt:   formatTimestamp(s.updated_at || ""),
            mapRequests: mb.requests_this_month || 0,
            mapWarn:     mb.warn || false,
        }
    }

    // format ISO 8601 timestamp "2025-01-15T14:32:00Z" → "2025-01-15 14:32 UTC".
    // returns "" for empty input.
    function formatTimestamp(iso) {
        if (!iso) return ""
        var ts = iso.replace("T", " ").replace("Z", "")
        return ts.substring(0, 16) + " UTC"
    }

    // parse a pins JSON string; return the array, or null if invalid.
    // accepts only a top-level array — objects and primitives are rejected.
    function parsePins(raw) {
        try {
            var parsed = JSON.parse(raw)
            return Array.isArray(parsed) ? parsed : null
        } catch (e) {
            return null
        }
    }

    // human-readable label for a pin type string.
    function pinTypeLabel(type) {
        if (type === "quake")     return "Earthquake"
        if (type === "military")  return "Military aircraft"
        if (type === "emergency") return "Emergency squawk"
        if (type === "gdacs")     return "GDACS disaster alert"
        return ""
    }
}

// Utils.qml — pure logic for the threatwatch module.
// no Quickshell imports; all functions are testable with qmltestrunner.
// ThreatWatchModel uses these helpers; tests import this file directly.

import QtQuick
import qs 

QtObject {
      // level → colour map — currently unused (ThreatWatchWidget removed); kept for
      // the planned popup status summary. do not delete without deciding what
      // replaces it (see docs/architecture.md).
      property var levelColors: ({
        "critical": Config.colors.danger,
        "high":     Config.colors.urgent,
        "medium":   Config.colors.warning,
        "low":      Config.colors.accent,
        "info":     Config.colors.text,
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

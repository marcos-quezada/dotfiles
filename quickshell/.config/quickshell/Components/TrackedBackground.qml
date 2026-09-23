import QtQuick

// TrackedBackground.qml - a decoration layer that binds to another item's
// geometry, rather than containing it. background tracks content bounds, it
// never lays out or contains the content itself. avoids the whole class of 
// magic number margin drift that comes from trying to size wrapping container
// to match content that lives inside it.
//
// styling (color/border.*) is intentionally left as plain inherited
// Rectangle properties, not declared here - this component only adds
// tracking, it has no opinion on theme colors (see architecture.md's
// "Components/ - shared, generic UI atoms" convention).
Rectangle {
    id: root

    required property Item target
    // if target lives in a different coordinate space (e.g. nested inside
    // a RowLayout that isn't a direct child of whatever root is anchored
    // to), pass the itemto translate into. leave null if target's x/y
    // are already in the right space.
    property Item mapTarget: null
    property int  padding:  3 

    x: {
        target.x
        return (mapTarget ? target.mapToItem(mapTarget, 0, 0).x : target.x) - padding
    }
    y: {
        target.y
        return (mapTarget ? target.mapToItem(mapTarget, 0, 0).y : target.y) - padding
    }
    width:  target.width  + padding * 2
    height: target.height + padding * 2
}

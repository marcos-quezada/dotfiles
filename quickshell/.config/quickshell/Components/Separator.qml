import QtQuick

// Sepparator.qml - a thin vertical "etched groove" divider, matching the
// clasic win95 toolbar convention for marking a section boundary without
// wrapping either side in a full sunken panel. Two 1px lines side by side
// (shadow then highlight) read as a subtle engraved line, using the same
// bevel colors as everything else in this project.
Item {
    id:            root
    implicitWidth: 2
    
    property color shadowColor
    property color highlightColor

    Rectangle {
        width:  1
        height: parent.height
        color:  root.shadowColor
    }
    Rectangle {
        x:      1
        width:  1
        height: parent.height
        color:  root.highlightColor
    }
}

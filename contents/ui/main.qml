import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property real memTotalKb: 0
    property real memUsedKb: 0
    property real swapTotalKb: 0
    property real swapUsedKb: 0
    property real gpuTotalKb: 0
    property real gpuUsedKb: 0
    property bool memTotalLoaded: false
    property bool swapTotalLoaded: false
    property bool gpuTotalLoaded: false

    readonly property color usedColor: plasmoid.configuration.ramColor
    readonly property color swapColor: plasmoid.configuration.swapColor
    readonly property color gpuColor: plasmoid.configuration.gpuColor
    readonly property color trackColor: plasmoid.configuration.trackColor
    readonly property int updateMs: Math.max(500, (plasmoid.configuration.updateInterval || 5) * 1000)

    toolTipMainText: ""
    toolTipSubText: ""

    function formatKb(kb) {
        if (kb >= 1048576) {
            return (kb / 1048576).toFixed(1) + " GiB"
        } else if (kb >= 1024) {
            return (kb / 1024).toFixed(1) + " MiB"
        } else {
            return kb.toFixed(0) + " KiB"
        }
    }

    Sensors.Sensor {
        sensorId: "memory/physical/total"
        updateRateLimit: root.updateMs
        enabled: !root.memTotalLoaded
        onValueChanged: {
            if (value !== undefined && !isNaN(value)) {
                root.memTotalKb = Math.max(0, Number(value) / 1024)
                root.memTotalLoaded = true
            }
        }
    }
    Sensors.Sensor {
        sensorId: "memory/physical/used"
        updateRateLimit: root.updateMs
        enabled: true
        onValueChanged: {
            if (value !== undefined && !isNaN(value)) root.memUsedKb = Math.max(0, Number(value) / 1024)
        }
    }
    Sensors.Sensor {
        sensorId: "memory/swap/total"
        updateRateLimit: root.updateMs
        enabled: !root.swapTotalLoaded || root.expanded
        onValueChanged: {
            if (value !== undefined && !isNaN(value)) {
                root.swapTotalKb = Math.max(0, Number(value) / 1024)
                root.swapTotalLoaded = true
            }
        }
    }
    Sensors.Sensor {
        sensorId: "memory/swap/used"
        updateRateLimit: root.updateMs
        enabled: true
        onValueChanged: {
            if (value !== undefined && !isNaN(value)) root.swapUsedKb = Math.max(0, Number(value) / 1024)
        }
    }
    Sensors.Sensor {
        sensorId: "gpu/all/totalVram"
        updateRateLimit: root.updateMs
        enabled: !root.gpuTotalLoaded
        onValueChanged: {
            if (value !== undefined && !isNaN(value)) {
                root.gpuTotalKb = Math.max(0, Number(value) / 1024)
                root.gpuTotalLoaded = true
            }
        }
    }
    Sensors.Sensor {
        sensorId: "gpu/all/usedVram"
        updateRateLimit: root.updateMs
        enabled: true
        onValueChanged: {
            if (value !== undefined && !isNaN(value)) root.gpuUsedKb = Math.max(0, Number(value) / 1024)
        }
    }

    component UsageBar: ColumnLayout {
        id: barRoot
        property string label: ""
        property real usedKb: 0
        property real totalKb: 0
        property color barColor: "#ff2fc0"
        property bool showRow: true
        property bool animEnabled: true

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing / 2
        visible: showRow

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: barRoot.label
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            PlasmaComponents3.Label {
                text: root.formatKb(barRoot.usedKb)
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 0.55
            radius: height / 2
            color: root.trackColor
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: parent.radius
                color: barRoot.barColor
                width: barRoot.totalKb > 0
                    ? parent.width * Math.max(0, Math.min(1, barRoot.usedKb / barRoot.totalKb))
                    : 0

                Behavior on width {
                    enabled: barRoot.animEnabled
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // Small icon-style bars used when the plasmoid sits in a panel.
    // Sized to the panel's thickness so it actually shrinks with the panel,
    // instead of forcing the full-representation's width/height.
    compactRepresentation: Item {
        id: compact

        readonly property bool isPanelVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property bool isVerticalLayout: {
            var opt = Number(plasmoid.configuration.displayOrientation);
            if (opt === 1) return false;
            if (opt === 2) return true;
            return compact.isPanelVertical;
        }

        readonly property int barThickness: plasmoid.configuration.barThickness
        readonly property int barGap: 3
        readonly property int margin: 4
        readonly property int barLength: plasmoid.configuration.barLength

        Layout.fillWidth: compact.isPanelVertical
        Layout.preferredWidth: {
            if (compact.isPanelVertical) {
                return -1;
            }
            if (compact.isVerticalLayout) {
                var numBars = 1 + (root.swapTotalKb > 0 ? 1 : 0) + (root.gpuTotalKb > 0 ? 1 : 0);
                return numBars * compact.barThickness + (numBars - 1) * compact.barGap + compact.margin * 2;
            } else {
                return compact.barLength;
            }
        }
        Layout.minimumWidth: Layout.preferredWidth

        Layout.fillHeight: !compact.isPanelVertical
        Layout.preferredHeight: {
            if (!compact.isPanelVertical) {
                return -1;
            }
            if (compact.isVerticalLayout) {
                return compact.barLength;
            } else {
                var numBars = 1 + (root.swapTotalKb > 0 ? 1 : 0) + (root.gpuTotalKb > 0 ? 1 : 0);
                return numBars * compact.barThickness + (numBars - 1) * compact.barGap + compact.margin * 2;
            }
        }
        Layout.minimumHeight: Layout.preferredHeight

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }

        component CompactBar: Rectangle {
            id: barItem
            property real usedKb: 0
            property real totalKb: 0
            property color barColor: "#ffffff"
            property bool verticalFill: false
            property bool showBar: true
            property bool animEnabled: true

            visible: showBar
            Layout.fillWidth: !verticalFill
            Layout.fillHeight: verticalFill
            Layout.preferredWidth: verticalFill ? compact.barThickness : -1
            Layout.preferredHeight: verticalFill ? -1 : compact.barThickness
            radius: (verticalFill ? width : height) / 2
            color: root.trackColor
            clip: true

            readonly property real ratio: barItem.totalKb > 0 ? Math.max(0, Math.min(1, barItem.usedKb / barItem.totalKb)) : 0

            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.top: barItem.verticalFill ? undefined : parent.top
                anchors.right: barItem.verticalFill ? parent.right : undefined
                radius: parent.radius
                color: barItem.barColor
                width: barItem.verticalFill ? parent.width : Math.round(barItem.ratio * parent.width * 2) / 2
                height: barItem.verticalFill ? Math.round(barItem.ratio * parent.height * 2) / 2 : parent.height
                Behavior on width { enabled: barItem.animEnabled && !barItem.verticalFill; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: barItem.animEnabled && barItem.verticalFill; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }

        // Horizontal layout (horizontal bars, stacked):
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - compact.margin * 2
            spacing: compact.barGap
            visible: !compact.isVerticalLayout

            CompactBar { usedKb: root.memUsedKb; totalKb: root.memTotalKb; barColor: root.usedColor; verticalFill: false; animEnabled: !compact.isVerticalLayout }
            CompactBar { usedKb: root.swapUsedKb; totalKb: root.swapTotalKb; barColor: root.swapColor; verticalFill: false; showBar: root.swapTotalKb > 0; animEnabled: !compact.isVerticalLayout }
            CompactBar { usedKb: root.gpuUsedKb; totalKb: root.gpuTotalKb; barColor: root.gpuColor; verticalFill: false; showBar: root.gpuTotalKb > 0; animEnabled: !compact.isVerticalLayout }
        }

        // Vertical layout (vertical bars, side-by-side):
        RowLayout {
            anchors.centerIn: parent
            height: parent.height - compact.margin * 2
            spacing: compact.barGap
            visible: compact.isVerticalLayout

            CompactBar { usedKb: root.memUsedKb; totalKb: root.memTotalKb; barColor: root.usedColor; verticalFill: true; animEnabled: compact.isVerticalLayout }
            CompactBar { usedKb: root.swapUsedKb; totalKb: root.swapTotalKb; barColor: root.swapColor; verticalFill: true; showBar: root.swapTotalKb > 0; animEnabled: compact.isVerticalLayout }
            CompactBar { usedKb: root.gpuUsedKb; totalKb: root.gpuTotalKb; barColor: root.gpuColor; verticalFill: true; showBar: root.gpuTotalKb > 0; animEnabled: compact.isVerticalLayout }
        }
    }

    fullRepresentation: ColumnLayout {
        id: fullRepItem

        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        Layout.preferredWidth: plasmoid.configuration.popupWidth
        Layout.preferredHeight: plasmoid.configuration.popupHeight
        spacing: Kirigami.Units.smallSpacing * 2

        onWidthChanged: resizeSaveTimer.restart()
        onHeightChanged: resizeSaveTimer.restart()

        Timer {
            id: resizeSaveTimer
            interval: 250
            repeat: false
            onTriggered: {
                if (plasmoid.expanded && fullRepItem.Window.window && fullRepItem.Window.window.visible) {
                    if (fullRepItem.width >= fullRepItem.Layout.minimumWidth && fullRepItem.width !== plasmoid.configuration.popupWidth) {
                        plasmoid.configuration.popupWidth = fullRepItem.width;
                    }
                    if (fullRepItem.height >= fullRepItem.Layout.minimumHeight && fullRepItem.height !== plasmoid.configuration.popupHeight) {
                        plasmoid.configuration.popupHeight = fullRepItem.height;
                    }
                }
            }
        }

        UsageBar {
            label: "RAM"
            usedKb: root.memUsedKb
            totalKb: root.memTotalKb
            barColor: root.usedColor
            animEnabled: fullRepItem.visible
        }

        UsageBar {
            label: "Swap"
            usedKb: root.swapUsedKb
            totalKb: root.swapTotalKb
            barColor: root.swapColor
            showRow: root.swapTotalKb > 0
            animEnabled: fullRepItem.visible
        }

        UsageBar {
            label: "VRAM"
            usedKb: root.gpuUsedKb
            totalKb: root.gpuTotalKb
            barColor: root.gpuColor
            showRow: root.gpuTotalKb > 0
            animEnabled: fullRepItem.visible
        }
    }
}

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // Let Plasma pick: full bars directly on the desktop, small compact
    // icon-style bars when placed in a panel (click to pop up full detail).

    property real memTotalKb: 0
    property real memAvailableKb: 0
    property real memUsedKb: 0
    property real swapTotalKb: 0
    property real swapFreeKb: 0
    property real swapUsedKb: 0
    property real zramUsedKb: 0
    property real gpuTotalKb: 0
    property real gpuUsedKb: 0

    readonly property color usedColor: plasmoid.configuration.ramColor
    readonly property color swapColor: plasmoid.configuration.swapColor
    readonly property color gpuColor: plasmoid.configuration.gpuColor
    readonly property color trackColor: plasmoid.configuration.trackColor

    toolTipMainText: ""
    toolTipSubText: ""

    function kbToGib(kb) {
        return kb / 1048576
    }

    function formatKb(kb) {
        if (kb >= 1048576) {
            return (kb / 1048576).toFixed(1) + " GiB"
        } else if (kb >= 1024) {
            return (kb / 1024).toFixed(1) + " MiB"
        } else {
            return kb.toFixed(0) + " KiB"
        }
    }

    function parseMemInfo(text) {
        var lines = text.split("\n")
        var map = {}
        for (var i = 0; i < lines.length; i++) {
            var idx = lines[i].indexOf(":")
            if (idx < 0) continue
            var key = lines[i].substring(0, idx).trim()
            var rest = lines[i].substring(idx + 1).trim()
            var num = parseFloat(rest.replace(" kB", "").replace(" KB", ""))
            if (!isNaN(num)) map[key] = num
        }
        if (map["MemTotal"] !== undefined) memTotalKb = map["MemTotal"]
        if (map["MemAvailable"] !== undefined) memAvailableKb = map["MemAvailable"]
        memUsedKb = Math.max(0, memTotalKb - memAvailableKb)

        if (map["SwapTotal"] !== undefined) swapTotalKb = map["SwapTotal"]
        if (map["SwapFree"] !== undefined) swapFreeKb = map["SwapFree"]
        if (zramUsedKb > 0) {
            swapUsedKb = zramUsedKb
        } else {
            swapUsedKb = Math.max(0, swapTotalKb - swapFreeKb)
        }
    }

    function parseZramInfo(text) {
        var lines = text.trim().split("\n")
        var totalBytes = 0
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var tokens = line.split(/\s+/)
            if (tokens.length >= 3) {
                var memUsedBytes = parseFloat(tokens[2])
                if (!isNaN(memUsedBytes)) {
                    totalBytes += memUsedBytes
                }
            }
        }
        if (totalBytes > 0) {
            zramUsedKb = totalBytes / 1024
            swapUsedKb = zramUsedKb
        }
    }

    function parseGpuInfo(text) {
        // Parse sysfs VRAM info (single number in bytes)
        var bytes = parseInt(text.trim())
        if (!isNaN(bytes)) {
            return bytes / 1024  // Convert bytes to KB
        }
        return 0
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            var stdout = data["stdout"]
            if (stdout) {
                if (sourceName.indexOf("meminfo") >= 0) {
                    parseMemInfo(stdout)
                } else if (sourceName.indexOf("zram") >= 0) {
                    parseZramInfo(stdout)
                } else if (sourceName.indexOf("vram_total") >= 0) {
                    gpuTotalKb = parseGpuInfo(stdout)
                } else if (sourceName.indexOf("vram_used") >= 0) {
                    gpuUsedKb = parseGpuInfo(stdout)
                }
            }
            disconnectSource(sourceName)
        }
        function exec(cmd) {
            connectSource(cmd)
        }
    }

    Timer {
        id: pollTimer
        interval: (plasmoid.configuration.updateInterval || 2) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            executable.exec("cat /proc/meminfo")
            executable.exec("cat /sys/block/zram*/mm_stat 2>/dev/null")
            executable.exec("cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null")
            executable.exec("cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null")
        }
    }

    component UsageBar: ColumnLayout {
        id: barRoot
        property string label: ""
        property real usedKb: 0
        property real totalKb: 0
        property color barColor: "#ff2fc0"
        property bool showRow: true

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

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: parent.radius
                color: barRoot.barColor
                width: barRoot.totalKb > 0
                    ? Math.min(parent.width, parent.width * (barRoot.usedKb / barRoot.totalKb))
                    : 0

                Behavior on width {
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

        // Horizontal layout (horizontal bars, stacked):
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - compact.margin * 2
            spacing: compact.barGap
            visible: !compact.isVerticalLayout

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: compact.barThickness
                radius: height / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.usedColor
                    width: root.memTotalKb > 0 ? parent.width * (root.memUsedKb / root.memTotalKb) : 0
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                visible: root.swapTotalKb > 0
                Layout.fillWidth: true
                Layout.preferredHeight: compact.barThickness
                radius: height / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.swapColor
                    width: root.swapTotalKb > 0 ? parent.width * (root.swapUsedKb / root.swapTotalKb) : 0
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                visible: root.gpuTotalKb > 0
                Layout.fillWidth: true
                Layout.preferredHeight: compact.barThickness
                radius: height / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.gpuColor
                    width: root.gpuTotalKb > 0 ? parent.width * (root.gpuUsedKb / root.gpuTotalKb) : 0
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }
        }

        // Vertical layout (vertical bars, side-by-side):
        RowLayout {
            anchors.centerIn: parent
            height: parent.height - compact.margin * 2
            spacing: compact.barGap
            visible: compact.isVerticalLayout

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: compact.barThickness
                radius: width / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.usedColor
                    height: root.memTotalKb > 0 ? parent.height * (root.memUsedKb / root.memTotalKb) : 0
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                visible: root.swapTotalKb > 0
                Layout.fillHeight: true
                Layout.preferredWidth: compact.barThickness
                radius: width / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.swapColor
                    height: root.swapTotalKb > 0 ? parent.height * (root.swapUsedKb / root.swapTotalKb) : 0
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                visible: root.gpuTotalKb > 0
                Layout.fillHeight: true
                Layout.preferredWidth: compact.barThickness
                radius: width / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.gpuColor
                    height: root.gpuTotalKb > 0 ? parent.height * (root.gpuUsedKb / root.gpuTotalKb) : 0
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    fullRepresentation: ColumnLayout {
        id: fullRepItem

        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        Layout.preferredWidth: plasmoid.configuration.popupWidth
        Layout.preferredHeight: plasmoid.configuration.popupHeight
        spacing: Kirigami.Units.smallSpacing * 2

        onWidthChanged: {
            if (plasmoid.expanded && width >= Layout.minimumWidth && width !== plasmoid.configuration.popupWidth) {
                plasmoid.configuration.popupWidth = width;
            }
        }
        onHeightChanged: {
            if (plasmoid.expanded && height >= Layout.minimumHeight && height !== plasmoid.configuration.popupHeight) {
                plasmoid.configuration.popupHeight = height;
            }
        }

        UsageBar {
            label: "RAM"
            usedKb: root.memUsedKb
            totalKb: root.memTotalKb
            barColor: root.usedColor
        }

        UsageBar {
            label: "Swap"
            usedKb: root.swapUsedKb
            totalKb: root.swapTotalKb
            barColor: root.swapColor
            showRow: root.swapTotalKb > 0
        }

        UsageBar {
            label: "VRAM"
            usedKb: root.gpuUsedKb
            totalKb: root.gpuTotalKb
            barColor: root.gpuColor
            showRow: root.gpuTotalKb > 0
        }
    }
}

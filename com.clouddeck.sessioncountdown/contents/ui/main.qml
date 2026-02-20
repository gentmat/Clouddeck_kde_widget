import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Shapes 1.15
import QtMultimedia

import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.plasma5support 2.0 as P5Support

PlasmoidItem {
    id: root

    // ── config ───────────────────────────────────────────────────────────────
    readonly property int totalSeconds: Math.max(0,
        (Math.max(0, Number(Plasmoid.configuration.durationHours)) * 3600)
        + (Math.max(0, Number(Plasmoid.configuration.durationMinutes)) * 60))

    readonly property string bootAnchorScriptPath: localPathFromUrl(Qt.resolvedUrl("../scripts/boot_anchor_from_shutdown.sh"))
    readonly property string currentBootScriptPath: localPathFromUrl(Qt.resolvedUrl("../scripts/current_boot_epoch.sh"))
    readonly property string bootAnchorCommand: "bash \"" + bootAnchorScriptPath + "\""
    readonly property string currentBootCommand: "bash \"" + currentBootScriptPath + "\""
    // Sound file bundled with the plasmoid — drop any MP3/WAV/OGG here
    readonly property url beepSoundUrl: Qt.resolvedUrl("../sounds/beep.mp3")

    // ── state ────────────────────────────────────────────────────────────────
    property int remainingSeconds: 0
    property int previousRemainingSeconds: 0
    property int anchorEpochSeconds: 0
    property bool anchorReady: false
    readonly property int bootAnchorOffsetSeconds: 10

    property var triggeredWarningSeconds: ({})

    // ── derived ──────────────────────────────────────────────────────────────
    readonly property real textOpacity: 1.0

    readonly property real progressRatio: totalSeconds > 0
        ? Math.max(0.0, Math.min(1.0, remainingSeconds / totalSeconds))
        : 0.0

    readonly property int urgency: {
        if (remainingSeconds <= 0)                            return 2
        if (totalSeconds > 0 && progressRatio <= 0.1)         return 2
        if (totalSeconds > 0 && progressRatio <= 0.25)        return 1
        return 0
    }

    // ── dynamic urgency colour ──────────────────────────────────────────────────
    // green (ok) → amber (warning) → red (critical).
    readonly property color arcColor: {
        return urgency === 2 ? "#ef4444"
             : urgency === 1 ? "#f59e0b"
             :                 "#22c55e"
    }

    // Desktop background opacity (0–100)
    readonly property real bgOpacity: Math.max(0, Math.min(1.0,
        Number(Plasmoid.configuration.backgroundOpacity) / 100.0))

    // ── plasmoid meta ─────────────────────────────────────────────────────────
    Plasmoid.icon: "chronometer"
    Plasmoid.title: i18n("Session Countdown")
    Plasmoid.status: remainingSeconds > 0 ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    // Remove Plasma's own widget frame on desktop → our Rectangle becomes the background
    Plasmoid.backgroundHints: Plasmoid.formFactor === PlasmaCore.Types.Planar
        ? PlasmaCore.Types.NoBackground
        : PlasmaCore.Types.DefaultBackground

    toolTipMainText: Plasmoid.title
    toolTipSubText: anchorReady ? formattedTime(remainingSeconds) : i18n("Reading shutdown and boot history...")

    // ── helpers ───────────────────────────────────────────────────────────────
    function localPathFromUrl(url) {
        const text = url.toString()
        if (text.indexOf("file://") === 0) return decodeURIComponent(text.slice(7))
        return text
    }

    function formattedTime(total) {
        const clamped = Math.max(0, total)
        const h = Math.floor(clamped / 3600)
        const m = Math.floor((clamped % 3600) / 60)
        const s = clamped % 60
        return twoDigits(h) + ":" + twoDigits(m) + ":" + twoDigits(s)
    }

    function twoDigits(v) { return v < 10 ? "0" + v : "" + v }

    function parseWarningSecondsList() {
        const csv = ((Plasmoid.configuration.warningMinutesCsv || "") + "")
        const seen = ({})
        const result = []
        csv.split(",").forEach(function(piece) {
            const t = piece.trim()
            if (!t) return
            const pm = parseInt(t, 10)
            if (isNaN(pm)) return
            const ws = Math.max(0, pm) * 60
            const key = "" + ws
            if (seen[key]) return
            seen[key] = true
            result.push(ws)
        })
        result.sort(function(a, b) { return b - a })
        return result
    }

    function warningTriggerEpochSeconds(ws) {
        if (!anchorReady || ws > totalSeconds) return -1
        return anchorEpochSeconds + Math.max(0, totalSeconds - ws)
    }

    function warningTriggerAtText(ws) {
        if (!anchorReady) return i18n("Waiting for boot time...")
        const te = warningTriggerEpochSeconds(ws)
        if (te < 0) return i18n("Outside timer range")
        return Qt.formatDateTime(new Date(te * 1000), "HH:mm:ss")
    }

    function requestBootAnchorEpoch() { anchorCommandSource.connectSource(bootAnchorCommand) }

    function applyAnchorEpoch(epochSeconds) {
        if (isNaN(epochSeconds) || epochSeconds <= 0)
            epochSeconds = Math.floor(Date.now() / 1000)
        anchorEpochSeconds = Math.max(0, epochSeconds - bootAnchorOffsetSeconds)
        anchorReady = true
        resetRuntimeState()
    }

    function resetRuntimeState() {
        triggeredWarningSeconds = ({})
        // beepBurstTimer.stop()  // removed — burst timer no longer used
        updateRemainingTime(false)
        // On launch: silently mark alarms whose time has already passed
        const preFired = {}
        parseWarningSecondsList().forEach(function(ws) {
            if (remainingSeconds <= ws) preFired["" + ws] = true
        })
        if (Object.keys(preFired).length > 0) triggeredWarningSeconds = preFired
        if (anchorReady && remainingSeconds > 0) tickTimer.start()
        else tickTimer.stop()
    }

    function updateRemainingTime(emitWarnings) {
        if (!anchorReady) {
            remainingSeconds = totalSeconds
            previousRemainingSeconds = totalSeconds
            return
        }
        const now = Math.floor(Date.now() / 1000)
        const elapsed = Math.max(0, now - anchorEpochSeconds)
        const next = Math.max(0, totalSeconds - elapsed)
        if (emitWarnings) checkWarnings(previousRemainingSeconds, next)
        remainingSeconds = next
        previousRemainingSeconds = next
        if (remainingSeconds <= 0) {
            tickTimer.stop()
        }
    }

    function checkWarnings(prev, cur) {
        parseWarningSecondsList().forEach(function(ws) {
            const key = "" + ws
            if (triggeredWarningSeconds[key]) return
            if (cur <= ws && prev > ws) {
                var copy = Object.assign({}, triggeredWarningSeconds)
                copy[key] = true
                triggeredWarningSeconds = copy
                triggerSingleBeep()
            }
        })
    }

    function triggerSingleBeep() {
        // Use a lock file to prevent duplicate beeps across widget instances.
        // `set -C` (noclobber) makes the redirect fail atomically if the file exists.
        const lockFile = "/tmp/clouddeck-session-beep.lock"
        const cmd = "(set -C; echo $$ > " + lockFile + ") 2>/dev/null && echo LOCKED || echo SKIP"
        beepLockSource.connectSource(cmd)
    }

    P5Support.DataSource {
        id: beepLockSource
        engine: "executable"; interval: 0
        onNewData: function(sourceName, data) {
            beepLockSource.disconnectSource(sourceName)
            const out = ((data["stdout"] || "") + "").trim()
            if (out === "LOCKED") {
                beepPlayer.stop()
                beepPlayer.play()
                // Remove the lock after 3 seconds so the next alarm can fire
                beepLockCleanup.start()
            }
            // If SKIP, another widget instance already played the beep
        }
    }

    Timer {
        id: beepLockCleanup
        interval: 3000; repeat: false
        onTriggered: {
            const cmd = "rm -f /tmp/clouddeck-session-beep.lock"
            beepLockSource.connectSource(cmd)
        }
    }

    Component.onCompleted: requestBootAnchorEpoch()

    // ── config watchers ───────────────────────────────────────────────────────
    Connections {
        target: Plasmoid.configuration
        function onDurationHoursChanged()    { root.resetRuntimeState() }
        function onDurationMinutesChanged()  { root.resetRuntimeState() }
        function onWarningMinutesCsvChanged(){ root.resetRuntimeState() }
    }

    // ── shared config file sync ───────────────────────────────────────────────
    // Poll a shared file written by configGeneral.qml so that all widget
    // instances stay in sync even though Plasma gives each its own config.
    readonly property string sharedConfigPath: "$HOME/.config/clouddeck-session-shared.conf"

    P5Support.DataSource {
        id: sharedConfigReader
        engine: "executable"
        interval: 0
        onNewData: function(sourceName, data) {
            sharedConfigReader.disconnectSource(sourceName)
            const raw = ((data["stdout"] || "") + "").trim()
            if (!raw) return
            const lines = raw.split("\n")
            const map = {}
            lines.forEach(function(line) {
                const eq = line.indexOf("=")
                if (eq > 0) map[line.substring(0, eq)] = line.substring(eq + 1)
            })
            // Apply shared values if they differ from current config
            if (map["warningMinutesCsv"] !== undefined &&
                map["warningMinutesCsv"] !== (Plasmoid.configuration.warningMinutesCsv || "")) {
                Plasmoid.configuration.warningMinutesCsv = map["warningMinutesCsv"]
            }
            if (map["durationHours"] !== undefined) {
                const h = parseInt(map["durationHours"], 10)
                if (!isNaN(h) && h !== Plasmoid.configuration.durationHours)
                    Plasmoid.configuration.durationHours = h
            }
            if (map["durationMinutes"] !== undefined) {
                const m = parseInt(map["durationMinutes"], 10)
                if (!isNaN(m) && m !== Plasmoid.configuration.durationMinutes)
                    Plasmoid.configuration.durationMinutes = m
            }
            if (map["backgroundOpacity"] !== undefined) {
                const o = parseInt(map["backgroundOpacity"], 10)
                if (!isNaN(o) && o !== Plasmoid.configuration.backgroundOpacity)
                    Plasmoid.configuration.backgroundOpacity = o
            }
        }
    }

    Timer {
        id: sharedConfigPollTimer
        interval: 5000; repeat: true; running: true
        onTriggered: {
            const cmd = "cat \"" + root.sharedConfigPath + "\" 2>/dev/null"
            sharedConfigReader.connectSource(cmd)
        }
    }

    // ── timers ────────────────────────────────────────────────────────────────
    Timer {
        id: tickTimer
        interval: 1000; repeat: true; running: false
        onTriggered: root.updateRemainingTime(true)
    }

    // ── data sources ──────────────────────────────────────────────────────────
    P5Support.DataSource {
        id: anchorCommandSource
        engine: "executable"; interval: 0
        onNewData: function(sourceName, data) {
            if (sourceName !== root.bootAnchorCommand && sourceName !== root.currentBootCommand) return
            if (typeof data["stdout"] === "undefined" && typeof data["exit code"] === "undefined") return
            const raw = ((data["stdout"] || "") + "").trim()
            const parsed = parseInt(raw, 10)
            anchorCommandSource.disconnectSource(sourceName)
            if (isNaN(parsed) || parsed <= 0) {
                if (sourceName === root.bootAnchorCommand) {
                    anchorCommandSource.connectSource(root.currentBootCommand)
                    return
                }
            }
            root.applyAnchorEpoch(parsed)
        }
    }

    // ── audio ─────────────────────────────────────────────────────────────────
    MediaPlayer {
        id: beepPlayer
        source: root.beepSoundUrl
        audioOutput: AudioOutput { volume: 1.0 }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // COMPACT REPRESENTATION  (shown in taskbar/panel)
    // Uses KDE's official Layout.minimumWidth/Height pattern based on formFactor.
    // ─────────────────────────────────────────────────────────────────────────
    compactRepresentation: Item {
        // KDE official pattern: base minimum size on formFactor
        Layout.minimumWidth: {
            switch (Plasmoid.formFactor) {
            case PlasmaCore.Types.Vertical:
                return 0
            case PlasmaCore.Types.Horizontal:
                return timerText.implicitWidth + Kirigami.Units.smallSpacing * 2
            default:
                return Kirigami.Units.gridUnit * 5
            }
        }
        Layout.minimumHeight: {
            switch (Plasmoid.formFactor) {
            case PlasmaCore.Types.Vertical:
                return timerText.implicitHeight + Kirigami.Units.smallSpacing * 2
            case PlasmaCore.Types.Horizontal:
                return 0
            default:
                return Kirigami.Units.gridUnit * 2
            }
        }

        PlasmaComponents3.Label {
            id: timerText
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.formattedTime(root.remainingSeconds)
            color: root.arcColor
            font.family: "monospace"
            font.bold: true
            font.pixelSize: Math.max(11, Math.round(parent.height * 0.52))
            leftPadding: Kirigami.Units.largeSpacing
            rightPadding: Kirigami.Units.largeSpacing
            Behavior on color { ColorAnimation { duration: 600 } }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
            cursorShape: Qt.PointingHandCursor
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FULL REPRESENTATION  (shown in popup when compact is clicked)
    // Plasma wraps this in its own standard themed panel automatically.
    // When placed on the desktop, we draw our own background.
    // ─────────────────────────────────────────────────────────────────────────
    fullRepresentation: Item {
        id: fullRepRoot
        
        // Ensure Plasma requests at least enough size for the content
        implicitWidth: contentLayout.implicitWidth + Kirigami.Units.largeSpacing * 2
        implicitHeight: contentLayout.height + Kirigami.Units.largeSpacing * 2
        
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight

        // Background behind all content — strictly bounds to the layout's actual rendered size
        Rectangle {
            z: -1
            x: 0; y: 0
            width: contentLayout.width + Kirigami.Units.largeSpacing * 2
            height: contentLayout.height + Kirigami.Units.largeSpacing * 2
            radius: Kirigami.Units.largeSpacing
            color: "#000000"
            opacity: root.bgOpacity
            visible: Plasmoid.formFactor === PlasmaCore.Types.Planar
        }

        ColumnLayout {
            id: contentLayout
            x: Kirigami.Units.largeSpacing
            y: Kirigami.Units.largeSpacing
            
            // Expand to fill the container, but never compress smaller than our children need
            width: Math.max(implicitWidth, parent.width - Kirigami.Units.largeSpacing * 2)
            spacing: Kirigami.Units.largeSpacing

        // ── Header ──────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Kirigami.Heading {
                level: 4
                text: i18n("Session Countdown")
                Layout.fillWidth: true
                color: "#ffffff"
            }

            PlasmaComponents3.ToolButton {
                icon.name: "configure"
                flat: true
                PlasmaComponents3.ToolTip.text: i18n("Configure")
                PlasmaComponents3.ToolTip.visible: hovered
                onClicked: {
                    root.expanded = false
                    Plasmoid.internalAction("configure").trigger()
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // ── Arc + Timer ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 8

            Shape {
                id: arcShape
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                layer.enabled: true
                layer.samples: 8

                ShapePath {
                    strokeWidth: Math.max(6, arcShape.width * 0.07)
                    strokeColor: Qt.rgba(root.arcColor.r, root.arcColor.g, root.arcColor.b, 0.15)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: arcShape.width / 2; centerY: arcShape.height / 2
                        radiusX: (arcShape.width - strokeWidth * 2) / 2
                        radiusY: radiusX
                        startAngle: -225; sweepAngle: 270
                    }
                }

                ShapePath {
                    strokeWidth: Math.max(6, arcShape.width * 0.07)
                    strokeColor: root.arcColor
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: arcShape.width / 2; centerY: arcShape.height / 2
                        radiusX: (arcShape.width - strokeWidth * 2) / 2
                        radiusY: radiusX
                        startAngle: -225
                        sweepAngle: 270 * root.progressRatio
                        Behavior on sweepAngle { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.largeSpacing * 4
                spacing: 2

                PlasmaComponents3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.formattedTime(root.remainingSeconds)
                    font.family: "monospace"
                    font.bold: true
                    fontSizeMode: Text.HorizontalFit
                    font.pixelSize: Kirigami.Units.gridUnit * 2.2
                    minimumPixelSize: Kirigami.Units.gridUnit
                    color: root.arcColor
                    opacity: root.textOpacity
                    Behavior on color { ColorAnimation { duration: 600 } }
                }

                PlasmaComponents3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: !root.anchorReady ? i18n("Initialising…")
                        : root.remainingSeconds <= 0 ? i18n("Time's Up")
                        : i18n("remaining")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.55
                    font.capitalization: Font.AllUppercase
                }
            }
        }

        // ── Progress Bar ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Qt.rgba(root.arcColor.r, root.arcColor.g, root.arcColor.b, 0.15)
            clip: true

            Rectangle {
                height: parent.height
                width: parent.width * root.progressRatio
                radius: 3
                color: root.arcColor
                Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 600 } }
            }
        }

        // ── Status ───────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Rectangle {
                width: 8; height: 8; radius: 4
                color: root.arcColor
                Behavior on color { ColorAnimation { duration: 600 } }
                SequentialAnimation on opacity {
                    running: root.urgency === 2 && root.remainingSeconds > 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            PlasmaComponents3.Label {
                text: root.urgency === 2 && root.remainingSeconds > 0 ? i18n("Critical")
                    : root.urgency === 1 ? i18n("Warning")
                    : root.anchorReady ? i18n("Active") : i18n("Initialising…")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: root.arcColor
                opacity: 0.8
            }

            // Item { Layout.fillWidth: true }
            // PlasmaComponents3.Button {
            //     icon.name: "media-playback-start"
            //     text: i18n("Test Beep")
            //     flat: true
            //     onClicked: root.triggerSingleBeep()
            // }
        }

        // ── Alarm Schedule ───────────────────────────────────────────────────
        Kirigami.Separator {
            Layout.fillWidth: true
            visible: root.parseWarningSecondsList().length > 0
        }

        PlasmaComponents3.Label {
            visible: root.parseWarningSecondsList().length > 0
            text: i18n("Alarm schedule")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.5
            font.capitalization: Font.AllUppercase
        }

        Repeater {
            model: root.parseWarningSecondsList()
            delegate: RowLayout {
                required property int modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                readonly property bool fired: !!root.triggeredWarningSeconds["" + modelData]

                Kirigami.Icon {
                    source: fired ? "checkmark" : "notifications"
                    color: fired ? Kirigami.Theme.disabledTextColor : root.arcColor
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    Layout.alignment: Qt.AlignVCenter
                }

                PlasmaComponents3.Label {
                    text: {
                        const mins = Math.round(modelData / 60)
                        return mins === 1 ? i18n("1 min warning")
                                         : i18n("%1 min warning", mins)
                    }
                    font.bold: true
                    font.strikeout: fired
                    opacity: fired ? 0.4 : 1.0
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    text: i18n("at %1", root.warningTriggerAtText(modelData))
                    font.strikeout: fired
                    opacity: fired ? 0.3 : 0.6
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
        }
        } // ColumnLayout (contentLayout)
    } // fullRepresentation Item
} // PlasmoidItem

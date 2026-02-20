import QtQuick 2.15
import QtQuick.Controls 2.15 as QtControls
import QtQuick.Layouts 1.15

import org.kde.kcmutils as KCM
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support

KCM.SimpleKCM {
    id: root
    property alias cfg_durationHours: durationHours.value
    property alias cfg_durationMinutes: durationMinutes.value
    property string cfg_warningMinutesCsv
    property alias cfg_backgroundOpacity: backgroundOpacity.value

    property bool syncingWarningsModel: false
    property bool updatingCsvFromUi: false

    // ── helpers ──────────────────────────────────────────────────────────────
    function clampMinute(value) {
        const parsed = Number(value)
        if (isNaN(parsed)) return 0
        return Math.max(0, Math.min(1440, Math.floor(parsed)))
    }

    function updateWarningCsv() {
        if (syncingWarningsModel) return
        const seen = ({})
        const values = []
        for (let i = 0; i < warningsModel.count; i++) {
            const mv = clampMinute(warningsModel.get(i).minutes)
            const key = "" + mv
            if (seen[key]) continue
            seen[key] = true
            values.push(mv)
        }
        // Sort descending in the CSV (largest time-before-end first)
        values.sort(function(a, b) { return b - a })
        const nextCsv = values.join(",")
        if (cfg_warningMinutesCsv === nextCsv) return
        updatingCsvFromUi = true
        cfg_warningMinutesCsv = nextCsv
        writeSharedConfig()
    }

    function rebuildWarningsModel(csvText) {
        syncingWarningsModel = true
        warningsModel.clear()
        const raw = (csvText || "").toString()
        const seen = ({})
        const entries = []
        raw.split(",").forEach(function(part) {
            const t = part.trim()
            if (!t) return
            const mv = clampMinute(t)
            const key = "" + mv
            if (seen[key]) return
            seen[key] = true
            entries.push(mv)
        })
        // Sort descending (largest time-before-end first)
        entries.sort(function(a, b) { return b - a })
        entries.forEach(function(mv) { warningsModel.append({ minutes: mv }) })
        syncingWarningsModel = false
    }

    function removeWarning(idx) {
        if (idx < 0 || idx >= warningsModel.count) return
        warningsModel.remove(idx)
        updateWarningCsv()
    }

    function addWarning(afterIndex, initialValue) {
        // Find the next value not already in the model to avoid silent dedup
        let mv = clampMinute(initialValue)
        const existing = new Set()
        for (let i = 0; i < warningsModel.count; i++) existing.add(warningsModel.get(i).minutes)
        while (existing.has(mv) && mv < 1440) mv++
        const ins = Math.max(0, Math.min(warningsModel.count, afterIndex + 1))
        warningsModel.insert(ins, { minutes: mv })
        updateWarningCsv()
    }

    // ── shared config file sync ───────────────────────────────────────────────
    // Write current settings to a shared file so all widget instances can read them.
    readonly property string sharedConfigPath: "$HOME/.config/clouddeck-session-shared.conf"

    P5Support.DataSource {
        id: sharedFileWriter
        engine: "executable"
        interval: 0
    }

    function writeSharedConfig() {
        const csv = cfg_warningMinutesCsv || ""
        const hours = cfg_durationHours
        const mins = cfg_durationMinutes
        const opacity = cfg_backgroundOpacity
        const cmd = 'echo "warningMinutesCsv=' + csv + '\ndurationHours=' + hours + '\ndurationMinutes=' + mins + '\nbackgroundOpacity=' + opacity + '" > ' + sharedConfigPath
        sharedFileWriter.connectSource(cmd)
    }

    onCfg_warningMinutesCsvChanged: {
        if (updatingCsvFromUi) { updatingCsvFromUi = false; return }
        rebuildWarningsModel(cfg_warningMinutesCsv)
    }
    onCfg_durationHoursChanged: writeSharedConfig()
    onCfg_durationMinutesChanged: writeSharedConfig()
    onCfg_backgroundOpacityChanged: writeSharedConfig()

    Component.onCompleted: {
        rebuildWarningsModel(cfg_warningMinutesCsv)
        writeSharedConfig()
    }

    ListModel { id: warningsModel }

    // ── layout ────────────────────────────────────────────────────────────────
    Kirigami.FormLayout {
        id: formLayout
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 40
        anchors.horizontalCenter: parent.horizontalCenter

        // ════════════════════════════════════════
        // SECTION: Timer Duration
        // ════════════════════════════════════════
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Timer Duration")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Hours")
            spacing: Kirigami.Units.smallSpacing

            QtControls.SpinBox {
                id: durationHours
                from: 0; to: 72
                implicitWidth: 120
                editable: true
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Minutes")
            spacing: Kirigami.Units.smallSpacing

            QtControls.SpinBox {
                id: durationMinutes
                from: 0; to: 59
                implicitWidth: 120
                editable: true
            }
        }

        // Live duration preview
        Rectangle {
            Layout.fillWidth: true
            height: 48
            radius: Kirigami.Units.smallSpacing
            color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1)
            border.color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.3)
            border.width: 1

            Kirigami.Heading {
                anchors.centerIn: parent
                level: 3
                font.family: "monospace"
                color: Kirigami.Theme.highlightColor
                text: {
                    const h = Math.max(0, durationHours.value)
                    const m = Math.max(0, durationMinutes.value)
                    const pad = v => v < 10 ? "0" + v : "" + v
                    return pad(h) + ":" + pad(m) + ":00"
                }
            }
        }

        Item { Kirigami.FormData.isSection: true }

        // ════════════════════════════════════════
        // SECTION: Warning Alarms
        // ════════════════════════════════════════
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Warning Alarms")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            QtControls.Label {
                text: warningsModel.count > 0 ? i18n("%1 alarm(s) configured", warningsModel.count) : i18n("No alarms configured")
                opacity: 0.7
                Layout.fillWidth: true
            }

            QtControls.Button {
                text: i18n("Add Alarm")
                icon.name: "list-add"
                onClicked: addWarning(warningsModel.count - 1, 5)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: warningsModel
                delegate: Rectangle {
                    required property int index
                    required property int minutes
                    Layout.fillWidth: true
                    height: Kirigami.Units.gridUnit * 2.5
                    radius: Kirigami.Units.smallSpacing
                    color: index % 2 === 0
                        ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.05)
                        : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.largeSpacing

                        QtControls.Label {
                            text: "#" + (index + 1)
                            font.bold: true
                            opacity: 0.5
                            Layout.alignment: Qt.AlignVCenter
                        }

                        QtControls.SpinBox {
                            id: warnSpin
                            from: 0; to: 1440
                            value: minutes
                            editable: true
                            implicitWidth: 140
                            textFromValue: function(v) { return v + i18n(" min") }
                            valueFromText: function(t) { return parseInt(t, 10) || 0 }

                            onValueChanged: {
                                if (syncingWarningsModel) return
                                if (minutes !== value) {
                                    warningsModel.setProperty(index, "minutes", value)
                                    updateWarningCsv()
                                }
                            }
                        }

                        QtControls.Label {
                            text: minutes === 0 ? i18n("(at expiry)") : i18n("before end")
                            opacity: 0.7
                            Layout.fillWidth: true
                        }

                        QtControls.ToolButton {
                            icon.name: "list-add"
                            QtControls.ToolTip.text: i18n("Insert alarm after this one")
                            QtControls.ToolTip.visible: hovered
                            onClicked: addWarning(index, warnSpin.value)
                        }

                        QtControls.ToolButton {
                            icon.name: "list-remove"
                            QtControls.ToolTip.text: i18n("Remove this alarm")
                            QtControls.ToolTip.visible: hovered
                            onClicked: removeWarning(index)
                        }
                    }
                }
            }
        }

        Item { Kirigami.FormData.isSection: true }

        // ════════════════════════════════════════
        // SECTION: Appearance
        // ════════════════════════════════════════
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Appearance")
        }



        // ── Desktop background opacity ─────────────────────────────────────────
        RowLayout {
            Kirigami.FormData.label: i18n("Panel background opacity")
            spacing: Kirigami.Units.smallSpacing

            QtControls.Slider {
                id: bgOpacitySlider
                from: 0; to: 100
                value: backgroundOpacity.value
                implicitWidth: Kirigami.Units.gridUnit * 10
                onMoved: backgroundOpacity.value = Math.round(value)
            }

            QtControls.SpinBox {
                id: backgroundOpacity
                from: 0; to: 100
                editable: true
                implicitWidth: 100
                onValueChanged: if (value !== Math.round(bgOpacitySlider.value))
                    bgOpacitySlider.value = value
            }

            QtControls.Label { text: "%"; opacity: 0.7 }
        }

        QtControls.Label {
            text: i18n("Controls the background when widget is placed on the desktop (not in a panel).")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            opacity: 0.6
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }
}

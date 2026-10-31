pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets
import qs.Modules.DDash
import qs.Modules.DDash.Overview

FocusScope {
    id: root

    property var parentModal: null

    focus: true

    readonly property var tabs: DashRegistry.tabEntries
    readonly property var optionEntryIds: DashRegistry.entries.filter(e => (e.options?.length ?? 0) > 0).map(e => e.id)
    SettingsPage {
        SettingsCard {
            title: I18n.tr("Weather")

            SettingsNavRow {
                tab: "dank_dash"
                settingKey: "dashWeatherSettings"
                title: I18n.tr("Weather")
                iconName: "partly_cloudy_day"
                onClicked: keyboard => root.parentModal?.navigateTo("weather", keyboard)
            }
        }

        SettingsCard {
            title: I18n.tr("Media player")

            SettingsNavRow {
                tab: "dank_dash"
                settingKey: "dashMediaSettings"
                title: I18n.tr("Media player")
                hint: I18n.tr("Lyrics providers", "Lyrics source priority settings")
                iconName: "music_note"
                onClicked: keyboard => root.parentModal?.navigateTo("media_player", keyboard)
            }

            SettingsRow {
                settingKey: "dashClavisPreset"
                tab: "dank_dash"
                tags: ["clavis", "media", "preset", "caelestia"]
                title: I18n.tr("Clavis reference appearance")
                subtitle: I18n.tr("Caelestia cover, Material progress and theme colors")

                DActionButton {
                    iconName: "auto_awesome"
                    tooltipText: I18n.tr("Apply")
                    onClicked: ClavisPreferences.applyReference()
                }
            }

            SettingsToggleRow {
                settingKey: "audioVisualizerEnabled"
                tab: "dank_dash"
                tags: ["clavis", "media", "spectrum", "visualizer", "caelestia"]
                text: I18n.tr("Audio visualizer")
                description: I18n.tr("Enable other media visualizers. Caelestia covers include their own spectrum; reduced motion keeps them still.")
                checked: SettingsData.audioVisualizerEnabled
                onToggled: checked => SettingsData.set("audioVisualizerEnabled", checked)
            }

            SettingsRow {
                settingKey: "dashClavisImport"
                tab: "dank_dash"
                tags: ["clavis", "media", "import", "cover", "progress", "color"]
                title: I18n.tr("Import Clavis media appearance")
                subtitle: ClavisPreferences.loading ? I18n.tr("Loading…")
                    : ClavisPreferences.available ? I18n.tr("Cover: %1 · Progress: %2 · Color: %3").arg(ClavisPreferences.preview.clavisCoverStyle).arg(ClavisPreferences.preview.clavisProgressStyle).arg(ClavisPreferences.preview.albumArtAccent ? I18n.tr("Album art") : I18n.tr("Theme"))
                    : ClavisPreferences.error !== "" ? I18n.tr("Unable to read valid Clavis media settings")
                    : I18n.tr("Read the local Clavis configuration and preview its three appearance options")

                DActionButton {
                    iconName: "refresh"
                    tooltipText: I18n.tr("Read Clavis settings")
                    enabled: !ClavisPreferences.loading
                    onClicked: ClavisPreferences.refresh()
                }

                DActionButton {
                    iconName: "check"
                    tooltipText: I18n.tr("Apply")
                    enabled: ClavisPreferences.available && !ClavisPreferences.loading
                    onClicked: ClavisPreferences.apply()
                }
            }
        }

        SettingsCard {
            title: I18n.tr("Digital wellbeing", "settings page and dashboard tab title, screen time tracking")

            SettingsNavRow {
                tab: "dank_dash"
                settingKey: "dashWellbeingSettings"
                title: I18n.tr("Digital wellbeing", "settings page and dashboard tab title, screen time tracking")
                hint: I18n.tr("Screen time and app limits", "settings sidebar hint and dashboard tab description for digital wellbeing")
                iconName: "digital_wellbeing"
                onClicked: root.parentModal?.navigateTo("wellbeing")
            }
        }

        SettingsCard {
            title: I18n.tr("Clavis dashboard cards")

            SettingsRow {
                settingKey: "dashClavisCards"
                tab: "dank_dash"
                tags: ["clavis", "cards", "cookie", "weather", "battery", "cpu", "memory", "network", "disk"]
                title: I18n.tr("Apply Clavis card styles")
                subtitle: I18n.tr("Keep the current card positions and sizes")

                DActionButton {
                    iconName: "palette"
                    tooltipText: I18n.tr("Apply")
                    onClicked: DashRegistry.applyClavisCardStyles()
                }
            }
        }

        SettingsCard {
            title: I18n.tr("Tabs", "noun, card title for dashboard tabs")
            settingKey: "dashTabs"
            tab: "dank_dash"

            headerActions: DActionButton {
                iconName: "refresh"
                iconSize: Theme.iconSizeSmall
                tooltipText: I18n.tr("Reset to default")
                onClicked: {
                    SettingsData.resetDashTabs();
                    SettingsData.resetToDefault(["dashTabPosition", "dashTabsEvenlySpaced"]);
                }
            }

            SettingsDropdownRow {
                text: I18n.tr("Position")
                readonly property var positions: [
                    {
                        value: "auto",
                        text: I18n.tr("Auto")
                    },
                    {
                        value: "left",
                        text: I18n.tr("Left")
                    },
                    {
                        value: "right",
                        text: I18n.tr("Right")
                    },
                    {
                        value: "bottom",
                        text: I18n.tr("Bottom")
                    },
                    {
                        value: "center",
                        text: I18n.tr("Center")
                    }
                ]
                settingKey: "dashTabPosition"
                tab: "dank_dash"
                tags: ["dashboard", "tabs", "position", "navigation"]
                currentValue: (positions.find(option => option.value === SettingsData.dashTabPosition) ?? positions[0]).text
                options: positions.map(option => option.text)
                onValueChanged: value => {
                    const option = positions.find(option => option.text === value);
                    if (option)
                        SettingsData.set("dashTabPosition", option.value);
                }
            }

            SettingsToggleRow {
                settingKey: "dashTabsEvenlySpaced"
                tab: "dank_dash"
                tags: ["dashboard", "tabs", "spacing", "navigation"]
                text: I18n.tr("Evenly space tabs", "dashboard tab bar toggle")
                checked: SettingsData.dashTabsEvenlySpaced
                onToggled: checked => SettingsData.set("dashTabsEvenlySpaced", checked)
            }

            SettingsReorderList {
                id: tabList

                model: ScriptModel {
                    values: root.tabs
                    objectProp: "id"
                }
                onReordered: indices => SettingsData.setDashTabOrder(indices.map(i => root.tabs[i].id))

                delegate: SettingsReorderRow {
                    id: tabRow

                    required property var modelData

                    reorderList: tabList

                    readonly property bool available: modelData.available !== false

                    iconName: modelData.icon
                    iconColor: available && modelData.enabled ? Theme.primary : Theme.onSurface_38
                    titleColor: available ? Theme.surfaceText : Theme.onSurface_38
                    title: modelData.text
                    subtitle: available ? modelData.description ?? "" : I18n.tr("Disabled")
                    clickable: available
                    onClicked: SettingsData.setDashTabEnabled(modelData.id, !modelData.enabled)

                    Row {
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        DActionButton {
                            anchors.verticalCenter: parent.verticalCenter
                            objectName: "editDashTab"
                            iconName: "edit"
                            tooltipText: I18n.tr("Edit")
                            Accessible.description: tabRow.modelData.text
                            enabled: tabRow.available
                            onClicked: PopoutService.openDankDashEditor(tabRow.modelData.id, root.Window.window?.screen)
                        }

                        DToggle {
                            anchors.verticalCenter: parent.verticalCenter
                            hideText: true
                            checked: tabRow.modelData.enabled
                            enabled: tabRow.available
                            onToggled: checked => SettingsData.setDashTabEnabled(tabRow.modelData.id, checked)
                        }
                    }
                }
            }
        }

        Repeater {
            // value-diffed ids keep a card alive across option changes, a rebuilt card collapses
            model: ScriptModel {
                values: root.optionEntryIds
            }

            SettingsCard {
                id: optionCard

                required property string modelData
                readonly property var entry: DashRegistry.entries.find(e => e.id === modelData) ?? null
                readonly property var options: entry?.options ?? []

                title: entry?.text ?? ""
                settingKey: "dashOptions:" + modelData
                tab: "dank_dash"
                collapsible: true
                expanded: false

                Repeater {
                    model: optionCard.options.length

                    DashOptionRow {
                        required property int index

                        spec: optionCard.options[index] ?? ({})
                        value: DashRegistry.option(optionCard.modelData, spec.key)
                        settingKey: "dashOptions:" + optionCard.modelData + ":" + spec.key
                        onCommitted: next => DashRegistry.setOption(optionCard.modelData, spec.key, next)
                    }
                }
            }
        }
    }
}

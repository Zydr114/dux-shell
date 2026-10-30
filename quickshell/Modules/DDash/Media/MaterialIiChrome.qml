pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets
import qs.Modules.DDash
import "../../../Common/Format.js" as Format
import "../../../DCommon/Common/FocusNavigation.js" as FocusNavigation

MediaChromeBase {
    id: root

    artSize: DashMetrics.mediaArtSizeDash
    baseHeight: DashMetrics.tabMinHeight
    backdropBlur: (root.player.options?.popupBackdropBlur ?? 60) / 100
    readonly property var transportFocusTargets: [shuffleButton, previousButton, playButton, nextButton, repeatButton]

    focusTargets: transportFocusTargets.concat(seekbar.canSeek ? [seekbar] : [], sourceGroup.focusTargets, [blurButton])
    panelButtons: sourceGroup.panelButtons.concat([blurButton])

    Item {
        id: hero
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.spacingL

        MediaArtView {
            id: art
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(root.artSize, parent.height, parent.width * 0.42))
            height: width
            player: root.player
            showLyrics: false
        }

        Item {
            id: details
            anchors.left: art.right
            anchors.leftMargin: Theme.spacingL
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(metadata.implicitHeight + seekBlock.height + transport.implicitHeight + Theme.spacingL * 2, art.height)

            Column {
                id: metadata
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Theme.spacingXS
                visible: !root.player.lyricsOpen

                StyledText {
                    width: parent.width
                    text: root.title
                    fontToken: root.titleFontToken
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeXXLarge
                    font.weight: Theme.fontWeightBold
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: root.artist
                    color: Theme.onSurfaceVariant
                    font.pixelSize: Theme.fontSizeMedium
                    elide: Text.ElideRight
                }
            }

            Loader {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: seekBlock.visible ? seekBlock.top : transport.top
                anchors.bottomMargin: Theme.spacingM
                active: root.player.lyricsOpen && root.player.live
                onLoaded: (item as Item)?.forceActiveFocus(Qt.PopupFocusReason)
                sourceComponent: LyricsOverlay {
                    player: root.player
                }
            }

            Column {
                id: seekBlock
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: transport.top
                anchors.bottomMargin: Theme.spacingM
                spacing: Theme.spacingXS
                visible: root.hasSeekbar

                MediaSeekbar {
                    id: seekbar
                    width: parent.width
                    player: root.player
                }

                Item {
                    width: parent.width
                    height: elapsed.implicitHeight

                    NumericText {
                        id: elapsed
                        anchors.left: parent.left
                        text: Format.formatDuration(seekbar.value * (root.presentation?.length ?? 0))
                        color: Theme.onSurfaceVariant
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    NumericText {
                        anchors.right: parent.right
                        text: Format.formatDuration(root.presentation?.length ?? 0)
                        color: Theme.onSurfaceVariant
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            RowLayout {
                id: transport
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.spacingXS
                Keys.onPressed: event => event.accepted = FocusNavigation.handleHorizontalKey(event, root.transportFocusTargets, I18n.isRtl)

                MediaTransportButton {
                    id: shuffleButton
                    player: root.player
                    mediaAction: "shuffle"
                }

                Item {
                    Layout.fillWidth: true
                }

                MediaTransportButton {
                    id: previousButton
                    player: root.player
                    mediaAction: "previous"
                }

                MediaTransportButton {
                    id: playButton
                    player: root.player
                    mediaAction: "play"
                    size: "m"
                    widthMode: "wide"
                    variant: "filled"
                    round: false
                    containerColor: MediaAccentService.accentContainer
                    contentColor: MediaAccentService.onAccentContainer
                }

                MediaTransportButton {
                    id: nextButton
                    player: root.player
                    mediaAction: "next"
                }

                Item {
                    Layout.fillWidth: true
                }

                MediaTransportButton {
                    id: repeatButton
                    player: root.player
                    mediaAction: "repeat"
                }
            }
        }
    }

    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: sourceGroup.height

        StyledText {
            anchors.left: parent.left
            anchors.right: auxiliary.left
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            text: root.presentation?.identity ?? ""
            color: Theme.onSurfaceVariant
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }

        Row {
            id: auxiliary
            anchors.right: parent.right
            spacing: Theme.spacingXS

            DIconButton {
                id: blurButton
                readonly property string panelId: "backdrop"
                variant: "outlined"
                iconName: "blur_on"
                tooltipText: I18n.tr("Album art backdrop")
                checkable: true
                checked: root.player.panel === panelId
                enabled: root.player.wallpaperEnabled
                onClicked: root.player.togglePanel(panelId)
            }

            MaterialSourceGroup {
                id: sourceGroup
                player: root.player
                presentation: root.presentation
            }
        }
    }
}

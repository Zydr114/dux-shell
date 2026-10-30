pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import qs.Widgets
import qs.Modules.DDash
import "../../../Common/Format.js" as Format
import "../../../DCommon/Common/FocusNavigation.js" as FocusNavigation

MediaChromeBase {
    id: root

    artSize: DashMetrics.mediaArtSizeDash * DashMetrics.mediaPopupScale
    baseHeight: DashMetrics.mediaPopupHeightFor(width)
    padding: Theme.spacingM
    borderWidth: 0
    backdropRadius: Theme.windowRadius
    backdropBlur: (root.player.options?.popupBackdropBlur ?? 60) / 100
    readonly property var transportFocusTargets: [previousButton, playButton, nextButton]

    backdropContent: MediaSpectrumBackdrop {
        radius: root.backdropRadius
        live: root.player.live
        playing: !!root.presentation?.playing
        spectrumColor: root.player.accent
    }

    focusTargets: transportFocusTargets.concat(seekbar.canSeek ? [seekbar] : [], sourceGroup.focusTargets, [blurButton])
    panelButtons: sourceGroup.panelButtons.concat([blurButton])

    Item {
        id: hero
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.spacingM

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
            anchors.leftMargin: Theme.spacingM
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: art.height

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
                    font.pixelSize: Theme.fontSizeXLarge
                    font.weight: Theme.fontWeightMedium
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
                anchors.bottom: seekbar.visible ? seekbar.top : transport.top
                anchors.bottomMargin: Theme.spacingM
                active: root.player.lyricsOpen && root.player.live
                onLoaded: (item as Item)?.forceActiveFocus(Qt.PopupFocusReason)
                sourceComponent: LyricsOverlay {
                    player: root.player
                }
            }

            MediaSeekbar {
                id: seekbar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: transport.top
                anchors.bottomMargin: Theme.spacingXS
                visible: root.hasSeekbar
                player: root.player
            }

            RowLayout {
                id: transport
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.spacingXS
                Keys.onPressed: event => event.accepted = FocusNavigation.handleHorizontalKey(event, root.transportFocusTargets, I18n.isRtl)

                NumericText {
                    text: Format.formatDuration(seekbar.value * (root.presentation?.length ?? 0))
                    color: Theme.onSurfaceVariant
                    font.pixelSize: Theme.fontSizeSmall
                    visible: root.hasSeekbar
                }

                Item {
                    Layout.fillWidth: true
                }

                MediaTransportButton {
                    id: previousButton
                    player: root.player
                    mediaAction: "previous"
                    keepNavigation: true
                    widthMode: "narrow"
                    buttonSize: Theme.buttonHeightXS
                }

                MediaTransportButton {
                    id: playButton
                    player: root.player
                    mediaAction: "play"
                    checkable: false
                    iconFilled: true
                    widthMode: "narrow"
                    buttonSize: Theme.buttonHeightXS
                }

                MediaTransportButton {
                    id: nextButton
                    player: root.player
                    mediaAction: "next"
                    keepNavigation: true
                    widthMode: "narrow"
                    buttonSize: Theme.buttonHeightXS
                }

                Item {
                    Layout.fillWidth: true
                }

                NumericText {
                    text: Format.formatDuration(root.presentation?.length ?? 0)
                    color: Theme.onSurfaceVariant
                    font.pixelSize: Theme.fontSizeSmall
                    visible: root.hasSeekbar
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

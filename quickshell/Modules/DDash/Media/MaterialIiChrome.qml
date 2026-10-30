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

    artSize: DashMetrics.mediaArtSizeDash * DashMetrics.mediaPopupScale
    baseHeight: DashMetrics.mediaPopupHeightFor(width)
    padding: compact ? Theme.spacingS : Theme.spacingM
    borderWidth: 0
    backdropRadius: Theme.windowRadius
    backdropBlur: (root.player.options?.popupBackdropBlur ?? 60) / 100
    readonly property bool compact: height < Theme.buttonHeightM * 2 + Theme.spacingM * 2
    readonly property real transportWidth: previousButton.implicitWidth + playButton.implicitWidth + nextButton.implicitWidth + Theme.spacingXS * 2
    readonly property bool showTimes: hasSeekbar && details.width >= transportWidth + Theme.buttonHeightS * 2 + Theme.spacingS * 2
    readonly property var transportFocusTargets: [previousButton, playButton, nextButton]

    backdropContent: MediaSpectrumBackdrop {
        radius: root.backdropRadius
        live: root.player.live
        playing: !!root.presentation?.playing
        spectrumColor: root.player.accent
    }

    focusTargets: transportFocusTargets.concat(seekbar.visible && seekbar.canSeek ? [seekbar] : [], footer.visible ? sourceGroup.focusTargets.concat([blurButton]) : [])
    panelButtons: sourceGroup.panelButtons.concat([blurButton])

    Item {
        id: hero
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.bottomMargin: footer.visible ? Theme.spacingM : 0

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
                    id: titleLabel
                    width: parent.width
                    text: root.title
                    fontToken: root.titleFontToken
                    color: Theme.surfaceText
                    font.pixelSize: root.compact ? Theme.fontSizeLarge : (Theme.fontSizeXLarge + Theme.fontSizeXXLarge) / 2
                    font.weight: Theme.fontWeightMedium
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: root.artist
                    color: Theme.onSurfaceVariant
                    font.pixelSize: root.compact ? Theme.fontSizeSmall : Theme.fontSizeLarge
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    visible: details.height >= titleLabel.implicitHeight + implicitHeight + transport.height + Theme.spacingS
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
                visible: root.hasSeekbar && details.height >= metadata.implicitHeight + height + transport.height + Theme.spacingM
                player: root.player
            }

            RowLayout {
                id: transport
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.spacingXS
                height: Theme.buttonHeightS
                Keys.onPressed: event => event.accepted = FocusNavigation.handleHorizontalKey(event, root.transportFocusTargets, I18n.isRtl)

                NumericText {
                    text: Format.formatDuration(seekbar.value * (root.presentation?.length ?? 0))
                    color: Theme.onSurfaceVariant
                    font.pixelSize: Theme.fontSizeMedium
                    visible: root.showTimes
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
                    implicitWidth: iconSize + horizontalInset * 2
                    variant: "tonal"
                    containerColor: MediaAccentService.accentSecondaryContainer
                    contentColor: MediaAccentService.onAccentSecondaryContainer
                    visible: details.width >= root.transportWidth
                }

                MediaTransportButton {
                    id: playButton
                    player: root.player
                    mediaAction: "play"
                    iconFilled: true
                    widthMode: "wide"
                    implicitWidth: iconSize + horizontalInset * 2
                    variant: "filled"
                    round: false
                    containerColor: MediaAccentService.accentContainer
                    contentColor: MediaAccentService.onAccentContainer
                }

                MediaTransportButton {
                    id: nextButton
                    player: root.player
                    mediaAction: "next"
                    keepNavigation: true
                    widthMode: "narrow"
                    implicitWidth: iconSize + horizontalInset * 2
                    variant: "tonal"
                    containerColor: MediaAccentService.accentSecondaryContainer
                    contentColor: MediaAccentService.onAccentSecondaryContainer
                    visible: previousButton.visible
                }

                Item {
                    Layout.fillWidth: true
                }

                NumericText {
                    text: Format.formatDuration(root.presentation?.length ?? 0)
                    color: Theme.onSurfaceVariant
                    font.pixelSize: Theme.fontSizeMedium
                    visible: root.showTimes
                }
            }
        }
    }

    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: visible ? sourceGroup.height : 0
        visible: !root.compact

        StyledText {
            anchors.left: parent.left
            anchors.right: auxiliary.left
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            text: root.presentation?.identity ?? ""
            color: Theme.onSurfaceVariant
            font.pixelSize: Theme.fontSizeMedium
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }

        Row {
            id: auxiliary
            anchors.right: parent.right
            spacing: Theme.spacingXS

            DIconButton {
                id: blurButton
                readonly property string panelId: "backdrop"
                variant: "tonal"
                containerColor: MediaAccentService.accentSecondaryContainer
                contentColor: MediaAccentService.onAccentSecondaryContainer
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
                buttonVariant: "tonal"
            }
        }
    }
}

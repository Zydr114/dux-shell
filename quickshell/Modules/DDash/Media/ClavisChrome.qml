pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DDash

MediaChromeBase {
    id: root

    readonly property string coverStyle: MediaOptions.normalizeClavisCoverStyle(player.options?.clavisCoverStyle)
    readonly property string progressStyle: MediaOptions.normalizeClavisProgressStyle(player.options?.clavisProgressStyle)
    readonly property bool backgroundCover: coverStyle === "background"
    readonly property real minimumDetailsWidth: Theme.buttonHeightXS * 4 + Theme.buttonHeightM + Theme.spacingS + Theme.spacingS * 6
    readonly property real minimumCoverWidth: Theme.buttonHeightM + (coverStyle === "caelestia" ? (Theme.clavisSpectrumMaxHeight + Theme.clavisSpectrumGap) * 2 : 0)
    readonly property bool narrow: width - (padding + borderWidth) * 2 < minimumDetailsWidth + Theme.clavisContentGap + minimumCoverWidth
    readonly property bool chromeLive: visible && player.live
    readonly property color foreground: MediaOptions.albumArtAccent ? MediaAccentService.onAccentSecondaryContainer : Theme.surfaceText
    readonly property color secondaryForeground: Theme.withAlpha(foreground, Theme.clavisSecondaryAlpha)
    readonly property int sourceCount: player.allPlayers?.length ?? 0
    readonly property bool showDeviceName: player.options?.deviceName ?? MediaOptions.defaults.deviceName
    property bool sourceSelectorOpen: false

    implicitWidth: coverStyle === "rounded" ? Theme.clavisRoundedWidth : Theme.clavisExpandedWidth
    baseHeight: coverStyle === "rounded" ? Theme.clavisRoundedHeight : Theme.clavisExpandedHeight
    artSize: coverStyle === "caelestia" || backgroundCover ? Theme.clavisSpectrumCoverSize : Theme.clavisCoverSize
    padding: Theme.spacingM
    borderWidth: 0
    backdropRadius: Theme.windowRadius
    artworkBackdropEnabled: false
    surfaceColor: MediaOptions.albumArtAccent ? MediaAccentService.accentSecondaryContainer : Theme.withAlpha(Theme.surface, 1)
    backdropContent: backgroundCover ? coverBackdrop : null
    focusTargets: sourceSelectorOpen ? [sourceSelector.focusTarget] : [sourceBadge, lyricsButton, volumeButton, devicesButton, shuffleButton, previousButton, playButton, nextButton, repeatButton].concat(seekbar.visible && seekbar.canSeek ? [seekbar] : [])
    panelButtons: [volumeButton, devicesButton]

    onChromeLiveChanged: {
        if (!chromeLive)
            sourceSelectorOpen = false;
    }
    onPanelOpenChanged: {
        if (panelOpen)
            sourceSelectorOpen = false;
    }
    onSourceCountChanged: {
        if (sourceCount < 2)
            dismissSourceSelector();
    }

    function dismissSourceSelector() {
        if (!sourceSelectorOpen)
            return false;
        sourceSelectorOpen = false;
        if (sourceBadge.enabled)
            sourceBadge.forceActiveFocus(Qt.OtherFocusReason);
        else if (playButton.enabled)
            playButton.forceActiveFocus(Qt.OtherFocusReason);
        return true;
    }

    function handleSourceSelectorKey(event) {
        sourceSelector.handleKeyEvent(event);
        return true;
    }

    ClavisCover {
        id: cover
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, Math.min(root.artSize, parent.height, parent.width * (1 - Theme.clavisMetadataWidthRatio), parent.width - Theme.clavisContentGap - root.minimumDetailsWidth))
        height: width
        visible: !root.backgroundCover && !root.narrow
        player: root.player
        artUrl: root.artUrl
        caelestia: root.coverStyle === "caelestia"
    }

    Item {
        id: details
        x: root.backgroundCover && !root.narrow ? Math.max(0, Math.min(root.artSize + Theme.clavisContentGap, parent.width - root.minimumDetailsWidth)) : cover.visible ? cover.width + Theme.clavisContentGap : 0
        width: Math.max(0, parent.width - x)
        height: parent.height

        Item {
            id: toolbar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Theme.buttonHeightXXS

            Row {
                id: auxiliary
                anchors.left: parent.left
                spacing: Theme.spacingXXS

                DIconButton {
                    id: lyricsButton
                    buttonSize: Theme.buttonHeightXXS
                    iconSize: Theme.iconSizeSmall
                    iconName: "notes"
                    checkable: true
                    checked: root.player.lyricsOpen
                    visible: root.player.lyricsEnabled
                    tooltipText: I18n.tr("Lyrics", "Media player lyrics button")
                    iconColor: root.foreground
                    containerColor: MediaAccentService.accentContainer
                    contentColor: MediaAccentService.onAccentContainer
                    onClicked: root.player.toggleLyrics(lyricsButton)
                }

                DIconButton {
                    id: volumeButton
                    readonly property string panelId: "volume"
                    buttonSize: Theme.buttonHeightXXS
                    iconSize: Theme.iconSizeSmall
                    iconName: root.player.getVolumeIcon()
                    iconColor: root.foreground
                    enabled: root.player.volumeAvailable
                    tooltipText: (root.player.usePlayerVolume ? I18n.tr("Media volume") : I18n.tr("Volume")) + ": " + Math.round(root.player.currentVolume * 100) + "%"
                    onClicked: root.player.togglePanel(panelId)

                    MediaVolumeWheel {
                        player: root.player
                        button: volumeButton
                    }
                }

                DButton {
                    id: devicesButton
                    readonly property string panelId: "devices"
                    readonly property bool named: root.showDeviceName && !root.narrow
                    buttonHeight: Theme.buttonHeightXXS
                    iconSize: Theme.iconSizeSmall
                    minimumWidth: 0
                    maximumWidth: named ? details.width * DashMetrics.mediaDeviceNameWidthRatio : Theme.buttonHeightXXS
                    horizontalPadding: Theme.spacingXS
                    text: named ? AudioService.displayName(AudioService.sink) : ""
                    iconName: AudioService.sinkIcon(AudioService.sink)
                    backgroundColor: "transparent"
                    textColor: root.foreground
                    tooltipText: I18n.tr("Devices", "Media player output device picker") + ": " + AudioService.displayName(AudioService.sink)
                    Accessible.name: tooltipText
                    onClicked: root.player.togglePanel(panelId)

                    MediaSinkMute {}
                }
            }

            DButton {
                id: sourceBadge
                anchors.right: parent.right
                buttonHeight: Theme.buttonHeightXXS
                horizontalPadding: Theme.spacingS
                minimumWidth: 0
                maximumWidth: Math.max(0, toolbar.width - auxiliary.implicitWidth - Theme.spacingS)
                text: root.sourceCount < 2 && root.activePlayer?.canRaise ? I18n.tr("Open %1").arg(root.presentation?.identity ?? "") : root.presentation?.identity ?? ""
                iconName: root.sourceCount > 1 ? (root.sourceSelectorOpen ? "expand_less" : "expand_more") : ""
                iconSize: Theme.iconSizeSmall
                backgroundColor: MediaAccentService.accentContainer
                textColor: MediaAccentService.onAccentContainer
                enabled: root.sourceCount > 1 || !!root.activePlayer?.canRaise
                tooltipText: root.sourceCount > 1 ? I18n.tr("Players", "Media player selection") : root.presentation?.identity ?? ""
                onClicked: {
                    if (root.sourceCount > 1) {
                        root.sourceSelectorOpen = !root.sourceSelectorOpen;
                        return;
                    }
                    if (root.activePlayer?.canRaise)
                        root.activePlayer.raise();
                }
            }
        }

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: toolbar.bottom
            anchors.topMargin: Theme.spacingXS
            anchors.bottom: parent.bottom
            spacing: Theme.spacingXS

            Column {
                id: metadata
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.spacingXS
                visible: !root.player.lyricsOpen

                StyledText {
                    width: parent.width
                    text: root.title
                    fontToken: root.titleFontToken
                    color: root.foreground
                    font.pixelSize: root.narrow ? Theme.fontSizeLarge : Theme.fontSizeXLarge
                    font.weight: Theme.fontWeightBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    width: parent.width
                    text: root.artist
                    color: root.secondaryForeground
                    font.pixelSize: Theme.fontSizeMedium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            Item {
                id: lyricSpace
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.player.lyricsOpen

                Loader {
                    anchors.fill: parent
                    active: root.player.lyricsOpen && root.chromeLive
                    sourceComponent: LyricsOverlay {
                        player: root.player
                        radius: Theme.cornerRadiusXS
                    }
                }
            }

            ClavisSeekbar {
                id: seekbar
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                visible: root.hasSeekbar
                player: root.player
                progressStyle: root.progressStyle
            }

            RowLayout {
                id: transport
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.buttonHeightM
                LayoutMirroring.enabled: false
                spacing: root.narrow ? Theme.spacingXXS : Theme.spacingS

                Item {
                    Layout.fillWidth: true
                }

                ClavisTransportButton {
                    id: shuffleButton
                    mediaAction: "shuffle"
                }

                ClavisTransportButton {
                    id: previousButton
                    mediaAction: "previous"
                }

                ClavisTransportButton {
                    id: playButton
                    mediaAction: "play"
                    size: "m"
                    buttonSize: Theme.buttonHeightM
                    iconSize: Theme.iconSizeLarge
                    Layout.minimumWidth: Theme.buttonHeightM
                    Layout.preferredWidth: Theme.buttonHeightM + Theme.spacingS
                    variant: "filled"
                    iconColor: MediaAccentService.onAccent
                    containerColor: MediaAccentService.accent
                    contentColor: MediaAccentService.onAccent
                }

                ClavisTransportButton {
                    id: nextButton
                    mediaAction: "next"
                }

                ClavisTransportButton {
                    id: repeatButton
                    mediaAction: "repeat"
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }

    ClavisPlayerSelector {
        id: sourceSelector
        anchors.fill: parent
        z: DashMetrics.overlayZ
        player: root.player
        opened: root.sourceSelectorOpen
        popupX: details.x
        popupY: toolbar.height + Theme.spacingXS
        popupWidth: details.width
        onDismissRequested: root.dismissSourceSelector()
    }

    component ClavisTransportButton: MediaTransportButton {
        id: button
        player: root.player
        keepNavigation: true
        visible: true
        buttonSize: Theme.buttonHeightXS
        iconSize: Theme.iconSizeMedium
        iconColor: checked ? MediaAccentService.accent : root.secondaryForeground
        containerColor: MediaAccentService.accentContainer
        contentColor: MediaAccentService.onAccentContainer
        Layout.minimumWidth: Theme.buttonHeightXS
        Layout.preferredWidth: Theme.buttonHeightXS
        Layout.alignment: Qt.AlignVCenter
        tooltipText: Accessible.name
        enabled: {
            if (!root.activePlayer?.canControl)
                return false;
            switch (button.mediaAction) {
            case "shuffle":
                return !!root.activePlayer.shuffleSupported;
            case "previous":
                return !!root.activePlayer.canGoPrevious;
            case "play":
                return !!root.activePlayer.canTogglePlaying;
            case "next":
                return !!root.activePlayer.canGoNext;
            case "repeat":
                return !!root.activePlayer.loopSupported;
            }
            return false;
        }
    }

    Component {
        id: coverBackdrop

        ClippingRectangle {
            radius: root.backdropRadius
            color: "transparent"

            Image {
                id: backgroundArt
                anchors.left: parent.left
                width: parent.width * Theme.clavisBackgroundArtWidthRatio
                height: parent.height
                source: root.artUrl
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready && !root.narrow
            }

            Rectangle {
                anchors.fill: backgroundArt
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Theme.withAlpha(root.surfaceColor, 0)
                    }
                    GradientStop {
                        position: 1
                        color: root.surfaceColor
                    }
                }
            }

            DIcon {
                x: parent.width * (1 - Theme.clavisMetadataWidthRatio) / 2 - width / 2
                anchors.verticalCenter: parent.verticalCenter
                name: "music_note"
                size: Theme.iconSizeLarge
                color: root.secondaryForeground
                visible: backgroundArt.status !== Image.Ready && !root.narrow
            }
        }
    }
}

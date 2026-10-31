pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import "../../../DCommon/Common/FocusNavigation.js" as FocusNavigation

FocusScope {
    id: root

    required property var player
    property bool opened: false
    property real popupX: 0
    property real popupY: 0
    property real popupWidth: width
    readonly property Item focusTarget: sourceList
    readonly property list<MprisPlayer> sources: {
        const active = player.activePlayer;
        const others = (player.allPlayers ?? []).filter(source => source && source !== active);
        return active ? [active].concat(others) : others;
    }
    readonly property bool canRaise: !!player.activePlayer?.canRaise

    signal dismissRequested

    visible: opened
    onSourcesChanged: {
        sourceList.currentIndex = Math.max(0, Math.min(sourceList.currentIndex, sources.length - 1));
        if (opened)
            sourceList.revealIndex(sourceList.currentIndex);
    }
    onOpenedChanged: {
        if (!opened)
            return;
        sourceList.currentIndex = 0;
        sourceList.positionViewAtBeginning();
        sourceList.forceActiveFocus(Qt.OtherFocusReason);
    }

    function selectSource(index) {
        const source = sources[index];
        if (!source)
            return;
        MprisController.setActivePlayer(source);
        dismissRequested();
    }

    function cycleFocus(backwards) {
        const targets = [sourceList, raiseButton].filter(item => item.visible && item.enabled);
        if (targets.length === 0)
            return false;
        const current = targets.findIndex(FocusNavigation.containsFocus);
        const next = current < 0 ? (backwards ? targets.length - 1 : 0) : (current + (backwards ? -1 : 1) + targets.length) % targets.length;
        return FocusNavigation.focusItem(targets[next], backwards);
    }

    function handleKeyEvent(event) {
        switch (event.key) {
        case Qt.Key_F6:
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            return cycleFocus(event.key === Qt.Key_Backtab || !!(event.modifiers & Qt.ShiftModifier));
        case Qt.Key_Up:
            sourceList.currentIndex = Math.max(0, sourceList.currentIndex - 1);
            sourceList.revealIndex(sourceList.currentIndex);
            return true;
        case Qt.Key_Down:
            sourceList.currentIndex = Math.min(sources.length - 1, sourceList.currentIndex + 1);
            sourceList.revealIndex(sourceList.currentIndex);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (raiseButton.activeFocus)
                return false;
            selectSource(sourceList.currentIndex);
            return true;
        }
        return false;
    }

    Keys.onPressed: event => event.accepted = handleKeyEvent(event)

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissRequested()
    }

    Rectangle {
        id: popup
        x: Math.max(0, Math.min(root.width - width, root.popupX))
        y: Math.max(0, root.popupY)
        width: Math.min(root.width, root.popupWidth)
        height: Math.max(0, Math.min(root.height - y, root.sources.length * Theme.buttonHeightXS + Math.max(0, root.sources.length - 1) * Theme.spacingXS + Theme.spacingS * 2 + (raiseButton.visible ? raiseButton.height + Theme.spacingS : 0)))
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainerHigh, 1)
        border.width: Theme.layerOutlineWidth
        border.color: Theme.outlineVariant

        MouseArea {
            anchors.fill: parent
        }

        DListView {
            id: sourceList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: raiseButton.visible ? raiseButton.top : parent.bottom
            anchors.margins: Theme.spacingS
            model: root.opened ? root.sources : []
            spacing: Theme.spacingXS
            clip: true
            fadeEdges: false
            activeFocusOnTab: true
            reuseItems: true
            currentIndex: 0
            Accessible.role: Accessible.List
            Accessible.name: I18n.tr("Players", "Media player selection")

            delegate: DButton {
                id: sourceButton
                required property int index
                required property MprisPlayer modelData
                width: sourceList.width
                buttonHeight: Theme.buttonHeightXS
                maximumWidth: width
                minimumWidth: 0
                text: modelData.identity || I18n.tr("Unknown")
                iconName: modelData === root.player.activePlayer ? "check_circle" : "music_note"
                backgroundColor: index === sourceList.currentIndex ? MediaAccentService.accentSecondaryContainer : "transparent"
                textColor: index === sourceList.currentIndex ? MediaAccentService.onAccentSecondaryContainer : Theme.surfaceText
                onClicked: root.selectSource(index)
            }
        }

        DButton {
            id: raiseButton
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacingS
            buttonHeight: Theme.buttonHeightXS
            maximumWidth: width
            minimumWidth: 0
            visible: root.canRaise
            text: I18n.tr("Open")
            tooltipText: root.player.activePlayer?.identity ?? ""
            iconName: "open_in_new"
            backgroundColor: MediaAccentService.accentContainer
            textColor: MediaAccentService.onAccentContainer
            onClicked: {
                if (!root.canRaise)
                    return;
                root.player.activePlayer.raise();
                root.dismissRequested();
            }
        }
    }
}

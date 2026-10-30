pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../Common/settings/ClockStyle.js" as ClockStyle

Row {
    id: root

    required property string text
    property real fontSize: Theme.clockTextSize(Theme.fontSizeMedium)
    property color color: Theme.primary
    property bool decorated: true
    property bool animate: visible && enabled
    property bool ready: false
    readonly property real lineHeight: fontSize + Theme.spacingXXS * 2
    readonly property var characterIds: ClockStyle.characterIds(text)

    Component.onCompleted: root.ready = true

    Repeater {
        model: root.text.length

        Item {
            id: cell

            required property int index
            readonly property string character: root.text.charAt(index)
            readonly property int digit: /^[0-9]$/.test(character) ? Number(character) : -1
            readonly property var style: SettingsData.clockStyle.digits[root.characterIds[index]]
            readonly property bool styled: root.decorated && !!style

            width: strip.implicitWidth
            height: root.lineHeight
            clip: true
            transform: [
                Translate {
                    x: cell.styled ? cell.style.x : 0
                    y: cell.styled ? cell.style.y : 0
                },
                Rotation {
                    angle: cell.styled ? cell.style.rotation : 0
                    origin.x: cell.width / 2
                    origin.y: cell.height / 2
                }
            ]

            StyledText {
                id: strip

                text: cell.digit < 0 ? cell.character : "0\n1\n2\n3\n4\n5\n6\n7\n8\n9"
                y: cell.digit < 0 ? 0 : -cell.digit * root.lineHeight
                color: cell.styled ? Theme.clockDigitColor(cell.style) : root.color
                font.family: Theme.clockFontFamily
                font.pixelSize: root.fontSize
                // Named weight faces are static; select the variable face before applying its axes.
                font.weight: Font.Normal
                font.variableAxes: Theme.clockFontAxes
                font.features: ({
                        "tnum": 1
                    })
                lineHeight: root.lineHeight
                lineHeightMode: Text.FixedHeight
                verticalAlignment: Text.AlignTop
                wrapMode: Text.NoWrap
                elide: Text.ElideNone

                Behavior on y {
                    enabled: root.ready && root.animate && cell.digit >= 0 && Theme.currentAnimationBaseDuration > 0

                    SpringAnimation {
                        spring: Theme.clockDigitSpring
                        damping: Theme.clockDigitDamping
                    }
                }
            }
        }
    }
}

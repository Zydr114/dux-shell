pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets

Row {
    id: root

    required property string text
    property real fontSize: Theme.clockTextSize(Theme.fontSizeMedium)
    property color color: Theme.primary
    property color alternateColor: Theme.clockAlternateColor
    property bool decorated: true
    property bool animate: visible && enabled
    property bool ready: false
    readonly property real lineHeight: fontSize + Theme.spacingXXS * 2

    Component.onCompleted: root.ready = true

    Repeater {
        model: root.text.length

        Item {
            id: cell

            required property int index
            readonly property string character: root.text.charAt(index)
            readonly property int digit: /^[0-9]$/.test(character) ? Number(character) : -1
            readonly property int digitIndex: root.text.slice(0, index).replace(/[^0-9]/g, "").length
            readonly property int styleIndex: digitIndex % Theme.clockDigitRotations.length
            readonly property bool styled: root.decorated && digit >= 0

            width: strip.implicitWidth
            height: root.lineHeight
            clip: true
            transform: [
                Translate {
                    y: cell.styled ? Theme.clockDigitOffsets[cell.styleIndex] : 0
                },
                Rotation {
                    angle: cell.styled ? Theme.clockDigitRotations[cell.styleIndex] : 0
                    origin.x: cell.width / 2
                    origin.y: cell.height / 2
                }
            ]

            StyledText {
                id: strip

                text: cell.digit < 0 ? cell.character : "0\n1\n2\n3\n4\n5\n6\n7\n8\n9"
                y: cell.digit < 0 ? 0 : -cell.digit * root.lineHeight
                color: cell.styled && cell.digitIndex % 2 === 0 ? root.alternateColor : root.color
                font.family: Theme.clockFontFamily
                font.pixelSize: root.fontSize
                font.weight: Font.Black
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

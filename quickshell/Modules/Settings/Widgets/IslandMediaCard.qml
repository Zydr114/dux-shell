import QtQuick
import qs.Common

SettingsCard {
    id: root

    required property var store
    property string keyPrefix: "island"
    property bool isDot: false

    readonly property string interludeText: root.store.setting("islandLyricsInterludeText")

    visible: !root.isDot
    iconName: "music_note"
    title: I18n.tr("Media and lyrics")
    settingKey: root.keyPrefix + "Media"
    tags: ["island", "media", "lyrics", "clavis", "playback", "compact"]

    SettingsToggleRow {
        settingKey: root.keyPrefix + "MediaClockVisible"
        tags: ["island", "media", "clock", "compact", "time"]
        visible: !root.isDot && root.store.setting("islandMediaPresentation") !== "clavis-lyrics"
        resetStore: root.store
        resetKeys: ["islandMediaClockVisible"]
        text: I18n.tr("Keep clock with media", "island settings: clock in media face toggle")
        checked: root.store.setting("islandMediaClockVisible")
        onToggled: checked => root.store.apply("islandMediaClockVisible", checked)
    }

    SettingsToggleRow {
        settingKey: root.keyPrefix + "MediaAutoSwitch"
        tags: ["island", "media", "playback", "auto", "switch", "compact"]
        visible: !root.isDot
        resetStore: root.store
        resetKeys: ["islandMediaAutoSwitch"]
        text: I18n.tr("Switch to media when playback starts", "island settings: auto-switch the compact face to media toggle")
        checked: root.store.setting("islandMediaAutoSwitch")
        onToggled: checked => root.store.apply("islandMediaAutoSwitch", checked)
    }

    SettingsButtonGroupRow {
        settingKey: root.keyPrefix + "MediaPresentation"
        tags: ["island", "media", "lyrics", "clavis", "compact"]
        visible: !root.isDot
        resetStore: root.store
        resetKeys: ["islandMediaPresentation"]
        text: I18n.tr("Compact media style")
        description: I18n.tr("Clavis lyrics shows the cover, current lyric and spectrum. Lyrics are requested independently of the media page's lyrics option.")
        model: [I18n.tr("Standard"), I18n.tr("Clavis lyrics")]
        values: ["standard", "clavis-lyrics"]
        value: root.store.setting("islandMediaPresentation")
        fallbackValue: "standard"
        onValueSelected: value => root.store.apply("islandMediaPresentation", value)
    }

    SettingsButtonGroupRow {
        settingKey: root.keyPrefix + "MediaTextMode"
        tags: ["island", "media", "lyrics", "title", "track"]
        visible: !root.isDot && root.store.setting("islandMediaPresentation") !== "clavis-lyrics"
        resetStore: root.store
        resetKeys: ["islandMediaTextMode"]
        text: I18n.tr("Media text")
        model: [I18n.tr("Track title"), I18n.tr("Lyrics"), I18n.tr("Title and lyrics")]
        values: ["title", "lyrics", "title-lyrics"]
        value: root.store.setting("islandMediaTextMode")
        fallbackValue: "title"
        onValueSelected: value => root.store.apply("islandMediaTextMode", value)
    }

    SettingsSliderRow {
        settingKey: root.keyPrefix + "MediaMaxWidth"
        tags: ["island", "media", "lyrics", "width"]
        visible: !root.isDot
        resetStore: root.store
        resetKeys: ["islandMediaMaxWidth"]
        text: I18n.tr("Maximum media width")
        unit: "px"
        minimum: 360
        maximum: 560
        step: 10
        value: root.store.setting("islandMediaMaxWidth")
        onSliderDragFinished: value => root.store.apply("islandMediaMaxWidth", value)
    }

    SettingsSliderRow {
        settingKey: root.keyPrefix + "LyricsWidthThreshold"
        tags: ["island", "media", "lyrics", "width"]
        visible: !root.isDot && root.store.setting("islandMediaPresentation") === "clavis-lyrics"
        resetStore: root.store
        resetKeys: ["islandLyricsWidthThreshold"]
        text: I18n.tr("Lyrics resize threshold")
        description: I18n.tr("Reserve space when lyrics grow and ignore small reductions in width.")
        unit: "px"
        minimum: 0
        maximum: 96
        step: 2
        value: root.store.setting("islandLyricsWidthThreshold")
        onSliderDragFinished: value => root.store.apply("islandLyricsWidthThreshold", value)
    }

    SettingsToggleRow {
        settingKey: root.keyPrefix + "LyricsHoldShortGaps"
        tags: ["island", "media", "lyrics", "clavis", "gap", "hold"]
        visible: !root.isDot && root.store.setting("islandMediaPresentation") === "clavis-lyrics"
        resetStore: root.store
        resetKeys: ["islandLyricsHoldShortGaps"]
        text: I18n.tr("Hold lyrics through short gaps")
        description: I18n.tr("Keep the previous lyric visible during short instrumental gaps.")
        checked: root.store.setting("islandLyricsHoldShortGaps")
        onToggled: checked => root.store.apply("islandLyricsHoldShortGaps", checked)
    }

    SettingsSliderRow {
        settingKey: root.keyPrefix + "LyricsShortGapSeconds"
        tags: ["island", "media", "lyrics", "clavis", "gap", "duration", "seconds"]
        visible: !root.isDot && root.store.setting("islandMediaPresentation") === "clavis-lyrics"
        enabled: root.store.setting("islandLyricsHoldShortGaps")
        resetStore: root.store
        resetKeys: ["islandLyricsShortGapSeconds"]
        text: I18n.tr("Maximum short gap")
        unit: "s"
        minimum: 1
        maximum: 10
        step: 1
        value: root.store.setting("islandLyricsShortGapSeconds")
        onSliderDragFinished: value => root.store.apply("islandLyricsShortGapSeconds", value)
    }

    SettingsTextFieldRow {
        settingKey: root.keyPrefix + "LyricsInterludeText"
        tags: ["island", "media", "lyrics", "clavis", "interlude", "instrumental", "text"]
        visible: !root.isDot && root.store.setting("islandMediaPresentation") === "clavis-lyrics"
        resetStore: root.store
        resetKeys: ["islandLyricsInterludeText"]
        text: I18n.tr("Interlude text")
        description: I18n.tr("Shown during instrumental gaps. Leave empty to hide it.")
        maximumLength: 128
        value: root.interludeText
        onEditingFinished: value => {
            if (value !== root.interludeText)
                root.store.apply("islandLyricsInterludeText", value);
        }
    }

    SettingsToggleRow {
        settingKey: root.keyPrefix + "LyricsKeepInterludeWidth"
        tags: ["island", "media", "lyrics", "clavis", "interlude", "width"]
        visible: !root.isDot && root.store.setting("islandMediaPresentation") === "clavis-lyrics"
        resetStore: root.store
        resetKeys: ["islandLyricsKeepInterludeWidth"]
        text: I18n.tr("Keep width during interludes")
        description: I18n.tr("Keep the last lyric's width until the next lyric appears.")
        checked: root.store.setting("islandLyricsKeepInterludeWidth")
        onToggled: checked => root.store.apply("islandLyricsKeepInterludeWidth", checked)
    }
}

# Bar capsule groups

In **Settings → Bar widgets**, use the group button beside a built-in widget to create or edit its group. Add adjacent widgets with **Add previous/next**, move the complete group, or ungroup it. A group belongs to one section; moving a member out of its contiguous run splits the group into independent definitions. Duplicate widget types remain independent instances. Spacer, separator, Island and plugin entries have no group creation button.

The outer capsule uses a low surface tone and a subtle outline. Its children retain their own pill or segment surfaces, hover states and actions. Each group has independent tone, padding, spacing, blur and overflow settings. An empty group has no background, spacing or padding in the layout.

## Configuration

Member entries remain in the existing widget arrays; `groupId` refers to `barConfig.widgetGroups`:

```json
{
  "blur": "on",
  "leftWidgets": [
    { "id": "cpuUsage", "enabled": true, "groupId": "performance" },
    { "id": "memUsage", "enabled": true, "groupId": "performance" }
  ],
  "widgetGroups": {
    "performance": {
      "name": "Performance",
      "style": "pills",
      "padding": 4,
      "spacing": 3,
      "tone": "surface",
      "blur": "inherit",
      "overflowMode": "auto"
    }
  }
}
```

- `style`: `pills` or `segments`, independent of the bar's widget style.
- `tone`: `surface` or `primary`.
- `padding` and `spacing`: logical pixels, constrained to Theme spacing limits and snapped to the screen scale.
- `blur`: `inherit`, `on` or `off`. A group inherits the bar setting; the bar inherits the global setting. The bar setting is available under **Bar appearance → Surface → Background blur**.
- `overflowMode`: `auto`, `bar` or `always`. The complete group is one overflow unit; members cannot be split across the bar and its overflow popup.

Unknown blur values inherit. Invalid group references fall back to ordinary widgets. The runtime requires a widget's `groupContext` property before grouping it; unsupported plugin widgets retain their ordinary presentation.

## Size constraints

The primary size of the outer capsule is the sum of visible child hit sizes (including their outlines), internal gaps and padding at both ends. Flexible media and window-title widgets include their outlines in both natural and minimum sizes.

Across the bar, the child surface is bounded by the available bar thickness minus both outline strokes. Cross padding is then reduced to fit the remaining space. Thus:

```
child surface + 2 × child outline + 2 × cross padding ≤ bar thickness
```

The requested padding still applies along the bar. Increasing it never forces a thicker bar or shrinks every widget simply to preserve the requested cross padding. The section's input bounds include the outer capsule. Horizontal and vertical bars use the same rules.

## Backdrop blur and lifetime

Blur uses the compositor's `ext-background-effect-v1` support and the existing window blur-region registry. The group registers one rounded region; its children do not register duplicate regions. Opaque, hidden and destroyed groups unregister. A group uses an opaque surface when blur is disabled or unsupported. A group with blur off can therefore sit over a bar with blur on without a transparent blurred interior.

The compositor capability probe runs once on demand, including when only a local override requests blur. Frame chrome delegates blur only when the frame actually has global blur enabled. Overflow popups use their existing window background effect.

No persistent timer, polling process or background service is added. Layout changes and widget visibility drive updates. Group surfaces are reused while the group count stays the same; the existing blur registry refreshes their regions when geometry changes. This is event-driven work, and compositor blur cost still depends on the covered area.

## Validation on 2026-10-30–31

`make test-qml`, `make lint-qml` (the two shell entrypoints), and parse checks for all 40 changed QML/JS files passed. The new logic coverage includes empty/hidden members, atomic overflow, flexible widths and outlines, fractional bounds, disconnected group runs, duplicate widget instances, malformed group definitions and blur overrides. Direct lint of individual QML files reports dynamic QObject member and scope warnings and exits nonzero; it is not a clean lint result.

Screenshots from the already running niri session cover all four bar edges, ordinary and Island bars, a center group, large padding/outlines/icons/fonts, segment styling, hidden members, an atomic overflow trigger, the settings list and blur on/off with global blur disabled. The compositor reports `ext-background-effect-v1` support. Settled configuration changes produced no new group binding-loop or script errors; unrelated plugin and missing-icon warnings remain.

The final desktop configuration uses CPU+memory and tray+notifications+Control Center groups on the original top bar, with bar-local blur enabled. Full group-editor click/drag flows, the opened overflow popup, active media playback, other compositors and GPU performance were not visually or performance validated in this pass. Popup backdrops continue to follow the existing popup/global blur policy.

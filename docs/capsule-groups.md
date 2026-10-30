# Bar capsule groups

In **Settings → Bar widgets**, each section shows a one-level tree: ordinary widgets and group rows, with indented members below each group. Click a group row to open its settings directly underneath it. The chevron collapses members; the plus button selects an existing ungrouped widget in that section to add. **Add group**, or **Group** in the add-widget menu, creates a group from a selected existing widget. A group requires at least one member.

Top-level drag handles move a complete group, including across sections. Member handles reorder within the group; **Remove from group** places the member after its former group. Removing the last member removes the empty definition. Group and member rows also participate in keyboard navigation and ordering. Duplicate widget types retain their own settings because operations use occurrence indexes. Unknown and plugin entries remain preserved; the creation picker currently offers supported built-in widgets only.

## Uniform outer size

Ordinary capsule surfaces and group shells use the same outer cross-axis thickness, based on the former default group size. A single-icon ordinary capsule has at least that much primary space so its fill remains round. Content design size is separate from surface size: enlarging an ordinary shell does not enlarge all its icons or text.

Before physical-pixel rounding, the geometry is:

```
T = min(bar thickness, content basis + 2 × default group inset + 2 × effective outline)
ordinary fill = T − 2 × effective outline
group child fill = T − 2 × cross inset − 2 × effective outline
```

Effective outlines reserve a minimum content face before growing; very thin bars reduce them. Cross insets reserve the group border when possible and are constrained by the remaining inner face. A large group padding therefore reduces children inside the fixed shell. Requested padding still applies along the bar. Geometry is calculated on the screen's physical-pixel grid to keep ordinary and grouped bounds consistent at fractional scales.

Group primary size includes visible children, their outlines, internal gaps and both end insets. Flexible media/window-title sizes and the overflow trigger use matching budgets. Hidden children contribute no gaps; an empty group contributes no shell. Horizontal and vertical layouts share these rules, including section input bounds. Dock surfaces retain their separate sizing. Standard `PluginComponent` pills receive ordinary surface sizing and material parameters; custom plugin rendering must support the corresponding properties itself.

## Independent opacity and blur

The widget and group editors expose **Opacity** with an inheritance/override switch and a 0–100% slider, plus a separate blur choice. A widget inherits bar widget opacity; a group shell inherits bar surface opacity. Members can override their own fill opacity, while the group shell supplies their backdrop blur.

Blur is `inherit`, `on` or `off`. It does not force opacity to one when disabled or unavailable. Zero opacity with blur on permits an untinted blurred capsule; opaque fills do not register a blur region. The existing background visibility setting still controls whether an ordinary surface is shown.

A local blur switch controls that surface's request. It cannot reverse blur from an underlying bar/frame surface. Overflow retains its existing popup backdrop policy. The bar's own blur setting remains under **Bar appearance → Surface → Background blur**.

## Configuration compatibility

Members remain in the existing flat widget arrays. `groupId` refers to `barConfig.widgetGroups`; no nested or empty-container schema is introduced:

```json
{
  "blur": "off",
  "leftWidgets": [
    { "id": "clock", "enabled": true, "blur": "on", "backgroundOpacity": 0.25 },
    { "id": "cpuUsage", "enabled": true, "groupId": "performance" },
    { "id": "memUsage", "enabled": true, "groupId": "performance", "backgroundOpacity": 0.8 }
  ],
  "widgetGroups": {
    "performance": {
      "name": "Performance",
      "style": "pills",
      "padding": 4,
      "spacing": 3,
      "tone": "surface",
      "blur": "on",
      "backgroundOpacity": 0.35,
      "overflowMode": "auto"
    }
  }
}
```

- `backgroundOpacity`: absent or `null` inherits; a finite number is constrained to 0–1.
- `blur`: unknown values inherit. Group members use group blur while grouped and retain their own choice for when moved out.
- `style`: `pills` or `segments`, independent of bar style.
- `tone`: `surface` or `primary`.
- `padding` and `spacing`: logical pixels, bounded by Theme tokens and snapped to screen scale.
- `overflowMode`: `auto`, `bar` or `always`; a group moves into overflow as one unit.

Invalid group references fall back to ordinary presentation. Separate runs of the same group are normalized into independent definitions. Cross-section moves update both arrays atomically and retain the moved group's settings.

## Lifetime and validation

Blur uses the compositor's `ext-background-effect-v1` support and the existing window region registry. Each group registers one rounded region, with no duplicate child regions. Hidden, opaque and destroyed surfaces unregister. A local request can trigger the existing one-shot capability probe even when global/bar blur is off. Geometry refreshes reach the window registry, and null geometry during Island teardown is guarded.

No periodic timer, daemon, dependency or socket change was added. Existing event-driven layout and blur rebuilds are reused. Group surfaces retain their instances while the count is stable. Tree editors load only when selected; inherited DReorderList autoscroll runs only during an active drag. This source audit does not measure compositor GPU cost.

Acceptance on **2026-10-31**:

- `make test-qml`: logic suite plus 31 Qt and 38 lock checks passed. Focused regressions cover physical-pixel thickness, constrained padding/outlines, atomic overflow, tree block transfers, duplicate instances, last-member removal, unknown-entry preservation and independent material inheritance.
- `make lint-qml`: both shell entrypoints passed. All 22 changed QML files parsed with `qmlformat`; `git diff --check` passed. These entrypoint/parse checks are not a clean per-file dynamic QML lint result.
- Screenshots from the already running niri session cover mixed ordinary/grouped capsules, a thin vertical bar with large outlines/padding, bottom segments and an overflow trigger, standard Quick Capture pill sizing, the settings tree, opacity with blur on/off, and untinted blur. The compositor probe reported protocol support.
- The original bar configurations and other settings were restored exactly after temporary scenarios. Final settled logs contain no new capsule/tree binding-loop or script errors; unrelated plugin, icon and Island settings warnings remain. The existing shell hot-reloaded the source; no second shell or compositor was started.

Evidence and configuration backups are local to `/tmp/dms-redesign-20261031/`. Full mouse/keyboard drag flows, the opened group editor/add picker/overflow popup, active media playback, other compositors and performance were not interactively validated. The earlier implementation's finite acceptance remains in the Git history preceding this redesign.

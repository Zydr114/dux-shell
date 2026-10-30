# Uniform capsule surfaces and tree group settings

Plan accepted for implementation on 2026-10-31. This supersedes the variable group thickness and flat group editing introduced by `69d30d24f`, `40e3f9544` and `3b5476de4`.

## Outcome

Ordinary capsules and group shells share one outer cross-axis thickness, based on the previous default group shell. Group padding changes the space available to children, rather than increasing the group's outer thickness. Keep the existing content design scale separate so enlarging an ordinary surface does not enlarge every font or icon. Single-icon capsules remain round, and all input bounds, outline budgets and overflow measurements use the same geometry. Dock sizing remains independent.

The layout computes a common outer thickness from the existing widget thickness, default Theme group padding, effective widget outlines and available bar thickness. A grouped child receives the remaining fill thickness after group insets and child outlines. Insets preserve the outer border and shrink before making children unusable in thin bars. Horizontal and vertical bars use the same formulas.

## Settings tree

Project each section's existing flat array into top-level ordinary widgets and group nodes with indented member rows. Provide an explicit Group item in the add menu and a group creation action. Groups expose their name, collapse state, member actions and settings directly. Move top-level groups as blocks, reorder members within a group, select ordinary section widgets to add, and move members out beside their group.

Continue storing flat widget arrays plus `groupId` and `widgetGroups` for compatibility. Use occurrence indexes and ranges so duplicate widget types retain independent settings. Cross-section block moves update both arrays atomically. Creation requires at least one member; removing the last member dissolves the empty group.

## Material controls

Ordinary widget entries and group definitions have independent `blur` (`inherit`, `on`, `off`) and `backgroundOpacity` (`null` or absent to inherit, otherwise 0–1) settings. Ordinary opacity inherits the bar widget opacity; group shell opacity inherits the bar surface opacity. Group members can override their own fill opacity; their backdrop blur is provided by the group shell.

Opacity never changes merely because blur is disabled or unsupported. Zero opacity with blur on permits an untinted blurred surface, while opaque surfaces do not need a blur region. Background visibility remains a separate existing switch. A local blur switch controls that surface's requested effect; it cannot reverse blur already painted by another underlying bar/frame/popup layer. Overflow popups retain their existing window backdrop policy.

Use one lightweight pure logic helper for material inheritance, numeric validation and blur scope discovery. Local widget blur requests must trigger the existing one-shot compositor probe even when global blur is disabled. Geometry updates must reach the current window blur registry. No periodic timer, new daemon, socket protocol or dependency is needed.

## Delivery and acceptance

Implement geometry, tree data/UI and material controls in bounded parallel tasks; review and integrate centrally. Add regressions only for changed pure logic and supported service functions. Run the full existing QML suite, shell entrypoint lint, changed-file parsing and diff checks. Use the already running desktop for finite visual checks, separating transient reload warnings from settled errors; do not start a second shell or compositor for tests.

Preserve the user's current configuration and unrelated work. Restore temporary visual-check settings, retain backup/evidence outside Git, document actual acceptance and remaining limits, commit coherent implementation steps, and push this feature branch to origin.

## Delivery status — 2026-10-31

Implemented and centrally reviewed: common physical-pixel outer geometry, tree settings and atomic group moves, independent per-widget/group material controls, and standard plugin-pill forwarding. Validation and remaining interaction/platform boundaries are recorded in [capsule-groups.md](capsule-groups.md). Temporary desktop scenarios were restored to the exact starting bar configuration. No periodic work or protocol changes were introduced.

---
name: flutter-ui-consistency
description: Build or revise MonaServer Flutter screens using the app's documented design language. Use when a task changes visible Flutter UI.
---

# Flutter UI consistency

Read [`flutter/DESIGN_LANGUAGE.md`](../../../flutter/DESIGN_LANGUAGE.md)
before choosing visual styling or interaction copy. It separates established
patterns from known defects. Check the current theme and neighboring screen
implementation when the document is insufficient; do not turn an observed
exception into a new convention.

Use theme color and type roles and shared widgets where they express the
intended behavior. Keep group, artwork, presence, and progression states
semantically distinct. Make the primary action and its result clear, especially
when a user is collecting a reward or applying a group pin design.

For a substantial screen change, inspect the rendered flow at relevant phone
and wider sizes, with both themes and realistic content. Verify any affected
loading, empty, error, and overlay states. Select a focused widget, golden, or
browser check according to the changed behavior and the repository's
[`flutter/AGENTS.md`](../../../flutter/AGENTS.md); do not generate snapshots
for every minor edit. If the task intentionally changes the visual language,
update the design reference with the approved decision and its source.

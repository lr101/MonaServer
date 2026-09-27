---
name: flutter-visual-review
description: Review MonaServer Flutter screens for visual consistency and usability using rendered evidence. Use when asked for a UI/UX review or to assess a substantial screen change.
---

# Flutter visual review

Read [`flutter/DESIGN_LANGUAGE.md`](../../../flutter/DESIGN_LANGUAGE.md) to
understand the app's intended visual language and its documented exceptions.
Use it as a comparison point, not as proof that an existing pattern works.

Navigate the affected task in the running Flutter app when the user asks for
visual or experiential findings. Follow [`docs/AGENT_LOCAL_STACK.md`](../../../docs/AGENT_LOCAL_STACK.md)
when local API, database, or storage services are needed. Review relevant
phone and wider widths, themes, long or empty content, and transient states;
focus the matrix on the task instead of claiming exhaustive coverage.

For each actionable finding, record the route/action that exposes it, what is
visible, evidence such as a screenshot or reproducible observation, likely
source file, impact on the user, and a plausible fix with its trade-off.
Separate confirmed visual defects from design judgments and test-fixture
artifacts. Include recognition, action hierarchy, feedback, status meaning,
touch/keyboard access, and overlays in addition to alignment and color.
Existing widget tests or source alone cannot establish that a rendered flow
looks and feels correct.

When reviewing Flutter Web-specific browser behavior, use relevant web
guidelines as supplementary evidence. Do not impose HTML/CSS-only rules on
Flutter widgets. Report what was actually run and what was unavailable.

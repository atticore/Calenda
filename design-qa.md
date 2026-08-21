# Design QA
## Comparison target
Source visual truth: /var/folders/jv/yv5d4dgj4939d1hn29vjgzf80000gn/T/codex-clipboard-0732a0d1-e912-46d5-889a-23e81e12edfa.png.
Source size: 854 × 748 px.
Intended state: desktop month view with date-details sidebar and default weather state.
## Implementation evidence
Implementation build: /tmp/CalendaBuild/Build/Products/Debug/Calenda.app.
Implementation screenshot: unavailable.
Viewport, CSS size, density normalization, full-view comparison, and focused-region comparison: unavailable because the desktop Computer Use capture timed out twice after the built app was opened. No code-only comparison was used.
## Findings
- [P1] Visual comparison blocked
  Location: Calendar panel and menu-bar icon.
  Evidence: the reference image was opened successfully, but a screenshot of the native application could not be captured.
  Impact: typography, spacing, deep/light menu-bar rendering, and date-grid density cannot be accepted visually.
  Fix: capture the open Calenda panel on macOS, compare it at its native 620 × 440 pt panel size, then resolve any P1/P2 differences.
## Required fidelity surfaces
- Fonts and typography: blocked; no implementation capture.
- Spacing and layout rhythm: blocked; no implementation capture.
- Colors and visual tokens: blocked; no implementation capture.
- Image quality and asset fidelity: the only nonstandard visual is the code-rendered menu-bar date glyph; its 1, 19, and 31-day render paths have unit coverage, but visual inspection is blocked.
- Copy and content: blocked; no implementation capture.
## Implementation checklist
- Capture the calendar panel, including the header and right information column.
- Capture the menu-bar icon in both light and dark menu-bar contexts.
- Compare both captures to the intended hierarchy, not to the reference image's colors or legacy controls.
## Follow-up polish
- Validate the 18 pt menu-bar glyph's optical weight against the active macOS menu-bar theme.
- Check date-cell density with a 31-day month and a six-row month.
## Final result
final result: blocked

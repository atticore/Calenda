
---
name: calenda-macos-development
description: Develop, debug, and verify Calenda's native macOS menu-bar application. Use for tasks involving SwiftUI/AppKit integration, NSStatusItem, NSPanel, NSHostingView, menu-bar behavior, window or panel positioning, focus, keyboard handling, multi-display behavior, Spaces, Swift concurrency, calendar UI, Xcode builds, tests, previews, runtime debugging, or other implementation work in the Calenda repository.
---

# Calenda macOS Development

Use this workflow when implementing or debugging Calenda.

Read the repository AGENTS.md first and treat it as the source of truth for
architecture and engineering constraints.

## 1. Inspect Before Editing

Before making changes:

- locate the relevant existing implementation
- identify the owning type
- inspect nearby architecture
- determine whether the responsibility belongs to AppKit, SwiftUI, or a service
- inspect existing tests
- identify the current scheme and target rather than guessing

Prefer modifying the existing abstraction instead of creating a parallel one.

Do not begin by rewriting the subsystem.

---

## 2. Classify the Change

Classify the work as one or more of:

### Domain

Examples:

- date calculations
- calendar state
- lunar data
- holiday rules
- cache policy

Prefer deterministic models and unit tests.

### SwiftUI

Examples:

- month grid
- date cell
- selection
- detail view
- settings
- visual state

Use SwiftUI Preview when useful.

### AppKit

Examples:

- NSStatusItem
- NSPanel
- activation
- focus
- positioning
- event monitors
- Settings window coordination
- multi-display behavior
- Spaces

Verify these changes in the running application.

### Service

Examples:

- weather
- location
- holiday data
- persistence
- network fetching

Keep IO and asynchronous state outside views.

---

## 3. Use Xcode MCP

When Xcode MCP is available, use it as the preferred IDE integration.

For implementation work:

1. inspect available schemes and run destinations if necessary
2. make focused source changes
3. request an Xcode build
4. inspect compiler diagnostics
5. fix root causes
6. run relevant tests
7. use previews or runtime debugging when appropriate

Do not claim success until verification succeeds.

### 3.1 Select the verification tool
Choose the tool according to the behavior being verified:

- Use Xcode automation for project structure, schemes, destinations, builds,
  tests, compiler issues, build logs, console output, and SwiftUI previews.
- Use Computer Use for the running macOS application when the assertion is
  about what a user can click, focus, type, see, or dismiss. Use it for
  NSStatusItem and NSPanel interactions, settings-window transitions,
  keyboard handling, display/Spaces behavior, and layout screenshots.
- Use `xcodebuild` for CI, headless execution, reproducible command-line
  failures, and result-bundle collection when Xcode automation is unavailable.

Do not run the same build or test redundantly through multiple layers. A
successful Xcode build proves compilation; it does not prove live AppKit
behavior. If Computer Use is unavailable for a change that requires it, report
runtime verification as not performed rather than inferring it from a build.

### 3.2 Verification matrix

| Change category | Minimum verification |
|-----------------|----------------------|
| Domain or service logic | Relevant serial unit tests |
| SwiftUI content or state | Build, relevant unit/UI tests, Preview or snapshot when visual output matters |
| NSStatusItem or NSPanel lifecycle | Build, relevant tests, live-app Computer Use interaction |
| Panel geometry or pointer behavior | Live-app Computer Use interaction plus an inspected screenshot |
| Test infrastructure or scheme | Run the affected test target and inspect the result bundle or Xcode test result |

For UI tests, keep network, location prompts, user defaults, and third-party
input-method state deterministic. Report environmental skips separately from
failures, and do not treat a suite that skipped its main interaction as fully
verified.

---

## 4. SwiftUI Verification

For an isolated SwiftUI component:

1. build the target
2. render its existing Preview when available
3. inspect a Preview Snapshot when visual output matters
4. test important state variants when the change affects them

Useful variants may include:

- light appearance
- dark appearance
- today
- selected date
- holiday
- workday adjustment
- dates outside the displayed month
- long lunar/holiday text

Do not add Preview-only production architecture.

---

## 5. AppKit Verification

For NSStatusItem or NSPanel behavior, SwiftUI Preview is not sufficient.

Build and run Calenda.

Exercise the behavior affected by the patch.

Depending on scope, verify:

- click status item to open
- click status item again
- click outside the panel
- press Escape
- switch applications
- reopen the panel
- open Settings
- close Settings
- return to the panel
- keyboard navigation
- menu-bar position
- visible-screen bounds
- multiple displays
- Spaces

Use Computer Use for these interactions when available. Prefer accessibility
tree actions for control discovery and screenshots for visual or geometry
assertions. Re-read the current app state after each interaction; do not reuse
stale UI element indices. If the test setup terminates stale Calenda processes,
do not run it alongside a manually launched instance or another UI-test session.

Do not attempt to solve lifecycle bugs with arbitrary delays unless there is a
documented OS timing requirement.

Prefer understanding:

- NSApplication activation
- NSWindow/NSPanel ordering
- responder chain
- event monitor lifetime
- object ownership
- screen geometry

---

## 6. Swift Concurrency

When a Swift 6 concurrency diagnostic appears:

1. identify which actor owns the mutable state
2. identify where the value crosses an isolation boundary
3. determine whether the operation is UI-bound
4. use MainActor for UI/AppKit ownership
5. use actors for appropriate mutable service state
6. prefer Sendable value types across boundaries

Do not immediately apply:

- @unchecked Sendable
- nonisolated(unsafe)
- Task.detached

These are escape hatches, not default fixes.

---

## 7. Network and Cache Changes

For HolidayService or WeatherService changes, reason about all states:

- initial state
- valid cache
- stale cache
- successful network refresh
- network unavailable
- malformed response
- permission unavailable where applicable

Calenda's core calendar must remain functional when remote data is unavailable.

Prefer last-known-good data plus an explicit freshness/error state over
discarding useful cached information.

---

## 8. Avoid Dependency Creep

Before adding a package, verify that the task cannot reasonably be solved by:

- Foundation
- AppKit
- SwiftUI
- CoreLocation
- URLSession
- existing project code

Do not add convenience libraries for small functionality.

---

## 9. Build Failure Workflow

If build fails:

1. capture the meaningful diagnostic
2. identify the earliest root error
3. inspect the relevant source
4. make the smallest correct fix
5. rebuild

Do not make broad speculative edits in response to cascading compiler errors.

---

## 10. Completion

A Calenda coding task is complete only when the appropriate verification has
been performed.

Report:

- files/components changed
- behavior changed
- verification tools used (Xcode automation, Computer Use, or `xcodebuild`)
- tests performed
- build result
- runtime or Preview verification when applicable
- result-bundle or screenshot artifacts when produced
- skipped tests and their environment limitations
- any remaining limitation

Never report "verified" if the relevant command, test, preview, or runtime
interaction was not actually performed.

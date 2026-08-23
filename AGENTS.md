
# Calenda Repository Instructions

## Project

Calenda is a native macOS menu-bar calendar application.

Technology:

- Xcode 27 beta 5
- Swift 6.4 compiler
- Swift 6 language mode
- SwiftUI + AppKit hybrid architecture
- AppKit owns menu-bar and panel/window lifecycle.
- SwiftUI owns application content views.
- Swift Package Manager is the package manager.
- Tyme4Swift is used behind an adapter for lunar-calendar calculations.

Primary UI architecture:

NSStatusItem
    ↓
AppKit status-item controller
    ↓
NSPanel
    ↓
NSHostingView
    ↓
SwiftUI calendar UI

Do not replace this architecture with MenuBarExtra, NSPopover, Catalyst,
Electron, Tauri, WebView, or another framework unless explicitly requested.

---

## Product Constraints

Calenda is intentionally small and native.

Do not introduce:

- a backend service
- user accounts
- analytics
- telemetry
- paid APIs
- unnecessary third-party SDKs
- unnecessary runtime dependencies

The core calendar must remain useful offline.

Offline-capable functionality includes:

- Gregorian calendar
- lunar calendar
- solar terms

Remote or environment-dependent functionality includes:

- Chinese statutory holiday data
- weather
- location-derived weather

These features must degrade gracefully when unavailable.

Do not make remote availability a prerequisite for showing the calendar.

---

## Architecture

Prefer the following dependency direction:

Views
    ↓
View Models / Observable State
    ↓
Domain Services
    ↓
Adapters / Clients / Persistence

Do not put networking, filesystem IO, location requests, or calendar
calculation directly inside SwiftUI View bodies.

Keep domain logic independent from AppKit whenever practical.

### AppKit responsibilities

AppKit is responsible for:

- NSStatusItem
- NSStatusBarButton
- NSPanel lifecycle
- panel positioning
- panel activation
- keyboard focus
- outside-click dismissal
- multi-display behavior
- Spaces behavior
- application lifecycle integration
- Settings window lifecycle where AppKit coordination is necessary

Keep strong references to long-lived AppKit objects such as:

- NSStatusItem
- NSPanel
- panel/window controllers
- event monitors

Do not create these as temporary local values.

### SwiftUI responsibilities

SwiftUI is responsible for:

- calendar grid
- month header
- date cells
- selected-date state presentation
- lunar/holiday/solar-term labels
- detail content
- weather presentation
- settings content
- normal view animation

Do not move window-management behavior into SwiftUI merely to avoid AppKit.

---

## NSPanel Rules

The menu-bar calendar popup is an NSPanel, not a normal NSWindow.

The implementation must correctly handle:

- opening from the status item
- closing when appropriate
- repeated open/close cycles
- focus
- keyboard interaction
- Escape dismissal
- status-item positioning
- screen-edge positioning
- menu bar placement
- multiple displays
- Spaces
- switching applications
- reopening after Settings
- app activation/deactivation

Do not assume the main screen is the screen containing the menu-bar item.

Panel positioning must use the actual status-item/window/screen geometry.

Avoid hard-coded global screen coordinates.

Any change involving panel lifecycle, positioning, focus, or event monitors
requires live-app verification. SwiftUI Preview alone is insufficient.

---

## Concurrency

Use Swift concurrency.

Prefer:

- async/await
- Task
- actors
- @MainActor
- structured concurrency

Avoid:

- DispatchQueue-based concurrency when async/await is suitable
- Task.detached unless isolation is intentionally being escaped
- shared mutable state without isolation
- blocking waits
- semaphores for async control flow

UI and AppKit state belong on MainActor.

Long-running or shared mutable service state should use appropriate actor
isolation.

Respect Swift 6 strict concurrency diagnostics.

Do not silence Sendable or actor-isolation warnings without understanding
the underlying ownership problem.

Avoid `@unchecked Sendable` unless there is a documented and justified
thread-safety invariant.

---

## Observation and State

Use modern Observation where appropriate.

Prefer a clear owner for every piece of mutable application state.

Do not create duplicated sources of truth for:

- selected date
- displayed month
- current location
- weather
- holiday data
- settings

Views should derive presentation state rather than synchronizing redundant
copies manually.

---

## Services

Keep external capabilities behind explicit service boundaries.

Expected conceptual services include:

- LunarCalendarService
- HolidayService
- WeatherService
- LocationService
- PersistenceService

Names may differ if the existing codebase already uses another coherent
convention.

Do not introduce new abstractions solely to satisfy this document.

Follow the existing architecture when it is already clean.

### Lunar calendar

Tyme4Swift must be isolated behind an application-owned adapter/service.

Do not expose Tyme4Swift types throughout the SwiftUI hierarchy.

Application code should consume Calenda-owned domain models.

### Holidays

Holiday data must support:

- local cache
- last-known-good data
- explicit stale/unavailable state
- graceful fallback

A holiday-network failure must not prevent calendar rendering.

### Weather

Weather must be optional.

Use Open-Meteo through a dedicated client/service.

Do not couple calendar rendering to successful weather retrieval.

Location permission must remain optional.

Support a manually selected city independently of location permission.

### Persistence

Prefer:

- UserDefaults for small preferences
- Application Support JSON/files for cached structured data

Do not store large cache payloads in UserDefaults.

Do not add a database unless requirements clearly justify one.

---

## Dependencies

Before adding a third-party package:

1. Check whether Foundation, AppKit, SwiftUI, or another Apple framework
   already solves the problem.
2. Check whether the existing project already contains equivalent
   functionality.
3. Explain why a dependency is justified.
4. Prefer small, actively maintained Swift packages.
5. Avoid adding packages for trivial utilities.

Do not add or upgrade dependencies opportunistically during unrelated work.

---

## macOS UX

Calenda should behave like a native macOS menu-bar utility.

Prefer platform conventions over iOS-style UI transplanted to macOS.

Pay attention to:

- pointer interaction
- keyboard navigation
- focus rings
- hover states
- window activation
- menu behavior
- accessibility
- reduced motion
- light/dark appearance
- Dynamic Type where applicable

Use SF Symbols when an appropriate system symbol exists.

Do not use custom icons merely to mimic an available SF Symbol.

---

## Accessibility

For interactive UI changes, consider:

- accessibility labels
- accessibility values
- accessibility identifiers when useful for tests
- keyboard accessibility
- VoiceOver semantics
- sufficient hit targets
- state conveyed by more than color alone

Calendar cells should expose meaningful date/state information to
accessibility APIs.

---

## Build System

Do not change any of the following unless explicitly required:

- bundle identifier
- signing team
- signing certificate
- entitlements
- sandbox configuration
- deployment target
- build configuration names
- scheme names

Do not modify signing settings merely to make a local build pass.

Never commit:

- DerivedData
- xcuserdata
- user-specific Xcode state
- local secrets
- signing certificates
- provisioning profiles

---

## Xcode Usage

When Xcode MCP is available, prefer Xcode tools for:

- discovering schemes
- discovering run destinations
- build
- test
- compiler diagnostics
- runtime diagnostics
- SwiftUI previews
- preview snapshots
- launching/debugging the application

Use shell/xcodebuild when:

- MCP does not expose the required operation
- reproducing a CLI/CI build
- inspecting build settings
- debugging an MCP-specific failure

Do not repeatedly run both MCP build and xcodebuild if one successful build
already provides sufficient evidence.

---

## Build Verification

Before building, inspect the actual project rather than guessing scheme names.

Useful CLI commands:

```bash
xcodebuild -list -project Calenda.xcodeproj

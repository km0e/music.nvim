# Version 0.1.1 (2025-09-04)

This release includes the following improvements and bug fixes:

- Refactored keybinding with Snacks `Action` for better consistency.
- Added Lyrics support.

# Version 0.2.1 (2025-09-21)

## Improvements

- Refactored state management using table `__newindex` metamethod.
- Refactored ui elements to use `snacks` components.

# Version 0.2.2 (2025-09-21)

## Improvements

- Added support for fetching current playback information across instances.

## Bug Fixes

- Fixed issue where the application would not automatically start a new MPV server when the connected server was closed.
- Fixed issue where the application would not correctly update the playback status when the value could be evaluated as false.

# UI Corner Layout — Emergency Accessibility Requirement

## Problem

In emergency scenarios the phone screen may be cracked or partially broken.
Touch digitizers often still work (especially at edges and corners) even when
the display is unreadable. The user may need to operate the app blind or
with minimal visual feedback.

## Requirement

The four most critical actions must be placed at the four corners of the
screen as large, full-bleed tap targets. No precision tapping. No small
buttons. No gestures.

```
┌─────────────────────────────────┐
│ SEARCH                     MAPS │
│                                 │
│                                 │
│                                 │
│                                 │
│                                 │
│ STATUS                     SYNC │
└─────────────────────────────────┘
```

## Corner assignments

| Corner | Action | Why this corner |
|--------|--------|-----------------|
| Top-left | **Search** | Most used action. Left-hand thumb natural position. |
| Top-right | **Maps** | Second most used. Right-hand natural. |
| Bottom-left | **Status** | "Am I ok? What do I have?" Glanceable, not urgent. |
| Bottom-right | **Sync** | One-shot sync trigger. Intentional action, bottom-right avoids accidental tap. |

## Design constraints

- Each corner target must be at least 25% of screen width and 15% of screen height.
- Targets must start from the physical edge of the screen (no margins, no padding from edge).
- Targets must have high contrast (black on white or white on black). No gradients, no transparency.
- Targets must respond to a single tap. No long-press, no swipe, no double-tap.
- Haptic feedback (vibration) on tap if the device supports it — confirms action when screen is unreadable.
- Audio confirmation optional but useful: a short distinct tone per action.

## States

Each corner should communicate its state through color alone (for partial screen visibility):

| State | Color |
|-------|-------|
| Ready / idle | White background, black text |
| Active / loading | Inverted (black background, white text) |
| Error / unavailable | Red background, white text |
| Success / done | Green background, white text |

## Sync corner specifics

The sync button arms a one-shot sync per the network policy model.
It must show:

- Current network policy (OFF)
- "Tap to arm one-shot sync"
- After tap: "Armed — waiting for network" or "Syncing..." or "Done: N items"
- Auto-disarm per the one-shot contract

Tapping sync when already armed should disarm (cancel), not double-trigger.

## Not in scope for this document

- Internal page layouts (search results, map view, document reader)
- Navigation between pages
- Settings or configuration UI
- This document defines only the home screen corner layout requirement

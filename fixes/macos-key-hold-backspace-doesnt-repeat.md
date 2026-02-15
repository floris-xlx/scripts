# macOS Key Hold / Backspace Repeat Failure

## Problem Description

When holding the Backspace (Delete) key, only a single character is removed instead of continuous deletion.

This indicates macOS receives a single key-down event followed by a key-up event rather than a repeating key-down stream. The keyboard repeat engine itself is not malfunctioning — input events are being intercepted or collapsed before reaching the text system.

This is not caused by normal keyboard repeat speed settings.

---

## Quick Isolation Test

1. Open **TextEdit**
2. Type a long sentence
3. Hold Backspace

Result interpretation:

* Repeats normally → application-level problem (editor/plugin)
* Deletes one character → system-level interception (most cases)

---

## Step 1 — Disable Accessibility Key Filters

macOS accessibility features can convert held keys into single presses.

Navigate:

System Settings → Accessibility → Keyboard

Disable ALL of the following:

* Slow Keys
* Sticky Keys
* Key Repeat (visible only if Slow Keys enabled)

Then also:

System Settings → Accessibility → Pointer Control → Alternate Control Methods
Disable:

* Mouse Keys

---

## Step 2 — Disable Accent Press-and-Hold Behavior

macOS replaces key repeat with accent popup input unless disabled.

Run in Terminal:

```
defaults write -g ApplePressAndHoldEnabled -bool false
killall Finder
```

Log out or reboot afterwards.

---

## Step 3 — Detect Low-Level Event Interference

Run:

```
hidutil eventmonitor
```

Hold Backspace.

Expected (correct):
Multiple repeating key-down events

Broken:
Single key-down followed immediately by key-up

If broken → the problem is below macOS UI level.

---

## Step 4 — Input Remappers (Common Cause)

Check for keyboard event interception tools:

* Karabiner-Elements
* BetterTouchTool
* Hammerspoon
* Vim input plugins
* Remote desktop clients

Check running processes:

```
ps aux | grep -i karabiner
```

If present:

1. Fully quit the application
2. Unplug and reconnect keyboard
3. Test again in TextEdit

---

## Step 5 — External Keyboard Firmware Mode

Many mechanical keyboards send discrete presses when in NKRO / rapid trigger mode.

Test using built-in Mac keyboard.

If built-in works:
Switch external keyboard to:

* Mac mode
* 6KRO mode
* Disable rapid trigger

---

## Step 6 — Reset macOS Repeat Engine

```
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
killall SystemUIServer
```

Reboot after running.

---

## Root Cause Summary

A held key producing a single deletion means macOS is not receiving continuous key-down interrupts.

Possible layers causing this:

1. Accessibility filters collapsing input
2. Event tap / remapping software
3. Remote input virtualization layer
4. Keyboard firmware mode

Normal keyboard settings alone cannot produce this symptom.

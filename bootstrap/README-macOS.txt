Emergency Nomad for macOS
=========================

Read this first.
These instructions are written for someone who does not work with computers.

What this folder does
---------------------

This folder installs the Emergency Nomad runtime onto an Android phone by USB.
It also includes ADB. No internet download is needed during install.
After install, the phone runs the local runtime by itself.
The USB cable is only for install, broken-screen mode, or fallback restart.

What to do before an emergency
------------------------------

Do this once, while the phone still works normally.

1. Unlock the Android phone.

2. Open `Settings`.

3. Find `Build number`.
   The easiest way:
   - tap the search bar inside `Settings`
   - type `Build number`
   - open the result

4. If search does not find it, try this path:
   - `Settings`
   - `About phone`
   - `Software information`
   - `Build number`

5. Tap `Build number` 7 times.
   If the phone asks for the PIN or passcode, enter it.
   The phone should then say that Developer Options are turned on.

6. Go back to `Settings`.

7. Find `USB debugging`.
   The easiest way:
   - tap the search bar inside `Settings`
   - type `USB debugging`
   - open the result

8. If search does not find it, try this path:
   - `Settings`
   - `Developer options`
   - `USB debugging`

9. Turn `USB debugging` ON.
   If the phone shows a warning, accept it.

10. Connect the phone to this Mac with a real data cable.

11. Watch the phone screen.
    When the phone asks for USB debugging permission:
    - tap `Allow`
    - also check `Always allow from this computer`

How to install
--------------

1. Put the emergency bundle `.zip` file in this folder.

2. Connect the phone with the USB cable.

3. Unlock the phone and leave the screen on.

4. Double-click `Emergency Install.command`.

5. If your Mac blocks the file, stop and follow the next section:
   `If macOS blocks the installer`

6. Read the text on the screen.

7. When the screen asks:
   `Proceed? [y/N]`
   type:

   `y`

8. Press the `Return` key.

9. Wait.
   Do not unplug the cable while it is working.

10. When the install is finished, the phone should open a browser page.

After phone reboot
------------------

If the phone restarts later:

1. Wait up to 2 minutes.
2. The local runtime should start again by itself.
3. If the local page does not come back, connect the phone by USB.
4. Double-click `Emergency Restart.command`.

Broken screen mode
------------------

If the phone screen is broken but USB debugging was already approved:

1. Connect the phone by USB.
2. Double-click `Emergency Restart (headless).command`.
3. Use the browser on the Mac.

If macOS blocks the installer
-----------------------------

This package is not signed with an Apple Developer certificate.
macOS may block it the first time.

If you see a warning like:

- "cannot be opened because the developer cannot be verified"
- "Apple could not verify it is free of malware"

do this exactly:

1. Open `Terminal`.
   The easiest way:
   - press `Command + Space`
   - type `Terminal`
   - press `Return`

2. In the Terminal window, type:

   `cd `

   Important:
   there is one space after `cd`.

3. Drag this installer folder from Finder into the Terminal window.
   The folder path will appear by itself.

4. Press `Return`.

5. Then type exactly:

   `bash "./Emergency Unblock.command"`

6. Press `Return`.

7. Wait until the window says `Done`.

8. Close Terminal.

9. Double-click `Emergency Install.command` again.

If something goes wrong, do this
--------------------------------

If the phone asks whether to allow USB debugging:
- tap `Allow`
- also check `Always allow from this computer`

If the phone is only charging and nothing else happens:
- try a different USB cable
- many cables are charge-only

If the phone does not show the permission message:
- unlock the phone
- unplug the cable
- plug the cable in again

If the phone restarts later:
- wait up to 2 minutes first
- if the local page does not come back, reconnect it by USB
- then double-click `Emergency Restart.command`

If the phone screen is broken but USB debugging was already approved:
- reconnect it by USB
- double-click `Emergency Restart (headless).command`

Files in this folder
--------------------

- `Emergency Install.command` - install to the phone
- `Emergency Restart.command` - fallback restart if reboot did not recover by itself
- `Emergency Restart (headless).command` - broken-screen mode
- `Emergency Unblock.command` - removes the macOS block on this folder
- `*.zip` - the emergency bundle
- `tools/` - installer files, leave them alone

# Emergency Nomad Installation Guide

This guide is written for a person who is not technical.
It explains how to install the emergency runtime onto an Android phone using a USB cable.

Read this first
---------------

- This is emergency software.
- It is meant for a dedicated Android utility phone, not a personal daily-use phone.
- The installer copies the runtime to the phone.
- It may also install the helper APK `com.emergency.nomad` by ADB.
- It does not download anything from the internet during install.
- After install, normal use is on the phone itself.
- The USB cable is for install, broken-screen mode, and fallback restart.

What you need
-------------

1. A computer.
   Supported paths:
   - Mac
   - Linux
   - Windows with the packaged installer or WSL

2. An Android phone.
   Use a phone dedicated to this purpose if possible.

3. A real USB data cable.
   Some cheap cables are charge-only.
   If the phone is charging but the computer never sees it, the cable may be the problem.

4. The emergency bundle `.zip` file.
   Download it before the emergency.

Prepare the phone now, not later
--------------------------------

Do this while the phone still works and the screen is usable.

### 1. Turn on Developer Options

Do not assume you already have this.
Most people do not.

Try this first:

1. Open `Settings`.
2. Tap the search bar inside `Settings`.
3. Type `Build number`.
4. Open the result.
5. Tap `Build number` 7 times.

If search does not find it, try:

1. Open `Settings`.
2. Open `About phone`.
3. Open `Software information`.
4. Find `Build number`.
5. Tap it 7 times.

If the phone asks for a PIN or passcode, enter it.
The phone should then say that Developer Options are enabled.

### 2. Turn on USB debugging

Try search first:

1. Open `Settings`.
2. Tap the search bar.
3. Type `USB debugging`.
4. Open the result.
5. Turn `USB debugging` on.

If search does not find it, try:

1. Open `Settings`.
2. Open `Developer options`.
3. Turn `USB debugging` on.

The phone may show a warning.
Accept it.

### 3. Approve this computer

1. Connect the phone to the computer with the USB cable.
2. A message should appear on the phone asking whether to allow USB debugging.
3. Tap `Allow`.
4. Also check:
   `Always allow from this computer`

This step matters.
If the phone screen is broken later, the computer must already be approved.

Mac users: if macOS says "Unidentified Developer"
-------------------------------------------------

The Mac package is not signed with an Apple Developer certificate.
macOS may block it the first time.

If you see a message like:

- "cannot be opened because the developer cannot be verified"
- "Apple could not verify it is free of malware"

do this:

1. Open `Terminal`.
   The easiest way:
   - press `Command + Space`
   - type `Terminal`
   - press `Return`

2. In the Terminal window, type:

```text
cd 
```

There is one space after `cd`.

3. Drag the installer folder from Finder into the Terminal window.
   The folder path will appear by itself.

4. Press `Return`.

5. Then type:

```bash
bash "./Emergency Unblock.command"
```

6. Press `Return`.
7. Wait for the word `Done`.
8. Double-click `Emergency Install.command` again.

If the helper file is missing, use:

```bash
xattr -dr com.apple.quarantine .
```

Simple install on Mac
---------------------

If you are using the prepared Mac package:

1. Put the emergency bundle `.zip` file in the same folder as `Emergency Install.command`.
2. Connect the phone by USB.
3. Unlock the phone and leave the screen on.
4. Double-click `Emergency Install.command`.
5. If the Mac blocks it, do the steps in the previous section.
6. Read the screen.
7. When asked `Proceed? [y/N]`, type:

```text
y
```

8. Press `Return`.
9. Wait.
10. When it finishes, the phone should open a browser page.

If the phone restarts later:

1. Wait up to 2 minutes.
2. The local runtime should start again by itself.
3. If the local page does not come back, reconnect the phone by USB.
4. Double-click `Emergency Restart.command`.

If the phone screen is broken:

1. Reconnect the phone by USB.
2. Double-click `Emergency Restart (headless).command`.
3. Use the browser on the Mac.

Terminal install on Mac, Linux, or WSL
--------------------------------------

Use this only if you are not using the prepared desktop package.

You need:

- `adb`
- `python3`

Examples:

Mac with Homebrew:

```bash
brew install android-platform-tools python
```

Ubuntu / Debian / WSL:

```bash
sudo apt install adb python3
```

Install from Terminal:

```bash
cd /path/to/emergency-nomad
./bootstrap/usb-push.sh /path/to/bundle.zip
```

What happens next:

1. The script checks the phone.
2. The script shows a declaration.
3. Type `y` and press Enter.
4. The script copies files to the phone.
5. If the package includes it, the helper APK is installed.
6. The local browser page is opened on the phone.

After installation
------------------

- The phone uses a local address like `http://127.0.0.1:1234/...`
- This page is local to the phone.
- Internet is not required for local use.
- You can unplug the USB cable after install.
- If you want the phone to be radio-silent, turn off mobile data, Wi-Fi, and Bluetooth yourself.
  The installer does not change those settings for you.

Common problems
---------------

### "adb: command not found"

`adb` is not installed, or it is not in the current PATH.
Install it first.

### "error: no ADB device connected"

Check these:

1. The phone is on.
2. USB debugging is enabled.
3. The cable is a data cable, not charge-only.
4. The phone already approved this computer.

### The phone shows `unauthorized`

The phone is waiting for you to approve the computer.
Look at the phone screen and tap `Allow`.
Also check `Always allow from this computer`.

### The Mac says "developer cannot be verified"

Do not guess.
Do this exactly:

1. Press `Command + Space`
2. Type `Terminal`
3. Press `Return`
4. Type `cd ` and then drag the installer folder into the window
5. Press `Return`
6. Type `bash "./Emergency Unblock.command"`
7. Press `Return`
8. Wait for `Done`
9. Try `Emergency Install.command` again

### The script says multiple devices are connected

More than one Android device is plugged in.
Disconnect the others, or choose the device with `-s SERIAL`.

### The browser does not open on the phone

Wait a few seconds, then try again.
If needed, reconnect by USB and run:

```bash
./bootstrap/usb-push.sh --restart
```

### Windows and WSL do not see the phone

This can happen.
Use the Windows package or native Windows ADB instead of WSL for that machine.

Short version
-------------

Do this now:

1. Turn on Developer Options.
2. Turn on USB debugging.
3. Approve this computer.
4. Keep the bundle file ready.

Do this during the emergency:

1. Connect the phone by USB.
2. On Mac, double-click `Emergency Install.command`.
3. Type `y`.
4. Wait.

Do this after phone reboot:

1. Wait up to 2 minutes.
2. If the local page does not come back, connect the phone by USB.
3. Double-click `Emergency Restart.command`.

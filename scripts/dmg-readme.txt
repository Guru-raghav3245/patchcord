MTP Tool 1.0.2
Copy files between your Mac and Android phones and players (like the Activo CT10) over USB.
Needs a Mac with Apple silicon (M1 or later) and macOS 12 or later.

INSTALL
1. Drag MTPTool into the Applications folder.
2. Open it. macOS will say it can't verify the developer. Click Done.
3. Open System Settings > Privacy & Security, scroll down, click "Open Anyway"
   next to MTPTool, and confirm. You only need to do this once.
   (MTP Tool is free and isn't signed with a paid Apple Developer ID, so macOS asks first.)

CONNECTING A DEVICE
- Use a USB data cable. Charge-only cables won't work.
- On the device, set the USB mode to "File transfer" (MTP).
- Quit other MTP apps first (Android File Transfer, MacDroid, OpenMTP).
  Only one app can use the device at a time; MTP Tool tells you which app has it.

PRIVACY
MTP Tool works entirely over USB. It makes no network connections and collects no data.

OPEN SOURCE
MTP Tool uses libmtp and libusb under the GNU LGPL 2.1. Their licences and our changes
to libmtp are inside the app (MTPTool > Show Package Contents > Contents > Resources > Licenses).
The library source code is available from the same page as this download.

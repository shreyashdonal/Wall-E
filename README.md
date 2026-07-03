# Wall-E
<<<<<<< HEAD

Browse folders of movie snapshots and set them as your desktop wallpaper,
navigable with global arrow-key hotkeys.

## Run (script)

```powershell
powershell.exe -ExecutionPolicy Bypass -File Wall-E.ps1
```
(or right-click `Wall-E.ps1` > Run with PowerShell)

## Build a portable .exe

Run this **once**, on Windows, from inside the `Wall-E` folder:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1
```

This installs the free, open-source `ps2exe` module (only if it isn't
already on your machine) and compiles `Wall-E.ps1` into `Wall-E.exe`,
with the app icon baked in and no console window popping up.

**To share the app with someone else:** zip up the whole `Wall-E` folder
(`Wall-E.exe` + `modules\` + `UI\` + `assets\`) and send that. They unzip
it anywhere and double-click `Wall-E.exe` - no installer, no PowerShell
knowledge needed, and it runs on any Windows 10/11 PC (PowerShell/.NET
is built in).

> The `.exe` is a launcher wrapping the script, not a single fully-merged
> binary - it still needs `modules\`, `UI\`, and `assets\` sitting next to
> it, exactly like `Wall-E.ps1` does. That's normal for ps2exe output and
> is what keeps the whole thing simple, readable, and easy to tweak later.

## Build a Windows installer (Wall-E-Setup.exe)

For sharing/selling Wall-E as a proper installed app (not just a zip),
use the included Inno Setup script:

1. Build `Wall-E.exe` first (see above).
2. Install [Inno Setup](https://jrsoftware.org/isdl.php) (free).
3. Open `WallE.iss` in Inno Setup and click **Compile**, or from the
   command line:
   ```powershell
   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" WallE.iss
   ```
4. The installer is written to `Output\Wall-E-Setup.exe` - that single
   file is what you distribute (or sell). It installs per-user (no admin
   needed), adds Start Menu/desktop shortcuts, and includes a clean
   uninstaller.

Before compiling, open `WallE.iss` and edit `MyAppPublisher` and
`MyAppURL` at the top to your own name/site.

## Structure

```
Wall-E/
├── Wall-E.ps1               # entry point (script version)
├── Wall-E.exe                # built by build.ps1 - portable, double-click to run
├── build.ps1                 # compiles Wall-E.ps1 -> Wall-E.exe
├── WallE.iss                  # Inno Setup script -> Wall-E-Setup.exe installer
├── assets/
│   ├── icon.ico               # app / window icon (multi-res)
│   └── icon.svg               # source vector
├── modules/
│   ├── Wallpaper.ps1          # sets/restores the desktop wallpaper
│   ├── WallpaperHelper.ps1
│   ├── SnapshotLibrary.ps1    # scans folders of snapshots
│   ├── GlobalHotkey.ps1       # system-wide arrow-key hotkeys
│   └── Cache/                  # runtime config + log (auto-created)
└── UI/
    ├── MainWindow.xaml         # main app window
    └── FullScreenWindow.xaml   # full-screen preview
```

## Controls

- **Right** = next image in current folder
- **Left** = previous image in current folder
- **Up** = next folder
- **Down** = previous folder
- **S** = toggle Slideshow (timed autoplay)
- **P** = toggle Quick Play (fast stop-motion flip-through)

Arrow-key hotkeys are global (system-wide); S/P only work while the app
window is focused.
=======
A wallpaper manager that provides multiple functionalities that windows doesn't.
>>>>>>> 74a681becdbb03b5fd87f9829a56e61bcbb64e1d

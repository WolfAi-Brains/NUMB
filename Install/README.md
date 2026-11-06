# NUMB installer

Installs for the **current user only** — **no administrator** required on target PCs.

Default folder: **`%LocalAppData%\WolfAi\NUMB`** (e.g. `C:\Users\you\AppData\Local\WolfAi\NUMB`).

Bundled **portable AutoHotkey v2.0.31** (`AutoHotkey64.exe` next to `NUMB.ahk`). `Start NUMB.bat` uses that copy first.

## Option A — Single setup EXE (recommended)

1. Install [Inno Setup 6](https://jrsoftware.org/isdl.php) on your build machine.
2. Ensure **`portable\AutoHotkey64.exe`** exists (included in repo; from [AutoHotkey 2.0.31 zip](https://github.com/AutoHotkey/AutoHotkey/releases/tag/v2.0.31)).
3. Run:

   ```powershell
   cd C:\WolfAi\NUMB\Install
   .\Build-Installer.ps1
   ```

4. Ship **`Output\NUMB-Setup-2.1.0.exe`**. Users run it **without** elevating.

**Upgrades:** Run the new setup EXE on a PC that already has NUMB (same `AppId`). Setup reuses the previous install folder, replaces program files, keeps **`numb.ini`**, closes a running NUMB/AutoHotkey64 briefly if needed, and preserves the logon startup shortcut if you already had one.

The wizard **checks “Start NUMB when Windows starts” by default** (Startup folder shortcut). Uncheck on the tasks page if you do not want logon startup.

Optional: launch when finished (last wizard page).

Uninstall removes NUMB and settings (`numb.ini`); it does not touch a separate system AutoHotkey install (this package does not require one).

## Option B — Copy `Install` + `number-ops`

Double-click **`Install NUMB.bat`** (or run the script below). No admin prompt.

```powershell
cd C:\WolfAi\NUMB\Install
.\Install-NUMB.ps1 -LaunchNow
.\Install-NUMB.ps1 -StartWithWindows -LaunchNow
```

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `-Dest` | `%LocalAppData%\WolfAi\NUMB` | Install directory |
| `-StartWithWindows` | **on** | Copy launcher into your Startup folder |
| `-NoStartWithWindows` | off | Skip Startup folder (overrides default) |
| `-LaunchNow` | off | Run `Start NUMB.bat` after copy |
| `-SkipAutoHotkey` | off | Do not copy portable `AutoHotkey64.exe` |
| `-InstallAutoHotkeySystem` | off | **Admin:** run `AutoHotkey_2.0.31_setup.exe` into Program Files (IT only) |

## IT / admin machines

If you prefer a shared system AutoHotkey instead of the portable copy:

```powershell
.\Install-NUMB.ps1 -InstallAutoHotkeySystem -SkipAutoHotkey
```

Or run `AutoHotkey_2.0.31_setup.exe` yourself, then install NUMB with `-SkipAutoHotkey`.

## After install

Run **`Start NUMB.bat`** from the install folder (or use the startup task). Tray **NUMB** — **Ctrl+Alt+Click** a numeric field in Ix.

**Reload** (tray menu) only works while NUMB is running. After **Exit**, run **`Start NUMB.bat`** again, use the **Start menu → NUMB** shortcut, or sign in again if logon startup was enabled.

## Refresh portable runtime

Replace **`portable\AutoHotkey64.exe`** from a newer official v2 **.zip** release (not the `.setup.exe`, which needs admin).

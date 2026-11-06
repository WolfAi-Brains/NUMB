# NUMB

In-place arithmetic for numeric fields in Windows apps (Ix first — modified AutoCAD).

**Ctrl+Alt+Click** a number → type `+56`, `-45`, `/2`, `*2`, or `(10+2)/2` → **Enter** → the result replaces the field.

## Run from this repo

```
C:\WolfAi\NUMB\number-ops\NUMB.ahk
```

## Setup (Windows)

### Installer (other machines)

Use **`Install\Install NUMB.bat`** or **`NUMB-Setup-2.1.0.exe`** — see **`Install\README.md`**. Installs to **`%LocalAppData%\WolfAi\NUMB`** with portable AutoHotkey v2.0.31; **no administrator** required.

### Manual (this repo)

1. Install [AutoHotkey v2](https://www.autohotkey.com/) (v2.0+, not v1), or run the installer above.
2. Double-click **`Start NUMB.bat`**, or right-click **`NUMB.ahk`** → **Run script**.
3. A tray icon labeled **NUMB** appears. Leave it running while you work in Ix.

**Tray menu:** **Reload** reloads the script (updates without Exit). **Exit** stops NUMB — there is no Reload after Exit; start it again (below).

### Start NUMB again after Exit

| Method | How |
|--------|-----|
| **Install folder** | Open `%LocalAppData%\WolfAi\NUMB` → double-click **`Start NUMB.bat`** (while NUMB is running: tray → **Open install folder**) |
| **Start menu** | **NUMB** shortcut (from the setup installer) |
| **Logon startup** | If install used “Start when Windows starts”, sign out/in or reboot |

Installed copies default to **`%LocalAppData%\WolfAi\NUMB`**. Optional dev copy to `C:\WolfAi\number-ops`: run **`Install-to-WolfAi.ps1`** (files only; use portable `AutoHotkey64.exe` or system AHK).

### Optional: start with Windows

```powershell
$bat = Join-Path $env:LOCALAPPDATA 'WolfAi\NUMB\Start NUMB.bat'
$startup = [Environment]::GetFolderPath('Startup')
Copy-Item $bat (Join-Path $startup 'Start NUMB.bat')
```

## Usage

| Action | Result |
|--------|--------|
| `Ctrl+Alt+Click` on `553.25` | Grabs value (clicks field if nothing selected), opens math popup |
| Type `+56` then Enter | Writes `609.25` |
| Type `-45` | `508.25` |
| Type `*2` or `/2` | Multiply / divide |
| Type `(10+2)/2` | Full expression (replaces with result) |
| Type `=32+54` | **Ignore** grabbed value; write `86` (Excel-style `=`) |
| Type `100` | Replace with bare number |
| Esc or empty Enter | Cancel, no change |

**Text case:** highlight the text → **Ctrl+Alt+Click** → pick an icon.

| Where | Apply |
|--------|--------|
| **Ix / AutoCAD / imos (MText)** | **A/a** → Ctrl+Shift+U/L; **Ab / Ab Cd** → paste over highlight only (no Ctrl+A) |
| **Other apps** (email, Word, …) | All icons paste transformed text; if the highlight was lost, NUMB merges into the field (Ctrl+A once on apply only) |

Pre-selection grab: **Ctrl+C** on the highlight outside CAD; in CAD **only in MText/editor** (avoids COPYCLIP on the drawing). **NoActivate** case popup when you pre-selected.

| Icon | Result |
|------|--------|
| **A** | ALL CAPS |
| **a** | lower case |
| **Ab** | First letter only (`Hello`) |
| **Ab Cd** | Title Case (`Hello World`) |

Invalid math expressions still beep and show a tray tip on Enter.

**AutoCAD Properties:** NUMB re-clicks the cell, pastes the result, and presses **Enter** to commit.

**Popup position:** opens to the **right** of the field by default. Drag the **NUMB** bar to reposition; offset is saved in `numb.ini`. If the popup used to open at the top of the whole Ix Properties panel, delete `numb.ini` once after updating. Drag: press and hold the top **NUMB** bar (label turns green).

## Ix tuning

If the wrong text is grabbed or write-back fails, open **`NUMB.ahk`** and raise these at the top:

```autohotkey
ClickDelayMs := 40   ; after click-to-focus
CopyDelayMs  := 80   ; field focus / select-all timing
SelectionClipWaitSec := 0.12   ; first Ctrl+C (keep low for fast numeric fields)
SelectionClipRetrySec := 0.38  ; second try after activate (case highlight)
FieldClipWaitSec := 0.28       ; read whole numeric cell
WriteDelayMs := 40   ; before typing the result
```

Try `80` / `120` / `80` if Ix is slow to select or accept paste.

## Notes

- Works in any app where the field supports **Select All + Copy** and typing.
- Your clipboard is restored after the grab.
- Only `0-9 . + - * / ( )` are allowed in expressions (no script injection).
- Tray menu: **Reload** / **Exit**.

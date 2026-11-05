# NUMB

In-place arithmetic for numeric fields in Windows apps (Ix first — modified AutoCAD).

**Ctrl+Shift+Click** a number → type `+56`, `-45`, `/2`, `*2`, or `(10+2)/2` → **Enter** → the result replaces the field.

## Run from this repo

```
C:\WolfAi\NUMB\number-ops\NUMB.ahk
```

## Setup (Windows)

### Installer (other machines)

Use **`Install\Install NUMB.bat`** or **`NUMB-Setup-1.4.6.exe`** — see **`Install\README.md`**. Installs to **`%LocalAppData%\WolfAi\NUMB`** with portable AutoHotkey v2.0.31; **no administrator** required.

### Manual (this repo)

1. Install [AutoHotkey v2](https://www.autohotkey.com/) (v2.0+, not v1), or run the installer above.
2. Double-click **`Start NUMB.bat`**, or right-click **`NUMB.ahk`** → **Run script**.
3. A tray icon labeled **NUMB** appears. Leave it running while you work in Ix.

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
| `Ctrl+Shift+Click` on `553.25` | Grabs value (clicks field if nothing selected), opens math popup |
| Type `+56` then Enter | Writes `609.25` |
| Type `-45` | `508.25` |
| Type `*2` or `/2` | Multiply / divide |
| Type `(10+2)/2` | Full expression (replaces with result) |
| Type `100` | Replace with bare number |
| Esc or empty Enter | Cancel, no change |

**Text case:** highlight **only** the characters to change (not the whole paragraph) → **Ctrl+Shift+Click** → pick an icon. Apply uses **Ctrl+Shift+U/L** (A/a) or **paste over the highlight only** — **no Ctrl+A** on apply. Keep the popup open briefly; clicking an icon returns focus to the editor first.

| Icon | Result |
|------|--------|
| **A** | ALL CAPS |
| **a** | lower case |
| **Ab** | First letter only (`Hello`) |
| **Ab Cd** | Title Case (`Hello World`) |

Invalid math expressions still beep and show a tray tip on Enter.

**AutoCAD Properties** (native palette): NUMB re-clicks the cell, pastes the result, and presses **Enter** to commit. If a value still does not stick, raise `WriteDelayMs` / `ClickDelayMs` at the top of `NUMB.ahk`.

**Popup position:** opens to the **right** of the field by default. Drag the **NUMB** bar to reposition; offset is saved in `numb.ini`. If the popup used to open at the top of the whole Ix Properties panel, delete `numb.ini` once after updating. Drag: press and hold the top **NUMB** bar (label turns green).

## Ix tuning

If the wrong text is grabbed or write-back fails, open **`NUMB.ahk`** and raise these at the top:

```autohotkey
ClickDelayMs := 40   ; after click-to-focus
CopyDelayMs  := 80   ; before/around Ctrl+A / Ctrl+C
WriteDelayMs := 40   ; before typing the result
```

Try `80` / `120` / `80` if Ix is slow to select or accept paste.

## Notes

- Works in any app where the field supports **Select All + Copy** and typing.
- Your clipboard is restored after the grab.
- Only `0-9 . + - * / ( )` are allowed in expressions (no script injection).
- Tray menu: **Reload** / **Exit**.

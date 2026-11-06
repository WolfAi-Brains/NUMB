#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

CoordMode "Mouse", "Screen"

; =============================================================================
; NUMB — in-place arithmetic on numeric fields; case conversion on text
; Hotkey: Ctrl+Shift+Click — text: select first, then click; numbers: click field (or select)
; Install path (Windows): C:\WolfAi\NUMB\number-ops\NUMB.ahk
; =============================================================================

APP_VERSION := "2.0.0"

; --- Tunables (raise delays if Ix is slow to focus/select) -------------------
ClickDelayMs := 40
CopyDelayMs := 80
WriteDelayMs := 40
SelectionClipWaitSec := 0.12   ; first try — empty numeric fields must not sit here long
SelectionClipRetrySec := 0.38  ; after activate, for slow MText / case highlight
FieldClipWaitSec := 0.28       ; Ctrl+A / Ctrl+C on a numeric cell
WmCopyProbeWaitSec := 0.06     ; quick WM_COPY attempts (fail fast)
; AutoCAD / native Properties palette: refocus cell and Enter to commit
CommitEnterAfterWrite := true
CommitEnterAfterCaseWrite := false
ReclickFieldBeforeWrite := true
UseClipboardPasteForWrite := true
PopupWidth := 148
CasePopupWidth := 268
PopupOffsetX := 2
PopupOffsetY := 2
PopupEstHeight := 42
dragZoneH := 48
maxFieldW := 320
maxFieldH := 48

; --- Tray -------------------------------------------------------------------
TraySetIcon(A_ScriptDir "\numb.ico")
A_TrayMenu.Delete()
A_TrayMenu.Add("NUMB v" APP_VERSION, (*) => 0)
A_TrayMenu.Disable("NUMB v" APP_VERSION)
A_TrayMenu.Add()
A_TrayMenu.Add("About", (*) => ShowAbout())
A_TrayMenu.Add("Open install folder", (*) => NumbOpenInstallFolder())
A_TrayMenu.Add()
A_TrayMenu.Add("Reload", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Reload"

; --- State ------------------------------------------------------------------
baseValue := 0.0
opsGui := 0
editHwnd := 0
targetWin := 0
fieldClickX := 0
fieldClickY := 0
busy := false
fieldRectLeft := 0
fieldRectTop := 0
fieldRectRight := 0
fieldRectBottom := 0
dragLabelCtrl := 0
dragActive := false
dragGrabX := 0
dragGrabY := 0
settingsPath := A_ScriptDir "\numb.ini"
savedPopupCustom := false
savedRelX := 0.0
savedRelY := 0.0
useCount := 0
suppressOutsideDismiss := false
popupMode := ""
caseSourceText := ""
casePreviewCtrl := 0
caseIconEntries := []
caseHoverActive := ""
caseFromPreSelection := false
caseFullText := ""
caseSelectionNeedle := ""
caseUseNativeCad := false
caseSourceRaw := ""

LoadUseCount()
UpdateTrayTip()
OnMessage(0x201, NumbGlobalLDown, 2)
OnMessage(0x202, NumbGlobalLUp, 2)

; --- Hotkey: Ctrl+Shift+Left click ------------------------------------------
^+LButton:: {
    global busy
    if busy
        return
    busy := true
    try
        StartNumberOp()
    catch as err
        Tip("NUMB error: " err.Message)
    finally
        busy := false
}

StartNumberOp() {
    global ClickDelayMs, CopyDelayMs, baseValue, targetWin, fieldClickX, fieldClickY
    global caseSourceText, caseFromPreSelection

    MouseGetPos(&anchorX, &anchorY)
    fieldClickX := anchorX
    fieldClickY := anchorY
    targetWin := WinExist("A")
    cadHost := IsCopyClipUnsafeHost(targetWin)

    ; =================================================================
    ; LOCKED — imos / Ix / AutoCAD routing (v1.8.5+). Do not change.
    ; Properties → NumbNumericGrabProperties | else → NumbRunCaseOp only
    ; =================================================================
    if cadHost {
        if NumbCadIsPropertiesPaletteContext(targetWin, anchorX, anchorY) {
            raw := NumbNumericGrabProperties(anchorX, anchorY)
            if (raw = "") {
                Tip("Click a number field in Properties.")
                return
            }
            if (IsTextForCase(raw)) {
                Tip("Highlight the words to change, then Ctrl+Shift+Click on the highlight.")
                return
            }
            if !NumbRouteGrabbedContent(raw, anchorX, anchorY, false)
                Tip("No number found: " . Trunc(raw, 40))
            return
        }
        NumbRunCaseOp(anchorX, anchorY, true)
        return
    }

    ; --- Outside CAD: case from highlight, else numeric click ---
    raw := NumbCaseGrabOutside(SelectionClipWaitSec)
    if (Trim(raw) = "" && targetWin) {
        try WinActivate("ahk_id " targetWin)
        Sleep(CopyDelayMs // 3)
        targetWin := WinExist("A")
        raw := NumbCaseGrabOutside(SelectionClipRetrySec)
    }
    if (Trim(raw) != "") {
        if NumbRouteGrabbedContent(raw, anchorX, anchorY, true)
            return
        Tip("No number or text found: " . Trunc(Trim(raw), 40))
        return
    }

    raw := NumbNumericGrabOutside()
    if (raw = "") {
        Tip("Click a number field (or highlight text first for case).")
        return
    }
    if (IsTextForCase(raw)) {
        Tip("Highlight the words to change, then Ctrl+Shift+Click on the highlight.")
        return
    }
    if !NumbRouteGrabbedContent(raw, anchorX, anchorY, false)
        Tip("No number found: " . Trunc(raw, 40))
}

; MText / in-place editor — never run numeric grab here. Properties palette is always numeric.
NumbCadIsCaseContext(hwnd, x, y) {
    if !IsCopyClipUnsafeHost(hwnd)
        return false
    if NumbCadIsPropertiesPaletteContext(hwnd, x, y)
        return false
    if IsCadInPlaceTextEditor(hwnd)
        return true
    if NumbCadMTextHasActiveSelection(hwnd, x, y)
        return true
    if NumbCadTextSurfaceAtPoint(x, y)
        return true
    return false
}

; MText / editor click on CAD — case only (never the numeric Ctrl+A path).
NumbCadMustUseCasePath(hwnd, x, y) {
    if !IsCopyClipUnsafeHost(hwnd)
        return false
    if NumbCadIsPropertiesPaletteContext(hwnd, x, y)
        return false
    if NumbCadIsCaseContext(hwnd, x, y)
        return true
    h := NumbHwndAtPoint(x, y)
    loop 16 {
        if !h
            break
        if NumbCadIsMtextOrRichEditHwnd(h) || NumbIsMultilineEditHwnd(h)
            return true
        h := DllCall("GetParent", "Ptr", h, "Ptr")
    }
    return false
}

NumbCadIsPropertiesPaletteContext(hwnd, x, y) {
    if !IsCopyClipUnsafeHost(hwnd)
        return false
    h := NumbHwndAtPoint(x, y)
    loop 24 {
        if !h
            break
        try {
            title := WinGetTitle("ahk_id " h)
            if RegExMatch(title, "i)propert|properties|eigenschaft|palette")
                return true
        } catch {
        }
        cls := NumbHwndClassName(h)
        if RegExMatch(cls, "i)Property|PropGrid|GridControl|Spread|Inspector")
            return true
        h := DllCall("GetParent", "Ptr", h, "Ptr")
    }
    try {
        if RegExMatch(WinGetTitle("ahk_id " hwnd), "i)propert|properties|eigenschaft")
            return true
    } catch {
    }
    return false
}

NumbCadSafeForGlobalFieldSelectCopy(hwnd) {
    global fieldClickX, fieldClickY
    if NumbCadIsCaseContext(hwnd, fieldClickX, fieldClickY)
        return false
    if NumbCadIsPropertiesPaletteContext(hwnd, fieldClickX, fieldClickY)
        return true
    fh := NumbGetGuiThreadFocusHwnd(hwnd)
    if NumbCadIsMtextOrRichEditHwnd(fh) || NumbIsMultilineEditHwnd(fh)
        return false
    if NumbHwndSelectionSpan(fh) > 80
        return false
    return true
}

NumbCopyFocusedFieldCadLegacy(clipWaitSec) {
    global CopyDelayMs, targetWin, fieldClickX, fieldClickY
    if !NumbCadIsPropertiesPaletteContext(targetWin, fieldClickX, fieldClickY)
        return ""
    clipSaved := ClipboardAll()
    A_Clipboard := ""
    Send("^a")
    Sleep(Max(12, CopyDelayMs // 4))
    Send("^c")
    if !ClipWait(clipWaitSec) {
        A_Clipboard := clipSaved
        return ""
    }
    raw := Trim(A_Clipboard)
    A_Clipboard := clipSaved
    return raw
}

NumbRunCaseOp(anchorX, anchorY, cadHost) {
    raw := NumbCaseGrabCad(SelectionClipWaitSec)
    if (Trim(raw) = "")
        raw := NumbCaseGrabCad(SelectionClipRetrySec)
    if (Trim(raw) != "") {
        if NumbRouteGrabbedContent(raw, anchorX, anchorY, true)
            return
        Tip("No number or text found: " . Trunc(Trim(raw), 40))
        return
    }
    Tip("Highlight the words to change, then Ctrl+Shift+Click on the highlight.")
}

NumbCaseGrabOutside(waitSec) {
    return TryCopySelection(waitSec)
}

NumbFindMtextEditHwnd(hwnd, x, y) {
    try {
        ctrl := ControlGetFocus("ahk_id " hwnd)
        if RegExMatch(ctrl, "i)RichEdit|RICHEDIT|Scintilla") {
            reHwnd := ControlGetHwnd(ctrl, "ahk_id " hwnd)
            if reHwnd
                return reHwnd
        }
    } catch {
    }
    for candidate in [NumbGetGuiThreadFocusHwnd(hwnd), NumbHwndAtPoint(x, y)] {
        h := candidate
        loop 22 {
            if !h
                break
            if NumbCadIsMtextOrRichEditHwnd(h) || NumbIsMultilineEditHwnd(h)
                return h
            h := DllCall("GetParent", "Ptr", h, "Ptr")
        }
    }
    return 0
}

NumbCaseGrabCad(waitSec) {
    global SelectionClipRetrySec
    raw := TryCopySelection(waitSec)
    if (Trim(raw) != "" && IsTextForCase(raw))
        return raw
    raw := TryCopyCadMTextSelectionGrab(waitSec)
    if (Trim(raw) != "")
        return raw
    long := Max(waitSec, SelectionClipRetrySec)
    raw := TryCopySelection(long)
    if (Trim(raw) != "" && IsTextForCase(raw))
        return raw
    return TryCopyCadMTextSelectionGrab(long)
}

NumbRawLooksNumeric(raw) {
    raw := Trim(raw)
    if (raw = "")
        return false
    if (ParseNumber(raw) != "")
        return true
    return RegExMatch(raw, "^[\d\s.,+\-eE]+$")
}

; =============================================================================
; LOCKED — iX Properties numeric only (v1.8.4: no bare Ctrl+C — avoids COPYCLIP).
; =============================================================================
NumbNumericGrabProperties(anchorX, anchorY) {
    global targetWin, ClickDelayMs, CopyDelayMs, FieldClipWaitSec, WmCopyProbeWaitSec
    global caseFromPreSelection, caseFullText, caseSelectionNeedle
    caseFromPreSelection := false
    caseFullText := ""
    caseSelectionNeedle := ""
    if targetWin {
        try WinActivate("ahk_id " targetWin)
        Sleep(CopyDelayMs // 4)
    }
    Click("Left")
    Sleep(ClickDelayMs // 2)
    targetWin := WinExist("A")
    raw := NumbTryCopyCadPropertyFromChain(NumbGetGuiThreadFocusHwnd(targetWin), WmCopyProbeWaitSec)
    if (raw != "")
        return raw
    raw := NumbTryCopyCadPropertyFromChain(NumbHwndAtPoint(anchorX, anchorY), WmCopyProbeWaitSec)
    if (raw != "")
        return raw
    return NumbCopyFocusedFieldCadLegacy(FieldClipWaitSec)
}

NumbNumericGrabCad(anchorX, anchorY) {
    global targetWin, ClickDelayMs, CopyDelayMs, caseFromPreSelection, caseFullText, caseSelectionNeedle
    global FieldClipWaitSec, WmCopyProbeWaitSec
    caseFromPreSelection := false
    caseFullText := ""
    caseSelectionNeedle := ""
    if NumbCadIsCaseContext(targetWin, anchorX, anchorY)
        return ""
    if NumbCadIsPropertiesPaletteContext(targetWin, anchorX, anchorY)
        return NumbNumericGrabProperties(anchorX, anchorY)
    probe := WmCopyProbeWaitSec
    if targetWin {
        try WinActivate("ahk_id " targetWin)
        Sleep(CopyDelayMs // 3)
    }
    Click("Left")
    Sleep(ClickDelayMs // 2)
    targetWin := WinExist("A")
    raw := TryCopyCadNumericAtClickPoint(anchorX, anchorY, probe)
    if (raw != "")
        return raw
    raw := NumbTryCopyCadPropertyFromChain(NumbGetGuiThreadFocusHwnd(targetWin), probe)
    if (raw != "")
        return raw
    if NumbCadSafeForGlobalFieldSelectCopy(targetWin)
        return NumbCopyFocusedFieldCadLegacy(FieldClipWaitSec)
    return ""
}

NumbNumericGrabOutside() {
    global targetWin, ClickDelayMs, CopyDelayMs, caseFromPreSelection, caseFullText, caseSelectionNeedle
    caseFromPreSelection := false
    caseFullText := ""
    caseSelectionNeedle := ""
    if targetWin {
        try WinActivate("ahk_id " targetWin)
        Sleep(CopyDelayMs // 3)
    }
    Click("Left")
    Sleep(ClickDelayMs // 2)
    targetWin := WinExist("A")
    return TryCopyFieldAllOutside()
}

NumbRouteGrabbedContent(raw, anchorX, anchorY, fromPreSelection) {
    global baseValue, caseSourceText, caseFromPreSelection, caseFullText, caseSelectionNeedle
    global caseSourceRaw, targetWin
    if (IsTextForCase(raw)) {
        caseSourceRaw := raw
        caseSourceText := SanitizeGrabbedText(raw)
        caseFromPreSelection := fromPreSelection
        caseFullText := ""
        caseSelectionNeedle := ""
        ShowCasePopup(anchorX, anchorY)
        return true
    }
    parsed := ParseNumber(raw)
    if (parsed != "") {
        baseValue := parsed
        caseFromPreSelection := false
        caseFullText := ""
        caseSelectionNeedle := ""
        ShowOpsPopup(anchorX, anchorY)
        return true
    }
    return false
}

; imos, AutoCAD, Ix — Ctrl+C on the drawing starts COPYCLIP (not used for case grab there).
IsCopyClipUnsafeHost(hwnd) {
    if !hwnd
        return false
    try {
        exe := StrLower(WinGetProcessName("ahk_id " hwnd))
        title := StrLower(WinGetTitle("ahk_id " hwnd))
    } catch {
        return false
    }
    for needle in ["acad", "autocad", "icad", "intellicad", "bricscad", "zwcad", "gcad", "progecad", "cms", "ix", "imos"] {
        if InStr(exe, needle)
            return true
    }
    if RegExMatch(title, "i)autocad|autodesk|\bix\b|imos|drawing editor|bricscad|intellicad")
        return true
    return false
}

IsTextInputControlClass(className) {
    if (className = "")
        return false
    if RegExMatch(className, "i)^RichEdit|^RICHEDIT|Scintilla|TXTextControl")
        return true
    return false
}

NumbClassNnToClassName(classNn) {
    if (classNn = "")
        return ""
    return RegExReplace(classNn, "\d+$", "")
}

NumbGetGuiThreadFocusHwnd(hwnd := 0) {
    if !hwnd
        hwnd := WinExist("A")
    if !hwnd
        return 0
    ti := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    buf := Buffer(72, 0)
    NumPut("UInt", 72, buf, 0)
    if !DllCall("GetGUIThreadInfo", "UInt", ti, "Ptr", buf)
        return 0
    return NumGet(buf, 16, "Ptr")
}

NumbHwndClassName(hwnd) {
    if !hwnd
        return ""
    buf := Buffer(512, 0)
    n := DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    return n ? StrGet(buf, "UTF-16") : ""
}

NumbHwndAtPoint(x, y) {
    pt := Buffer(8, 0)
    NumPut("Int", x, pt, 0)
    NumPut("Int", y, pt, 4)
    return DllCall("WindowFromPoint", "Int64", NumGet(pt, 0, "Int64"), "Ptr")
}

NumbIsMultilineEditHwnd(hwnd) {
    cls := NumbHwndClassName(hwnd)
    if !RegExMatch(cls, "i)^Edit\d*$")
        return false
    rect := Buffer(16, 0)
    if !DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rect)
        return false
    return NumGet(rect, 12, "Int") > 48
}

NumbCadTextSurfaceOnHwndChain(hwnd) {
    loop 18 {
        if !hwnd
            break
        cls := NumbHwndClassName(hwnd)
        if IsTextInputControlClass(cls) || NumbIsMultilineEditHwnd(hwnd)
            return true
        try {
            title := WinGetTitle("ahk_id " hwnd)
            if RegExMatch(title, "i)mtext|multiline|text editor|in-place|inplace|text edit|annotation")
                return true
        } catch {
        }
        hwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    }
    return false
}

; Ctrl+Shift+Click over the MText canvas (not Properties single-line cells).
NumbCadTextSurfaceAtPoint(x, y) {
    if !IsCopyClipUnsafeHost(WinExist("A"))
        return false
    return NumbCadTextSurfaceOnHwndChain(NumbHwndAtPoint(x, y))
}

; True only when click is on a single-line property Edit (not MText / drawing).
NumbCadLikelyPropertyNumericClick(x, y) {
    if !IsCopyClipUnsafeHost(WinExist("A"))
        return false
    hwnd := NumbHwndAtPoint(x, y)
    loop 22 {
        if !hwnd
            break
        if NumbCadIsMtextOrRichEditHwnd(hwnd)
            return false
        if NumbIsMultilineEditHwnd(hwnd)
            return false
        cls := NumbHwndClassName(hwnd)
        if RegExMatch(cls, "i)^Edit")
            return true
        hwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    }
    return false
}

NumbCadBlockNumericGrab(hwnd, x, y) {
    if !IsCopyClipUnsafeHost(hwnd)
        return false
    if NumbCadLikelyPropertyNumericClick(x, y)
        return false
    return true
}

NumbHwndHasTextSelection(hwnd) {
    if !hwnd
        return false
    span := NumbHwndSelectionSpan(hwnd)
    return span > 0 && span < 500000
}

NumbHwndSelectionSpan(hwnd) {
    if !hwnd
        return 0
    try {
        packed := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0xB0, "Ptr", 0, "Ptr", 0, "Ptr")
        if (packed != -1) {
            start := packed & 0xFFFF
            end := (packed >> 16) & 0xFFFF
            if (end > start)
                return end - start
        }
    } catch {
    }
    try {
        chrg := Buffer(8, 0)
        DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x043B, "Ptr", 0, "Ptr", chrg, "Ptr")
        end := NumGet(chrg, 4, "Int")
        start := NumGet(chrg, 0, "Int")
        if (end > start)
            return end - start
    } catch {
    }
    return 0
}

NumbFindHwndWithSelection(hwnd, x, y) {
    for candidate in [NumbGetGuiThreadFocusHwnd(hwnd), NumbHwndAtPoint(x, y)] {
        h := candidate
        loop 22 {
            if !h
                break
            if NumbHwndHasTextSelection(h)
                return h
            h := DllCall("GetParent", "Ptr", h, "Ptr")
        }
    }
    return 0
}

NumbCadMTextHasActiveSelection(hwnd := 0, x := 0, y := 0) {
    if !IsCopyClipUnsafeHost(hwnd ? hwnd : WinExist("A"))
        return false
    return NumbFindHwndWithSelection(hwnd, x, y) != 0
}

TryCopyCadMTextSelectionGrab(waitSec) {
    global targetWin, fieldClickX, fieldClickY
    win := targetWin ? targetWin : WinExist("A")
    selHwnd := NumbFindHwndWithSelection(win, fieldClickX, fieldClickY)
    if !selHwnd
        selHwnd := NumbFindMtextEditHwnd(win, fieldClickX, fieldClickY)
    if !selHwnd
        return ""
    raw := TryCopyWmCopyHwnd(selHwnd, waitSec)
    if (Trim(raw) != "")
        return raw
    return TryCopyWmCopyHwnd(selHwnd, Max(waitSec, 0.35))
}

NumbCadIsMtextOrRichEditHwnd(hwnd) {
    if !hwnd
        return false
    cls := NumbHwndClassName(hwnd)
    if IsTextInputControlClass(cls) || NumbIsMultilineEditHwnd(hwnd)
        return true
    return false
}

NumbCopyAllFromEditHwnd(hwnd, clipWaitSec) {
    if NumbCadIsMtextOrRichEditHwnd(hwnd)
        return ""
    cls := NumbHwndClassName(hwnd)
    if !RegExMatch(cls, "i)^Edit")
        return ""
    if NumbIsMultilineEditHwnd(hwnd)
        return ""
    clipSaved := ClipboardAll()
    A_Clipboard := ""
    DllCall("SendMessage", "Ptr", hwnd, "UInt", 0xB1, "Ptr", 0, "Ptr", -1, "Ptr") ; EM_SETSEL all — this control only
    DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x301, "Ptr", 0, "Ptr", 0, "Ptr")
    if !ClipWait(clipWaitSec) {
        A_Clipboard := clipSaved
        return ""
    }
    raw := Trim(A_Clipboard)
    A_Clipboard := clipSaved
    return raw
}

NumbTryCopyCadPropertyFromChain(startHwnd, clipWaitSec) {
    hwnd := startHwnd
    loop 10 {
        if !hwnd
            break
        if NumbCadIsMtextOrRichEditHwnd(hwnd) || NumbIsMultilineEditHwnd(hwnd) {
            hwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
            continue
        }
        cls := NumbHwndClassName(hwnd)
        if RegExMatch(cls, "i)^Edit") {
            raw := NumbCopyAllFromEditHwnd(hwnd, clipWaitSec)
            if (raw != "")
                return raw
        }
        raw := Trim(TryCopyWmCopyHwnd(hwnd, clipWaitSec))
        if (raw != "" && ParseNumber(raw) != "")
            return raw
        if (raw != "" && !RegExMatch(raw, "[A-Za-z]{4,}"))
            return raw
        hwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    }
    return ""
}

TryCopyCadNumericAtClickPoint(x, y, clipWaitSec) {
    global targetWin, FieldClipWaitSec
    if (clipWaitSec = "")
        clipWaitSec := FieldClipWaitSec
    raw := NumbTryCopyCadPropertyFromChain(NumbHwndAtPoint(x, y), clipWaitSec)
    if (raw != "")
        return raw
    return NumbTryCopyCadPropertyFromChain(NumbGetGuiThreadFocusHwnd(targetWin), clipWaitSec)
}

TryCopyWmCopyHwnd(hwnd, clipWaitSec := 0.12) {
    if !hwnd
        return ""
    clipSaved := ClipboardAll()
    A_Clipboard := ""
    try DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x301, "Ptr", 0, "Ptr", 0, "Ptr") ; WM_COPY
    if !ClipWait(clipWaitSec) {
        A_Clipboard := clipSaved
        return ""
    }
    raw := A_Clipboard
    A_Clipboard := clipSaved
    return raw
}

TryCopyWmCopyFromPointChain(x, y, clipWaitSec := 0.12) {
    global WmCopyProbeWaitSec
    if (clipWaitSec = 0.12)
        clipWaitSec := WmCopyProbeWaitSec
    hwnd := NumbHwndAtPoint(x, y)
    loop 10 {
        if !hwnd
            break
        raw := TryCopyWmCopyHwnd(hwnd, clipWaitSec)
        if (Trim(raw) != "")
            return raw
        hwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    }
    return ""
}

NumbGetCadFocusTextClass(hwnd := 0) {
    if !hwnd
        hwnd := WinExist("A")
    cls := NumbHwndClassName(NumbGetGuiThreadFocusHwnd(hwnd))
    if IsTextInputControlClass(cls)
        return cls
    cls := NumbGetFocusedControlClass(hwnd)
    if IsTextInputControlClass(cls)
        return cls
    return cls
}

; RichEdit / MText caret — do not run numeric click+Ctrl+A here.
NumbCadBlockNumericForTextFocus(hwnd := 0) {
    if !hwnd
        hwnd := WinExist("A")
    if !IsCopyClipUnsafeHost(hwnd)
        return false
    if IsCadInPlaceTextEditor(hwnd)
        return true
    cls := NumbGetCadFocusTextClass(hwnd)
    return IsTextInputControlClass(cls)
}

NumbCadSafeForSelectionCopy(hwnd := 0) {
    if !hwnd
        hwnd := WinExist("A")
    global fieldClickX, fieldClickY
    if NumbCadTextSurfaceAtPoint(fieldClickX, fieldClickY)
        return true
    if !IsCopyClipUnsafeHost(hwnd)
        return true
    if IsCadInPlaceTextEditor(hwnd)
        return true
    if IsTextInputControlClass(NumbGetCadFocusTextClass(hwnd))
        return true
    return false
}

; MText / in-place note editor in imos, AutoCAD, Ix — Ctrl+C is selection copy, not COPYCLIP.
IsCadInPlaceTextEditor(hwnd := 0) {
    if !hwnd
        hwnd := WinExist("A")
    if !hwnd
        return false
    if !IsCopyClipUnsafeHost(hwnd)
        return false
    try {
        title := WinGetTitle("ahk_id " hwnd)
        if RegExMatch(title, "i)mtext|multiline|text editor|in-place|inplace|text edit|annotation|notiz|beschreibung")
            return true
    } catch {
    }
    cls := NumbGetCadFocusTextClass(hwnd)
    if IsTextInputControlClass(cls)
        return true
    try {
        ctrl := ControlGetFocus("ahk_id " hwnd)
        if RegExMatch(ctrl, "i)RichEdit|RICHEDIT|Scintilla")
            return true
    } catch {
    }
    return false
}

NumbGetFocusedControlClass(hwnd) {
    if !hwnd
        return ""
    try {
        ctrl := ControlGetFocus("ahk_id " hwnd)
        return NumbClassNnToClassName(ctrl)
    } catch {
        return ""
    }
}

; Pre-selection: Ctrl+C outside CAD; in CAD use WM_COPY first, then Ctrl+C only in text focus.
TryCopyPreSelectionGrab(waitSec) {
    global targetWin, fieldClickX, fieldClickY
    win := targetWin ? targetWin : WinExist("A")
    if !IsCopyClipUnsafeHost(win)
        return TryCopySelection(waitSec)
    if NumbCadLikelyPropertyNumericClick(fieldClickX, fieldClickY)
        return ""
    raw := TryCopySelection(waitSec)
    if (Trim(raw) != "")
        return raw
    raw := TryCopyCadMTextSelectionGrab(waitSec)
    if (Trim(raw) != "")
        return raw
    raw := TryCopyWmCopyFromPointChain(fieldClickX, fieldClickY, waitSec)
    if (Trim(raw) != "")
        return raw
    raw := TryCopySelectionViaWmCopy(win, waitSec)
    if (Trim(raw) != "")
        return raw
    return TryCopySelection(Max(waitSec, 0.38))
}

TryCopySelectionViaWmCopy(hwnd, clipWaitSec := 0.12) {
    clipSaved := ClipboardAll()
    A_Clipboard := ""
    sent := false
    focusHwnd := NumbGetGuiThreadFocusHwnd(hwnd)
    if focusHwnd {
        try {
            DllCall("SendMessage", "Ptr", focusHwnd, "UInt", 0x301, "Ptr", 0, "Ptr", 0, "Ptr")
            sent := true
        } catch {
        }
    }
    if !sent {
        try {
            ctrl := ControlGetFocus("ahk_id " hwnd)
            if (ctrl = "") {
                A_Clipboard := clipSaved
                return ""
            }
            SendMessage(0x301, 0, 0, ctrl, "ahk_id " hwnd)
        } catch {
            A_Clipboard := clipSaved
            return ""
        }
    }
    if !ClipWait(clipWaitSec) {
        A_Clipboard := clipSaved
        return ""
    }
    raw := A_Clipboard
    A_Clipboard := clipSaved
    return raw
}

; imos / CAD: targeted read only (no global Ctrl+A). Other apps: normal field read.
TryCopyFieldAllOutside() {
    global CopyDelayMs, FieldClipWaitSec
    clipSaved := ClipboardAll()
    A_Clipboard := ""
    Send("^a")
    Sleep(Max(12, CopyDelayMs // 4))
    Send("^c")
    if !ClipWait(FieldClipWaitSec) {
        A_Clipboard := clipSaved
        return ""
    }
    raw := Trim(A_Clipboard)
    A_Clipboard := clipSaved
    return raw
}

TryCopyFieldAll() {
    global targetWin, fieldClickX, fieldClickY, FieldClipWaitSec
    if IsCopyClipUnsafeHost(targetWin)
        return TryCopyCadNumericAtClickPoint(fieldClickX, fieldClickY, FieldClipWaitSec)
    return TryCopyFieldAllOutside()
}

TryCopySelection(clipWaitSec := 0.12) {
    clipSaved := ClipboardAll()
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(clipWaitSec) {
        A_Clipboard := clipSaved
        return ""
    }
    raw := A_Clipboard
    A_Clipboard := clipSaved
    return raw
}

ApplyCaseToSelectionOnly(mode) {
    global targetWin
    if IsCopyClipUnsafeHost(targetWin)
        ApplyCaseCadIx(mode)
    else
        ApplyCaseOutsideHost(mode)
}

ApplyCaseCadIx(mode) {
    ; LOCKED — CAD / Ix / imos MText case apply (selection only). Do not change.
    global targetWin, WriteDelayMs, caseSourceText
    if targetWin {
        try WinActivate("ahk_id " targetWin)
        Sleep(WriteDelayMs)
    }
    if (mode = "upper") {
        Send("^+u")
        return
    }
    if (mode = "lower") {
        Send("^+l")
        return
    }
    newSel := TransformCase(caseSourceText, mode)
    clipSaved := ClipboardAll()
    A_Clipboard := newSel
    if !ClipWait(0.35) {
        A_Clipboard := clipSaved
        Tip("Could not paste over selection.")
        return
    }
    Send("^v")
    Sleep(WriteDelayMs // 2)
    A_Clipboard := clipSaved
}

; Outside CAD/Ix case only — ClipWait must not require "changed" (lower/title often match prior copy).
NumbCaseOutsidePasteText(newSel) {
    global WriteDelayMs
    if (Trim(newSel) = "")
        return false
    clipSaved := ClipboardAll()
    A_Clipboard := newSel
    if !ClipWait(0.5, 0) {
        A_Clipboard := clipSaved
        return false
    }
    Send("^v")
    Sleep(WriteDelayMs // 2)
    A_Clipboard := clipSaved
    return true
}

ApplyCaseOutsideHost(mode) {
    global targetWin, WriteDelayMs, caseSourceText, caseFromPreSelection
    if (Trim(caseSourceText) = "") {
        Tip("Nothing to apply.")
        return
    }
    newSel := TransformCase(caseSourceText, mode)
    if (Trim(newSel) = "") {
        Tip("Nothing to apply.")
        return
    }
    if targetWin {
        try WinActivate("ahk_id " targetWin)
        Sleep(WriteDelayMs)
    }
    if caseFromPreSelection && TryPasteCaseWithoutRecopy(newSel)
        return
    if TryPasteCaseOverSelection(newSel)
        return
    ApplyCaseMergedFieldReplace(newSel)
}

TryPasteCaseWithoutRecopy(newSel) {
    return NumbCaseOutsidePasteText(newSel)
}

CaseSelectionMatchesGrabbed(clipText) {
    global caseSourceText, caseSourceRaw
    clipText := SanitizeGrabbedText(clipText)
    if (clipText = "")
        return false
    for src in [caseSourceText, caseSourceRaw, SanitizeGrabbedText(caseSourceRaw)] {
        if (src = "")
            continue
        if (clipText = src)
            return true
        if (StrLower(clipText) = StrLower(src))
            return true
    }
    return false
}

TryReadActiveSelection(&text) {
    global SelectionClipWaitSec
    clipSaved := ClipboardAll()
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(SelectionClipWaitSec) {
        A_Clipboard := clipSaved
        return false
    }
    text := A_Clipboard
    A_Clipboard := clipSaved
    return true
}

TryPasteCaseOverSelection(newSel) {
    global WriteDelayMs
    if (Trim(newSel) = "")
        return false
    sel := ""
    if !TryReadActiveSelection(&sel)
        return false
    if !CaseSelectionMatchesGrabbed(sel)
        return false
    return NumbCaseOutsidePasteText(newSel)
}

ApplyCaseMergedFieldReplace(newSel) {
    global WriteDelayMs, CopyDelayMs, FieldClipWaitSec, caseSourceText, caseSourceRaw
    if (Trim(newSel) = "") {
        Tip("Nothing to apply.")
        return
    }
    clipSaved := ClipboardAll()
    A_Clipboard := ""
    Send("^a")
    Sleep(Max(12, CopyDelayMs // 4))
    Send("^c")
    if !ClipWait(FieldClipWaitSec) {
        A_Clipboard := clipSaved
        Tip("Could not read the field to apply case.")
        return
    }
    full := SanitizeGrabbedText(A_Clipboard)
    out := MergeCaseIntoFullText(full, newSel, &errMsg)
    if (out = "") {
        A_Clipboard := clipSaved
        Tip(errMsg != "" ? errMsg : "Could not apply case to this text.")
        return
    }
    A_Clipboard := out
    if !ClipWait(0.5, 0) {
        A_Clipboard := clipSaved
        Tip("Could not paste updated text.")
        return
    }
    Send("^a")
    Sleep(WriteDelayMs)
    Send("^v")
    Sleep(WriteDelayMs // 2)
    A_Clipboard := clipSaved
}

MergeCaseIntoFullText(full, newSel, &errMsg) {
    global caseSourceText, caseSourceRaw
    errMsg := ""
    if (full = "")
        return ""
    if (caseSourceText = "" && caseSourceRaw = "")
        return ""
    if (full = caseSourceText || (caseSourceRaw != "" && full = caseSourceRaw))
        return newSel
    needle := ResolveSelectionNeedle(full, caseSourceRaw, caseSourceText)
    if (needle = "") {
        errMsg := 'Could not find "' . Trunc(caseSourceText, 36) . '" in the text.'
        return ""
    }
    n := CountNeedleInFull(full, needle)
    if (n > 1)
        Tip("That text appears " . n . " times — changing the first match only.")
    if !(LocateSelectionInFull(full, needle, &pos, &matchLen)) {
        errMsg := 'Could not locate "' . Trunc(caseSourceText, 36) . '" in the text.'
        return ""
    }
    return SubStr(full, 1, pos - 1) . newSel . SubStr(full, pos + matchLen)
}

CountNeedleInFull(full, needle) {
    if (needle = "")
        return 0
    count := 0
    pos := 1
    lowFull := StrLower(full)
    lowNeedle := StrLower(needle)
    len := StrLen(needle)
    loop {
        p := InStr(lowFull, lowNeedle, , pos)
        if !p
            break
        count++
        pos := p + len
    }
    return count
}

ResolveSelectionNeedle(full, rawClipboard, sanitized) {
    for n in [rawClipboard, sanitized] {
        n := SanitizeGrabbedText(n)
        if (n = "")
            continue
        if (LocateSelectionInFull(full, n, &pos, &matchLen))
            return SubStr(full, pos, matchLen)
    }
    return ""
}

LocateSelectionInFull(full, needle, &pos, &matchLen) {
    pos := 0
    matchLen := 0
    if (needle = "")
        return false
    pos := InStr(full, needle, , 1)
    if pos {
        matchLen := StrLen(needle)
        return true
    }
    pos := InStr(StrLower(full), StrLower(needle), , 1)
    if !pos
        return false
    matchLen := StrLen(needle)
    actual := SubStr(full, pos, matchLen)
    if (StrLower(actual) != StrLower(needle))
        return false
    return true
}

TryCopyFieldAllInPlace() {
    global CopyDelayMs
    clipSaved := ClipboardAll()
    A_Clipboard := ""
    Send("^a")
    Sleep(CopyDelayMs)
    Send("^c")
    if !ClipWait(1.0) {
        A_Clipboard := clipSaved
        return ""
    }
    full := A_Clipboard
    A_Clipboard := clipSaved
    return SanitizeGrabbedText(full)
}

; --- Popup UI ---------------------------------------------------------------
ShowOpsPopup(anchorX, anchorY) {
    global opsGui, editHwnd, dragLabelCtrl, PopupWidth, PopupOffsetX, PopupOffsetY, PopupEstHeight, dragZoneH
    global fieldRectLeft, fieldRectTop, fieldRectRight, fieldRectBottom, dragActive

    CloseOpsPopup()

    GetFieldRectAtPoint(anchorX, anchorY, &fieldRectLeft, &fieldRectTop, &fieldRectRight, &fieldRectBottom)

    popW := PopupWidth
    popH := PopupEstHeight
    CalcPopupPos(fieldRectLeft, fieldRectTop, fieldRectRight, fieldRectBottom, popW, popH, &gx, &gy)
    ClampPopupOnScreen(&gx, &gy, popW, popH, fieldRectRight, fieldRectTop)

    editW := PopupWidth - 12
    dragBarH := 16
    guiH := 50

    opsGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "NUMB")
    opsGui.BackColor := "1e1e1e"
    opsGui.MarginX := 6
    opsGui.MarginY := 4
    opsGui.SetFont("s10 c777777", "Segoe UI")
    dragLabelCtrl := opsGui.AddText("xm ym w" editW " h" dragBarH " Background252525 Right cAAAAAA", "NUMB")
    opsGui.SetFont("s10 cFFFFFF", "Consolas")
    editCtrl := opsGui.AddEdit("xm y+4 w" editW " h22 vOpEdit Background2d2d2d")
    editHwnd := editCtrl.Hwnd
    dragActive := false

    opsGui.OnEvent("Close", (*) => CloseOpsPopup())
    opsGui.OnEvent("Escape", (*) => CloseOpsPopup())

    opsGui.Show("x" gx " y" gy " w" PopupWidth " h" guiH)
    global popupMode
    popupMode := "math"
    EnableNumbPopupHotkeys(opsGui.Hwnd)
    global suppressOutsideDismiss
    suppressOutsideDismiss := true
    SetTimer(NumbPopupWatch, 25)
    WinActivate("ahk_id " opsGui.Hwnd)
    editCtrl.Focus()
}

ShowCasePopup(anchorX, anchorY) {
    global opsGui, dragLabelCtrl, PopupOffsetX, PopupOffsetY, dragZoneH, CasePopupWidth
    global fieldRectLeft, fieldRectTop, fieldRectRight, fieldRectBottom, dragActive
    global caseSourceText, casePreviewCtrl, caseIconEntries, caseHoverActive, popupMode, caseFromPreSelection
    global caseSourceRaw, targetWin

    preSel := caseFromPreSelection
    rawSnap := caseSourceRaw
    txtSnap := caseSourceText
    CloseOpsPopup()
    caseFromPreSelection := preSel
    caseSourceRaw := rawSnap
    caseSourceText := txtSnap

    GetFieldRectAtPoint(anchorX, anchorY, &fieldRectLeft, &fieldRectTop, &fieldRectRight, &fieldRectBottom)

    popW := CasePopupWidth
    popH := 58
    CalcPopupPos(fieldRectLeft, fieldRectTop, fieldRectRight, fieldRectBottom, popW, popH, &gx, &gy)
    ClampPopupOnScreen(&gx, &gy, popW, popH, fieldRectRight, fieldRectTop)

    editW := CasePopupWidth - 12
    dragBarH := 16
    guiH := 82
    iconGap := 4
    iconW := (editW - iconGap * 3) // 4
    iconH := 28

    opsGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "NUMB")
    opsGui.BackColor := "1e1e1e"
    opsGui.MarginX := 6
    opsGui.MarginY := 4
    opsGui.SetFont("s10 c777777", "Segoe UI")
    dragLabelCtrl := opsGui.AddText("xm ym w" editW " h" dragBarH " Background252525 Right cAAAAAA", "NUMB")
    opsGui.SetFont("s10 cFFFFFF", "Segoe UI")
    casePreviewCtrl := opsGui.AddEdit("xm y+4 w" editW " h22 ReadOnly -TabStop Background2d2d2d cFFFFFF", caseSourceText)
    global editHwnd
    editHwnd := 0
    dragActive := false
    caseIconEntries := []
    caseHoverActive := ""

    opsGui.SetFont("s10 bold cECECEC", "Segoe UI")
    icons := [
        { mode: "upper", label: "A" },
        { mode: "lower", label: "a" },
        { mode: "first", label: "Ab" },
        { mode: "title", label: "Ab Cd" }
    ]
    loop icons.Length {
        i := A_Index
        m := icons[i]
        if (i = 1)
            opts := "xm y+6 w" iconW " h" iconH " Center Background333333"
        else
            opts := "x+" iconGap " yp w" iconW " h" iconH " Center Background333333"
        ctrl := opsGui.AddText(opts, m.label)
        ctrl.OnEvent("Click", CaseIconClick.Bind(m.mode))
        caseIconEntries.Push({ mode: m.mode, ctrl: ctrl })
    }

    opsGui.OnEvent("Close", (*) => CloseOpsPopup())
    opsGui.OnEvent("Escape", (*) => CloseOpsPopup())

    showOpts := "x" gx " y" gy " w" CasePopupWidth " h" guiH
    if caseFromPreSelection || !IsCopyClipUnsafeHost(targetWin)
        showOpts .= " NoActivate"
    opsGui.Show(showOpts)
    popupMode := "case"
    EnableCasePopupHotkeys(opsGui.Hwnd)
    global suppressOutsideDismiss
    suppressOutsideDismiss := true
    SetTimer(NumbPopupWatch, 25)
    SetTimer(CaseHoverTick, 40)
}

EnableCasePopupHotkeys(guiHwnd) {
    HotIfWinExist("ahk_id " guiHwnd)
    Hotkey("Esc", (*) => CloseOpsPopup(), "On")
    HotIf()
}

CaseHoverTick() {
    global opsGui, popupMode, casePreviewCtrl, caseSourceText, caseIconEntries, caseHoverActive
    if (popupMode != "case" || !opsGui || !casePreviewCtrl)
        return
    MouseGetPos(, , &win, &ctrlHwnd, 2)
    if (win != opsGui.Hwnd) {
        CaseSetIconHover("")
        casePreviewCtrl.Value := caseSourceText
        return
    }
    for entry in caseIconEntries {
        if (entry.ctrl.Hwnd = ctrlHwnd) {
            CaseSetIconHover(entry.mode)
            casePreviewCtrl.Value := TransformCase(caseSourceText, entry.mode)
            return
        }
    }
    CaseSetIconHover("")
    casePreviewCtrl.Value := caseSourceText
}

CaseIconClick(mode, *) {
    global caseSourceText, caseSourceRaw, caseFromPreSelection, targetWin, WriteDelayMs
    IncrementUseCount()
    src := caseSourceText
    raw := caseSourceRaw
    fromPre := caseFromPreSelection
    win := targetWin
    CloseOpsPopup()
    caseSourceText := src
    caseSourceRaw := raw
    caseFromPreSelection := fromPre
    targetWin := win
    if (Trim(src) = "") {
        Tip("Nothing to apply.")
        return
    }
    if targetWin {
        try WinActivate("ahk_id " targetWin)
        Sleep(WriteDelayMs)
    }
    ApplyCaseToSelectionOnly(mode)
}

BuildCaseResult(mode) {
    global caseSourceText
    return TransformCase(caseSourceText, mode)
}

CaseSetIconHover(activeMode) {
    global caseIconEntries, caseHoverActive
    if (caseHoverActive = activeMode)
        return
    caseHoverActive := activeMode
    for entry in caseIconEntries {
        bg := (entry.mode = activeMode && activeMode != "") ? "555555" : "333333"
        try entry.ctrl.Opt("Background" bg)
    }
}

SanitizeGrabbedText(text) {
    text := RegExReplace(text, '[\r\n]+$')
    return text
}

IsTextForCase(text) {
    text := Trim(text)
    if (text = "")
        return false
    ; Any letter in the selection → case mode (even "Room 101", "A-1").
    if !RegExMatch(text, "[A-Za-z]")
        return false
    ; Pure numeric string has no letters — handled by math route.
    return !IsPureNumber(text)
}

IsPureNumber(text) {
    text := Trim(text)
    text := StrReplace(text, ",", "")
    text := StrReplace(text, " ", "")
    return RegExMatch(text, "^[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?$")
}

TransformCase(text, mode) {
    text := SanitizeGrabbedText(text)
    if !InStr(text, "`r") && !InStr(text, "`n")
        return TransformCaseLine(text, mode)
    norm := StrReplace(text, "`r`n", "`n")
    norm := StrReplace(norm, "`r", "`n")
    lines := StrSplit(norm, "`n")
    out := ""
    for i, line in lines {
        if (i > 1)
            out .= "`n"
        out .= TransformCaseLine(line, mode)
    }
    return out
}

TransformCaseLine(text, mode) {
    switch mode {
        case "upper":
            return StrUpper(text)
        case "lower":
            return StrLower(text)
        case "first":
            t := StrLower(text)
            if (t = "")
                return t
            return StrUpper(SubStr(t, 1, 1)) . SubStr(t, 2)
        case "title":
            return TitleCase(text)
        default:
            return text
    }
}

TitleCase(text) {
    parts := StrSplit(text, A_Space, " `t")
    out := ""
    for i, w in parts {
        if (i > 1)
            out .= " "
        if (w = "")
            continue
        out .= StrUpper(SubStr(w, 1, 1)) . StrLower(SubStr(w, 2))
    }
    return out
}

EnableNumbPopupHotkeys(guiHwnd) {
    HotIfWinExist("ahk_id " guiHwnd)
    Hotkey("Enter", OnEnterApply, "On")
    Hotkey("NumpadEnter", OnEnterApply, "On")
    Hotkey("Esc", (*) => CloseOpsPopup(), "On")
    HotIf()
}

OnEnterApply(*) {
    global opsGui, baseValue, WriteDelayMs
    if !opsGui
        return

    expr := Trim(opsGui["OpEdit"].Value)
    if expr = "" {
        CloseOpsPopup()
        return
    }

    full := BuildExpression(baseValue, expr)
    result := SafeEval(full)
    if result = "" {
        SoundBeep(750, 120)
        Tip("Invalid expression: " . Trunc(expr, 48))
        return
    }

    out := FormatNumber(result)
    IncrementUseCount()
    CloseOpsPopup()
    ApplyResultToField(out, true)
}

ApplyResultToField(out, selectAllBeforeWrite := true, doubleClickBeforeWrite := false, isCaseWrite := false) {
    global targetWin, fieldClickX, fieldClickY, WriteDelayMs, ClickDelayMs
    global ReclickFieldBeforeWrite, UseClipboardPasteForWrite, CommitEnterAfterWrite, CommitEnterAfterCaseWrite

    if isCaseWrite
        out := SanitizeGrabbedText(out)

    if targetWin {
        try WinActivate("ahk_id " targetWin)
        Sleep(WriteDelayMs)
    }
    if doubleClickBeforeWrite {
        Click(fieldClickX, fieldClickY, 2)
        Sleep(ClickDelayMs * 2)
    } else if ReclickFieldBeforeWrite && !isCaseWrite {
        Click(fieldClickX, fieldClickY)
        Sleep(ClickDelayMs)
    }
    if selectAllBeforeWrite && !isCaseWrite {
        Send("^a")
        Sleep(WriteDelayMs)
    }
    if UseClipboardPasteForWrite {
        clipSaved := ClipboardAll()
        A_Clipboard := out
        if !ClipWait(0.3) {
            A_Clipboard := clipSaved
            Tip("Could not paste result (clipboard).")
            return
        }
        Send("^v")
        Sleep(WriteDelayMs)
        A_Clipboard := clipSaved
    } else {
        SendText(out)
        Sleep(WriteDelayMs)
    }
    if isCaseWrite {
        if CommitEnterAfterCaseWrite
            Send("{Enter}")
    } else if CommitEnterAfterWrite {
        Send("{Enter}")
    }
}

CloseOpsPopup() {
    global opsGui, editHwnd, dragLabelCtrl, dragActive, popupMode
    dragActive := false
    SetTimer(NumbDragMoveTick, 0)
    SetTimer(NumbPopupWatch, 0)
    SetTimer(CaseHoverTick, 0)
    popupMode := ""
    if opsGui {
        try NumbSaveDragPos()
        try {
            HotIfWinExist("ahk_id " opsGui.Hwnd)
            try Hotkey("Enter", "Off")
            try Hotkey("NumpadEnter", "Off")
            try Hotkey("Esc", "Off")
            HotIf()
        }
        try opsGui.Destroy()
    }
    opsGui := 0
    editHwnd := 0
    dragLabelCtrl := 0
    global casePreviewCtrl, caseIconEntries, caseHoverActive, caseFromPreSelection, caseFullText, caseSelectionNeedle, caseSourceRaw
    casePreviewCtrl := 0
    caseIconEntries := []
    caseHoverActive := ""
    caseFromPreSelection := false
    caseFullText := ""
    caseSelectionNeedle := ""
    caseSourceRaw := ""
}

; --- Expression helpers -----------------------------------------------------
; Operator-leading input applies to the grabbed base (+56, *2, /(1+1)).
; Leading '=' (Excel-style) ignores the base and evaluates the rest (=32+54).
; Input starting with '(' or a bare number / full expression is evaluated as-is.
BuildExpression(base, expr) {
    expr := RegExReplace(expr, "\s+", "")
    if expr = ""
        return ""

    if (SubStr(expr, 1, 1) = "=") {
        expr := SubStr(expr, 2)
        if (expr = "")
            return ""
        return expr
    }

    if RegExMatch(expr, "^[+\-*/]")
        return String(base) . expr

    if SubStr(expr, 1, 1) = "("
        return expr

    if RegExMatch(expr, "^[+-]?(\d+(\.\d*)?|\.\d+)$")
        return expr

    return expr
}

ParseNumber(text) {
    text := Trim(text)
    text := StrReplace(text, ",", "")
    text := StrReplace(text, " ", "")
    if RegExMatch(text, "^[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?$", &m)
        return Number(m[0])
    ; Allow leading junk like "Depth: 553.25"
    if RegExMatch(text, "[+-]?(\d+(\.\d*)?|\.\d+)", &m)
        return Number(m[0])
    return ""
}

FormatNumber(n) {
    if !IsNumber(n)
        return ""
    ; Avoid binary float noise: 609.2500000001 → 609.25
    return Format("{:.10g}", Number(n))
}

; --- Safe recursive-descent evaluator (digits . + - * / ( ) only) -----------
SafeEval(expr) {
    expr := RegExReplace(expr, "\s+", "")
    if expr = ""
        return ""
    if !RegExMatch(expr, "^[0-9.+*/()-]+$")
        return ""

    pos := 1
    try {
        val := ParseExpr(expr, &pos)
        if pos <= StrLen(expr)
            return ""  ; trailing junk
        return Float(val)
    } catch {
        return ""
    }
}

ParseExpr(s, &pos) {
    left := Float(ParseTerm(s, &pos))
    loop {
        op := Peek(s, pos)
        if (op != "+" && op != "-")
            break
        pos += 1
        right := Float(ParseTerm(s, &pos))
        left := (op = "+") ? (left + right) : (left - right)
    }
    return left
}

ParseTerm(s, &pos) {
    left := Float(ParseUnary(s, &pos))
    loop {
        op := Peek(s, pos)
        if (op != "*" && op != "/")
            break
        pos += 1
        right := Float(ParseUnary(s, &pos))
        if (op = "/") {
            if right = 0
                throw Error("div0")
            left := left / right
        } else {
            left := left * right
        }
    }
    return left
}

ParseUnary(s, &pos) {
    op := Peek(s, pos)
    if (op = "+") {
        pos += 1
        return ParseUnary(s, &pos)
    }
    if (op = "-") {
        pos += 1
        return -ParseUnary(s, &pos)
    }
    return ParsePrimary(s, &pos)
}

ParsePrimary(s, &pos) {
    ch := Peek(s, pos)
    if ch = "(" {
        pos += 1
        val := ParseExpr(s, &pos)
        if Peek(s, pos) != ")"
            throw Error("paren")
        pos += 1
        return val
    }
    return ParseNumberToken(s, &pos)
}

ParseNumberToken(s, &pos) {
    len := StrLen(s)
    start := pos
    if pos > len
        throw Error("num")
    sawDot := false
    while pos <= len {
        c := SubStr(s, pos, 1)
        if InStr("0123456789", c) {
            pos += 1
            continue
        }
        if (c = "." && !sawDot) {
            sawDot := true
            pos += 1
            continue
        }
        break
    }
    if pos = start
        throw Error("num")
    token := SubStr(s, start, pos - start)
    if (token = "." || token = "")
        throw Error("num")
    return Float(token)
}

Peek(s, pos) {
    if pos > StrLen(s)
        return ""
    return SubStr(s, pos, 1)
}

; --- Misc -------------------------------------------------------------------
LoadUseCount() {
    global settingsPath, useCount
    useCount := Integer(Trim(IniRead(settingsPath, "Stats", "UseCount", "0")))
}

SaveUseCount() {
    global settingsPath, useCount
    IniWrite(String(useCount), settingsPath, "Stats", "UseCount")
}

IncrementUseCount() {
    global useCount
    useCount += 1
    SaveUseCount()
    UpdateTrayTip()
}

UpdateTrayTip() {
    global APP_VERSION, useCount
    A_IconTip := "NUMB v" APP_VERSION " — Ctrl+Shift+Click a number`nUses: " useCount
}

ShowAbout() {
    global APP_VERSION, useCount
    MsgBox(
        "NUMB v" APP_VERSION "`n`n"
        . "Ctrl+Shift+Click a number, type +56 / *2 / (10+2)/2, or =32+54 (ignore field), Enter.`n"
        . "Highlight text for case (MText or email), Ctrl+Shift+Click — A/a/Ab/Ab Cd.`n"
        . "Numbers: Ctrl+Shift+Click a property/number field (Ix/imos/AutoCAD) or any numeric field elsewhere.`n"
        . "Formulas: =32+54 ignores the current value.`n`n"
        . "Uses so far: " useCount "`n`n"
        . "After Exit: double-click Start NUMB.bat in the install folder`n"
        . "(tray menu Open install folder), or use the Start menu NUMB shortcut.`n"
        . "If you chose logon startup at install, sign in again to auto-start.`n`n"
        . "Created by Wolf`n"
        . "5/11/2026`n"
        . "yankolobo@gmail.com",
        "About NUMB",
        "Iconi"
    )
}

NumbOpenInstallFolder(*) {
    try Run(A_ScriptDir)
    catch as err
        Tip("Could not open folder: " err.Message)
}

Tip(msg) {
    TrayTip("NUMB", msg, "Mute")
    SetTimer(() => TrayTip(), -2200)
}

Trunc(s, n) {
    return (StrLen(s) <= n) ? s : SubStr(s, 1, n) "…"
}

; Field rect + popup placement (screen coords)
GetFieldRectAtPoint(clickX, clickY, &left, &top, &right, &bottom) {
    if (TryFieldHwndRect(clickX, clickY, &left, &top, &right, &bottom))
        return
    ; Property grid / Ix: anchor to the row you clicked (not the whole palette)
    left := clickX - 12
    top := clickY - 14
    right := clickX + 160
    bottom := clickY + 14
}

TryFieldHwndRect(clickX, clickY, &left, &top, &right, &bottom) {
    global maxFieldW, maxFieldH
    try {
        hwnd := HwndAtPoint(clickX, clickY)
        if !hwnd
            return false
        if !GetWindowScreenRect(hwnd, &left, &top, &right, &bottom)
            return false
        w := right - left
        h := bottom - top
        if (w < 4 || h < 4)
            return false
        ; Reject whole panels (Ix Properties) — use click-row fallback instead
        if (w > maxFieldW || h > maxFieldH)
            return false
        if (w > A_ScreenWidth * 0.85 || h > A_ScreenHeight * 0.85)
            return false
        return true
    } catch {
        return false
    }
}

LoadPopupRelOffset(&relX, &relY, &custom) {
    global settingsPath, savedPopupCustom, savedRelX, savedRelY
    if savedPopupCustom {
        custom := true
        relX := savedRelX
        relY := savedRelY
        return
    }
    custom := (Trim(IniRead(settingsPath, "Popup", "Custom", "0")) = "1")
    relX := Float(Trim(IniRead(settingsPath, "Popup", "RelX", "0")))
    relY := Float(Trim(IniRead(settingsPath, "Popup", "RelY", "0")))
    if custom {
        savedPopupCustom := true
        savedRelX := relX
        savedRelY := relY
    }
}

SavePopupRelOffset(relX, relY) {
    global settingsPath, savedPopupCustom, savedRelX, savedRelY
    relX := Round(relX)
    relY := Round(relY)
    savedPopupCustom := true
    savedRelX := relX
    savedRelY := relY
    IniWrite("1", settingsPath, "Popup", "Custom")
    IniWrite(String(relX), settingsPath, "Popup", "RelX")
    IniWrite(String(relY), settingsPath, "Popup", "RelY")
}

; Default: right of field, vertically aligned to the clicked row.
CalcPopupPos(fL, fT, fR, fB, popW, popH, &gx, &gy) {
    global PopupOffsetX
    LoadPopupRelOffset(&relX, &relY, &custom)
    if custom {
        gx := fL + relX
        gy := fT + relY
    } else {
        gx := fR + PopupOffsetX
        gy := fT + Max(0, ((fB - fT) - popH) // 2)
    }
}

NumbSaveDragPos() {
    global opsGui, fieldRectLeft, fieldRectTop
    if !opsGui
        return
    try WinGetPos(&gx, &gy, , , "ahk_id " opsGui.Hwnd)
    catch
        return
    SavePopupRelOffset(gx - fieldRectLeft, gy - fieldRectTop)
}

SetDragVisual(on) {
    global dragLabelCtrl, opsGui
    if !opsGui || !dragLabelCtrl
        return
    try {
        if on
            dragLabelCtrl.SetFont("bold s9 c8BC34A", "Segoe UI")
        else
            dragLabelCtrl.SetFont("s9 cAAAAAA", "Segoe UI")
    } catch {
        return
    }
}

MouseInDragZone(mx, my) {
    global opsGui, dragZoneH
    if !opsGui
        return false
    try WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " opsGui.Hwnd)
    catch
        return false
    return (mx >= wx && mx <= wx + ww && my >= wy && my <= wy + dragZoneH)
}

StartNumbDrag() {
    global opsGui, dragActive, dragGrabX, dragGrabY
    if !opsGui || dragActive
        return
    MouseGetPos(&mx, &my)
    if !MouseInDragZone(mx, my)
        return
    WinGetPos(&wx, &wy, , , "ahk_id " opsGui.Hwnd)
    dragGrabX := mx - wx
    dragGrabY := my - wy
    dragActive := true
    SetDragVisual(true)
    SetTimer(NumbDragMoveTick, 8)
}

EndNumbDrag() {
    global opsGui, dragActive
    if !dragActive
        return
    if opsGui
        NumbSaveDragPos()
    dragActive := false
    SetTimer(NumbDragMoveTick, 0)
    if !opsGui
        return
    SetDragVisual(false)
    try opsGui["OpEdit"].Focus()
}

NumbDragMoveTick() {
    global opsGui, dragActive, dragGrabX, dragGrabY
    if !opsGui || !dragActive {
        SetTimer(NumbDragMoveTick, 0)
        return
    }
    if !GetKeyState("LButton", "P") {
        EndNumbDrag()
        return
    }
    MouseGetPos(&mx, &my)
    nx := mx - dragGrabX
    ny := my - dragGrabY
    WinGetPos(, , &ww, &wh, "ahk_id " opsGui.Hwnd)
    DllCall("MoveWindow", "Ptr", Integer(opsGui.Hwnd), "Int", nx, "Int", ny, "Int", ww, "Int", wh, "Int", 1)
}

NumbGlobalLDown(wParam, lParam, msg, hwnd) {
    global opsGui
    if !opsGui
        return
    StartNumbDrag()
}

; Clicks on other apps never hit our OnMessage — poll while the popup is open.
NumbPopupWatch() {
    global opsGui, suppressOutsideDismiss
    static lWasDown := false
    if !opsGui {
        lWasDown := false
        SetTimer(NumbPopupWatch, 0)
        return
    }
    lDown := GetKeyState("LButton", "P")
    if suppressOutsideDismiss {
        suppressOutsideDismiss := false
        lWasDown := lDown
        return
    }
    if lDown && !lWasDown {
        MouseGetPos(&mx, &my)
        if !IsClickOnOpsGui(mx, my)
            CloseOpsPopup()
    }
    lWasDown := lDown
}

IsClickOnOpsGui(mx, my) {
    global opsGui
    if !opsGui
        return false
    try WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " opsGui.Hwnd)
    catch
        return false
    return (mx >= wx && mx <= wx + ww && my >= wy && my <= wy + wh)
}

NumbGlobalLUp(wParam, lParam, msg, hwnd) {
    global dragActive
    if dragActive
        EndNumbDrag()
}

HwndAtPoint(x, y) {
    return DllCall("WindowFromPoint", "Int64", (y << 32) | (x & 0xFFFFFFFF), "Ptr")
}

GetWindowScreenRect(hwnd, &left, &top, &right, &bottom) {
    rect := Buffer(16, 0)
    if !DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect)
        return false
    left := NumGet(rect, 0, "Int")
    top := NumGet(rect, 4, "Int")
    right := NumGet(rect, 8, "Int")
    bottom := NumGet(rect, 12, "Int")
    return (right > left && bottom > top)
}

ClampPopupOnScreen(&gx, &gy, popW, popH, anchorX, anchorY) {
    global PopupOffsetX, PopupOffsetY
    margin := 4
    if (gx + popW > A_ScreenWidth - margin)
        gx := Max(margin, anchorX - popW - PopupOffsetX)
    if (gy + popH > A_ScreenHeight - margin)
        gy := Max(margin, anchorY - popH - PopupOffsetY)
    if (gx < margin)
        gx := margin
    if (gy < margin)
        gy := margin
}

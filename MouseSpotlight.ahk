#Include ./Utils.ahk
#SingleInstance, Force
#NoEnv
#MaxThreadsPerHotkey 3
#installmousehook
#installkeybdhook
#MaxHotkeysPerInterval 100

SetBatchLines, -1
SetWinDelay, -1
CoordMode, mouse, screen
SetWorkingDir, %A_ScriptDir%

ClickEvents := []

; Variables for the new spotlight behavior
SpotlightCurrentlyTyping := False
SpotlightLastMouseX := -1
SpotlightLastMouseY := -1
SpotlightMouseHasMovedSinceTyping := False
SpotlightShouldShowBasedOnActivity := True

SetupMouseSpotlight()
{
    global
    SETTINGS := ReadConfigFile("settings.ini")
    InitializeSpotlightGUI()
    SetupKeyboardHooksForSpotlight()
}

SetupKeyboardHooksForSpotlight()
{
    global
    ; Hook all keyboard keys to detect typing
    ProcessKeyForSpotlightFunc := Func("ProcessKeyForSpotlight")
    SetFormat, Integer, hex
    start := 0 
    Loop, 227
    {
        if ((key := GetKeyName("vk" start++)) != "")
            Hotkey, ~*%key%, %ProcessKeyForSpotlightFunc%
    }
    
    ; Add special keys
    for a, b in StrSplit("Up,Down,Left,Right,End,Home,PgUp,PgDn,Insert,Delete,NumpadEnter,Space,Tab,Enter,Backspace",",")
    {
        Hotkey, ~*%b%, %ProcessKeyForSpotlightFunc%
    }
    SetFormat, Integer, dec
}

ProcessKeyForSpotlight()
{
    global SpotlightCurrentlyTyping, SpotlightMouseHasMovedSinceTyping, SpotlightShouldShowBasedOnActivity
    
    ; Skip modifier keys (we only want to detect actual typing)
    theKeyPressed := SubStr(A_ThisHotkey, 3)
    if (theKeyPressed == "LShift" || theKeyPressed == "RShift" || theKeyPressed == "LControl" || theKeyPressed == "RControl" 
        || theKeyPressed == "LAlt" || theKeyPressed == "RAlt" || theKeyPressed == "LWin" || theKeyPressed == "RWin")
    {
        Return
    }
    
    ; User started typing - hide spotlight
    SpotlightCurrentlyTyping := True
    SpotlightMouseHasMovedSinceTyping := False
    SpotlightShouldShowBasedOnActivity := False
    
    ; Reset typing state after 1 second of no typing
    SetTimer, ResetTypingState, -1000
    Return
    
    ResetTypingState:
        SpotlightCurrentlyTyping := False
    Return
}

InitializeSpotlightGUI(){ 
    global CursorSpotlightHwnd, SETTINGS
    if (SETTINGS.cursorSpotlight.enabled == True)
    { 
        global CursorSpotlightDiameter := SETTINGS.cursorSpotlight.spotlightDiameter
        spotlightOuterRingWidth := SETTINGS.cursorSpotlight.spotlightOuterRingWidth
        Gui, CursorSpotlightWindow: +HwndCursorSpotlightHwnd +AlwaysOnTop -Caption +ToolWindow +E0x20 ;+E0x20 click thru
        Gui, CursorSpotlightWindow: Color, % SETTINGS.cursorSpotlight.spotlightColor
        Gui, CursorSpotlightWindow: Show, x0 y0 w%CursorSpotlightDiameter% h%CursorSpotlightDiameter% NA
        WinSet, Transparent, % SETTINGS.CursorSpotlight.spotlightOpacity, ahk_id %CursorSpotlightHwnd%
        ; Create a ring region to highlight the cursor
        finalRegion := DllCall("CreateEllipticRgn", "Int", 0, "Int", 0, "Int", CursorSpotlightDiameter, "Int", CursorSpotlightDiameter)
        if (spotlightOuterRingWidth < CursorSpotlightDiameter/2)
        {
            inner := DllCall("CreateEllipticRgn", "Int", spotlightOuterRingWidth, "Int", spotlightOuterRingWidth, "Int", CursorSpotlightDiameter-spotlightOuterRingWidth, "Int", CursorSpotlightDiameter-spotlightOuterRingWidth)
            DllCall("CombineRgn", "UInt", finalRegion, "UInt", finalRegion, "UInt", inner, "Int", 3) ; RGN_XOR = 3                                      
            DllCall("DeleteObject", UInt, inner)
        }
        DllCall("SetWindowRgn", "UInt", CursorSpotlightHwnd, "UInt", finalRegion, "UInt", true)
        SetTimer, DrawSpotlight, 10
        Return

        DrawSpotlight:            
            ; SETTINGS.cursorSpotlight.enabled can be changed by other script such as Annotation.ahk
            if (SETTINGS.cursorSpotlight.enabled == True)
            {
                MouseGetPos, CurrentX, CurrentY
                
                ; Check if mouse has moved
                if (SpotlightLastMouseX != CurrentX || SpotlightLastMouseY != CurrentY)
                {
                    ; Mouse moved - reset typing flag and show spotlight
                    if (SpotlightCurrentlyTyping)
                    {
                        SpotlightMouseHasMovedSinceTyping := True
                        SpotlightShouldShowBasedOnActivity := True
                    }
                    else
                    {
                        SpotlightShouldShowBasedOnActivity := True
                    }
                    
                    SpotlightLastMouseX := CurrentX
                    SpotlightLastMouseY := CurrentY
                    
                    ; Reset the auto-hide timer (2 seconds after mouse stops moving)
                    SetTimer, HideSpotlightAfterInactivity, -2000
                }
                
                ; Show spotlight only if: not currently typing (or mouse moved since typing) AND activity-based showing is enabled
                shouldShowSpotlight := SpotlightShouldShowBasedOnActivity && (!SpotlightCurrentlyTyping || SpotlightMouseHasMovedSinceTyping)
                
                if (shouldShowSpotlight)
                {
                    X := CurrentX - CursorSpotlightDiameter / 2
                    Y := CurrentY - CursorSpotlightDiameter / 2
                    WinMove, ahk_id %CursorSpotlightHwnd%, , %X%, %Y%
                    WinSet, AlwaysOnTop, On, ahk_id %CursorSpotlightHwnd%
                }
                else
                {
                    ; Hide spotlight by moving it off screen
                    WinMove, ahk_id %CursorSpotlightHwnd%, , -999999999, -999999999
                }
            }
            else
            {
                 WinMove, ahk_id %CursorSpotlightHwnd%, , -999999999, -999999999
            }

        Return
        
        HideSpotlightAfterInactivity:
            ; Hide spotlight after 2 seconds of no mouse movement
            SpotlightShouldShowBasedOnActivity := False
        Return
    }
}

SetupMouseSpotlight()

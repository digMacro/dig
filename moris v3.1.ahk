#Requires AutoHotkey v2.0
#SingleInstance Force

defaultTerrainColors := Map(
    "add custom terrain", [0x000000],
)

terrainColors := Map()
settingsFile := A_ScriptDir . "\settings.ini"

LoadSettings()

MyGui := Gui()
MyGui.Title := "moris dig v3.1"
MyGui.OnEvent("Close", OnGuiClose)

TabCtrl := MyGui.Add("Tab3", "w300 h300", ["Main", "Custom Terrain", "Debug", "Instructions", "Credits"])

TabCtrl.UseTab("Main")
MyGui.Add("Text", "Section", "Terrain:")
terrainDropdown := MyGui.Add("DropDownList", "w150 ys vSelectedTerrain", GetTerrainNames())
terrainDropdown.OnEvent("Change", UpdateTerrainType)
terrainDropdown.Value := selectedTerrainIndex

MyGui.Add("Button", "xs Section w80", "Start (F1)").OnEvent("Click", (*) => Send("{F1}"))
MyGui.Add("Button", "ys w80", "Reload (F2)").OnEvent("Click", (*) => Send("{F2}"))

MyGui.Add("CheckBox", "xs Section vRecoveryToggle", "Enable Recovery Cycle").Value := recoveryCycleEnabled
MyGui.Add("CheckBox", "xs vAutoSellToggle", "Auto Sell (after 5 cycles)").Value := autoSellEnabled

TabCtrl.UseTab("Custom Terrain")
MyGui.Add("Text", "Section", "Create Custom Terrain:")
MyGui.Add("Text", "xs", "Terrain Name:")
customNameEdit := MyGui.Add("Edit", "w150 vCustomName")
MyGui.Add("Text", "xs", "Color (Hex, e.g., 0xFF0000):")
customColorEdit := MyGui.Add("Edit", "w150 vCustomColor")
MyGui.Add("Button", "xs section w70", "Add Terrain").OnEvent("Click", AddCustomTerrain)
MyGui.Add("Button", "ys w70", "Delete").OnEvent("Click", DeleteCustomTerrain)

MyGui.Add("Text", "xs Section", "Existing Custom Terrains:")
customTerrainList := MyGui.Add("ListBox", "w200 h100 vCustomTerrainList")
UpdateCustomTerrainList()

TabCtrl.UseTab("Debug")
MyGui.Add("Text", "Section", "DONT CHANGE ANYTHING IF YOUR NOT SMART")
MyGui.Add("Text", "Section", "Click Delay:")
clickDelayEdit := MyGui.Add("Edit", "w40 ys", clickDelay)
clickDelayEdit.OnEvent("Change", UpdateClickDelay)
MyGui.Add("Text", "xs Section", "Scan Radius:")
scanRadiusEdit := MyGui.Add("Edit", "w40 ys", clickScanRadius)
scanRadiusEdit.OnEvent("Change", UpdateScanRadius)
MyGui.Add("Text", "xs Section", "Cooldown:")
clickCooldownEdit := MyGui.Add("Edit", "w40 ys", clickCooldown)
clickCooldownEdit.OnEvent("Change", UpdateClickCooldown)
MyGui.Add("Text", "xs Section", "Interval:")
followIntervalEdit := MyGui.Add("Edit", "w40 ys", followInterval)
followIntervalEdit.OnEvent("Change", UpdateFollowInterval)
MyGui.Add("Text", "xs Section", "Buffer:")
mouseBufferEdit := MyGui.Add("Edit", "w40 ys", mouseBuffer)
mouseBufferEdit.OnEvent("Change", UpdateMouseBuffer)
MyGui.Add("Text", "xs Section", "Recovery Cycles:")
cycleCountText := MyGui.Add("Text", "ys w50 Border Center", String(recoveryCycleCount))
MyGui.Add("Button", "ys w60", "Reset Count").OnEvent("Click", ResetCycleCount)

TabCtrl.UseTab("Instructions")
MyGui.Add("Text",, "F1 to Start")
MyGui.Add("Text",, "F2 to Reload the Macro")
MyGui.Add("Text",, "F3 to Copy current mouse Location color to Clipboard")

TabCtrl.UseTab("Credits")
MyGui.Add("Text",, "made by moris :)")
MyGui.Add("Text",, "webhooks and rejoin by adnrealan")
DiscordBtn := MyGui.Add("Button",, "Join Discord")
DiscordBtn.OnEvent("Click", (*) => Run("https://discord.gg/2fraBuhe3m"))
DonateBtn := MyGui.Add("Button",, "Donate")
DonateBtn.OnEvent("Click", (*) => Run("https://www.roblox.com/catalog/124883742268645/katze"))

MyGui.Show()

scanLeft := 512
scanTop := 916
scanRight := 1397
scanBottom := 926
targetColor := 0x191919 ;DO NOT CHANGE
clickColors := terrainColors["add custom terrain"]
clickColorVariation := -10
scanning := false
minX := 99999
maxX := -1
lastClickTime := 0
lastFoundX := 0
lastFoundY := 0
lastPixelFoundTime := 0
recoveryActive := false
clickLoopActive := false
recoveryCycleEnabled := true
recoveryCycleCount := 0
autoSellEnabled := true
lastAutoSellCycle := 0

LoadSettings() {
    global settingsFile, clickDelay, clickScanRadius, clickCooldown, followInterval, mouseBuffer, selectedTerrainIndex
    global recoveryCycleEnabled, terrainColors, defaultTerrainColors, recoveryCycleCount, autoSellEnabled, lastAutoSellCycle

    clickDelay := 10
    clickScanRadius := 20
    clickCooldown := 200
    followInterval := 10
    mouseBuffer := 10
    selectedTerrainIndex := 1
    recoveryCycleEnabled := true
    recoveryCycleCount := 0
    autoSellEnabled := true
    lastAutoSellCycle := 0

    terrainColors := Map()

    if (FileExist(settingsFile)) {
        clickDelay := IniRead(settingsFile, "Settings", "ClickDelay", clickDelay)
        clickScanRadius := IniRead(settingsFile, "Settings", "ScanRadius", clickScanRadius)
        clickCooldown := IniRead(settingsFile, "Settings", "ClickCooldown", clickCooldown)
        followInterval := IniRead(settingsFile, "Settings", "FollowInterval", followInterval)
        mouseBuffer := IniRead(settingsFile, "Settings", "MouseBuffer", mouseBuffer)
        selectedTerrainIndex := IniRead(settingsFile, "Settings", "SelectedTerrain", selectedTerrainIndex)
        recoveryCycleEnabled := IniRead(settingsFile, "Settings", "RecoveryCycleEnabled", recoveryCycleEnabled)
        recoveryCycleCount := IniRead(settingsFile, "Settings", "RecoveryCycleCount", recoveryCycleCount)
        autoSellEnabled := IniRead(settingsFile, "Settings", "AutoSellEnabled", autoSellEnabled)
        lastAutoSellCycle := IniRead(settingsFile, "Settings", "LastAutoSellCycle", lastAutoSellCycle)
        
        LoadAllTerrains()
    } else {
        for name, colors in defaultTerrainColors {
            terrainColors[name] := colors
        }
        SaveAllTerrains()
    }
}

LoadAllTerrains() {
    global settingsFile, terrainColors, defaultTerrainColors
    
    try {
        allTerrainNames := IniRead(settingsFile, "TerrainColors", "AllTerrains", "")
        if (allTerrainNames != "") {
            terrainList := StrSplit(allTerrainNames, "|")
            for terrainName in terrainList {
                if (terrainName != "") {
                    colorsString := IniRead(settingsFile, "TerrainColors", terrainName, "")
                    if (colorsString != "") {
                        if (colorsString = "EMPTY") {
                            terrainColors[terrainName] := []
                        } else {
                            colorStrings := StrSplit(colorsString, ",")
                            colors := []
                            for colorString in colorStrings {
                                if (colorString != "") {
                                    colors.Push(Integer(colorString))
                                }
                            }
                            terrainColors[terrainName] := colors
                        }
                    }
                }
            }
        } else {
            for name, colors in defaultTerrainColors {
                terrainColors[name] := colors
            }
            SaveAllTerrains()
        }
    } catch {
        for name, colors in defaultTerrainColors {
            terrainColors[name] := colors
        }
        SaveAllTerrains()
    }
}

SaveSettings() {
    global settingsFile, clickDelay, clickScanRadius, clickCooldown, followInterval, mouseBuffer, terrainDropdown
    global recoveryCycleEnabled, recoveryCycleCount, autoSellEnabled, lastAutoSellCycle

    currentClickDelay := Integer(clickDelayEdit.Value)
    currentScanRadius := Integer(scanRadiusEdit.Value)
    currentClickCooldown := Integer(clickCooldownEdit.Value)
    currentFollowInterval := Integer(followIntervalEdit.Value)
    currentMouseBuffer := Integer(mouseBufferEdit.Value)
    currentSelectedTerrain := terrainDropdown.Value
    guiValues := MyGui.Submit(false)
    currentRecoveryToggle := guiValues.RecoveryToggle
    currentAutoSellToggle := guiValues.AutoSellToggle

    IniWrite(currentClickDelay, settingsFile, "Settings", "ClickDelay")
    IniWrite(currentScanRadius, settingsFile, "Settings", "ScanRadius")
    IniWrite(currentClickCooldown, settingsFile, "Settings", "ClickCooldown")
    IniWrite(currentFollowInterval, settingsFile, "Settings", "FollowInterval")
    IniWrite(currentMouseBuffer, settingsFile, "Settings", "MouseBuffer")
    IniWrite(currentSelectedTerrain, settingsFile, "Settings", "SelectedTerrain")
    IniWrite(currentRecoveryToggle, settingsFile, "Settings", "RecoveryCycleEnabled")
    IniWrite(recoveryCycleCount, settingsFile, "Settings", "RecoveryCycleCount")
    IniWrite(currentAutoSellToggle, settingsFile, "Settings", "AutoSellEnabled")
    IniWrite(lastAutoSellCycle, settingsFile, "Settings", "LastAutoSellCycle")

    SaveAllTerrains()
}

SaveAllTerrains() {
    global settingsFile, terrainColors

    allTerrainNames := ""
    
    for terrainName, colors in terrainColors {
        if (allTerrainNames != "") {
            allTerrainNames .= "|"
        }
        allTerrainNames .= terrainName

        if (colors.Length = 0) {
            IniWrite("EMPTY", settingsFile, "TerrainColors", terrainName)
        } else {
            colorString := ""
            for color in colors {
                if (colorString != "") {
                    colorString .= ","
                }
                colorString .= color
            }
            IniWrite(colorString, settingsFile, "TerrainColors", terrainName)
        }
    }

    IniWrite(allTerrainNames, settingsFile, "TerrainColors", "AllTerrains")
}

GetTerrainNames() {
    global terrainColors
    names := []
    for name, colors in terrainColors {
        names.Push(name)
    }
    return names
}

UpdateCustomTerrainList() {
    global customTerrainList, terrainColors, defaultTerrainColors
    
    customTerrainList.Delete()
    
    for terrainName, colors in terrainColors {
        if (!defaultTerrainColors.Has(terrainName)) {
            customTerrainList.Add([terrainName])
        }
    }
}

AddCustomTerrain(*) {
    global terrainColors, terrainDropdown, customNameEdit, customColorEdit
    
    terrainName := Trim(customNameEdit.Text)
    colorHex := Trim(customColorEdit.Text)
    
    if (terrainName = "" || colorHex = "") {
        MsgBox("Please enter both terrain name and color value.")
        return
    }

    if (!RegExMatch(colorHex, "^0x[0-9A-Fa-f]{6}$")) {
        MsgBox("Invalid color format. Please use format: 0xRRGGBB from F3")
        return
    }

    if (terrainColors.Has(terrainName)) {
        result := MsgBox("Terrain '" . terrainName . "' already exists. Overwrite?", "Confirm", "YesNo")
        if (result = "No") {
            return
        }
    }

    colorValue := Integer(colorHex)
    terrainColors[terrainName] := [colorValue]

    terrainDropdown.Delete()
    terrainDropdown.Add(GetTerrainNames())

    UpdateCustomTerrainList()

    customNameEdit.Text := ""
    customColorEdit.Text := ""
    
    ToolTip("Custom terrain '" . terrainName . "' added successfully!", 10, 30)
    SetTimer(() => ToolTip(), -2000)
}

DeleteCustomTerrain(*) {
    global customTerrainList, terrainColors, terrainDropdown, defaultTerrainColors
    
    selectedIndex := customTerrainList.Value
    if (selectedIndex = 0) {
        MsgBox("Please select a terrain to delete.")
        return
    }
    
    terrainName := customTerrainList.Text
    
    result := MsgBox("Are you sure you want to delete terrain '" . terrainName . "'?", "Confirm Delete", "YesNo")
    if (result = "Yes") {
        terrainColors.Delete(terrainName)

        terrainDropdown.Delete()
        terrainDropdown.Add(GetTerrainNames())
        
        UpdateCustomTerrainList()
        
        ToolTip("Terrain '" . terrainName . "' deleted successfully!", 10, 30)
        SetTimer(() => ToolTip(), -2000)
    }
}

ResetCycleCount(*) {
    global recoveryCycleCount, cycleCountText, lastAutoSellCycle
    recoveryCycleCount := 0
    lastAutoSellCycle := 0
    cycleCountText.Text := String(recoveryCycleCount)
    SaveSettings()
    ToolTip("Recovery cycle count reset to 0", 10, 30)
    SetTimer(() => ToolTip(), -2000)
}

UpdateCycleCountDisplay() {
    global cycleCountText, recoveryCycleCount
    cycleCountText.Text := String(recoveryCycleCount)
}

OnGuiClose(*) {
    SaveSettings()
    ExitApp
}

UpdateTerrainType(*) {
    global clickColors, terrainColors
    selectedTerrain := terrainDropdown.Text
    if (terrainColors.Has(selectedTerrain)) {
        clickColors := terrainColors[selectedTerrain]
    }
}

UpdateClickDelay(*) {
    global clickDelay
    clickDelay := Integer(clickDelayEdit.Value)
}

UpdateScanRadius(*) {
    global clickScanRadius
    clickScanRadius := Integer(scanRadiusEdit.Value)
}

UpdateClickCooldown(*) {
    global clickCooldown
    clickCooldown := Integer(clickCooldownEdit.Value)
}

UpdateFollowInterval(*) {
    global followInterval
    followInterval := Integer(followIntervalEdit.Value)
    if (scanning) {
        SetTimer(ScanForColor, followInterval)
    }
}

UpdateMouseBuffer(*) {
    global mouseBuffer
    mouseBuffer := Integer(mouseBufferEdit.Value)
}

ApplySettings(*) {
    global recoveryCycleEnabled, autoSellEnabled
    
    UpdateTerrainType()
    UpdateClickDelay()
    UpdateScanRadius()
    UpdateClickCooldown()
    UpdateFollowInterval()
    UpdateMouseBuffer()

    guiValues := MyGui.Submit(false)
    recoveryCycleEnabled := guiValues.RecoveryToggle
    autoSellEnabled := guiValues.AutoSellToggle
    
    ToolTip("Settings applied", 10, 30)
    SetTimer(() => ToolTip(), -1000)
}

CheckAutoSell() {
    global autoSellEnabled, recoveryCycleCount, lastAutoSellCycle
    
    if (!autoSellEnabled) {
        return
    }
    
    if (recoveryCycleCount >= lastAutoSellCycle + 5) {
        lastAutoSellCycle := recoveryCycleCount
        
        ToolTip("Auto Sell activated!", 10, 70)
        
        Send "g"
        Sleep 500
        MouseMove 1254, 618
        Sleep 500
        Click
        Sleep 300
        Send "g"
        
        ToolTip("Auto Sell completed", 10, 70)
        SetTimer(() => ToolTip(), -3000)
        
        SaveSettings()
    }
}

F1::
{
    global scanning, followInterval, recoveryCycleEnabled

    SaveSettings()
    ApplySettings()
    
    ToolTip("Running scroll sequence", 10, 10)
    
    if (recoveryCycleEnabled) {
        Loop 18 {
            Send "{WheelUp}"
            Sleep 50
        }
        
        Send "{WheelDown}"
        
        Click
    }
    
    scanning := !scanning
    if (scanning) {
        ToolTip("Scroll sequence completed - Starting color tracking", 10, 10)
        SetTimer(ScanForColor, followInterval)
        if (recoveryCycleEnabled) {
            SetTimer(CheckPixelTimeout, 1000)
        }
    } else {
        ToolTip("Color tracking stopped", 10, 10)
        SetTimer(ScanForColor, 0)
        SetTimer(CheckPixelTimeout, 0)
        SetTimer(() => ToolTip(), -2000)
    }
}

F2::
{
    SaveSettings()
    ToolTip("Reloading script...", 10, 10)
    Sleep 100
    Reload
}

F3:: {
    try {
        MouseGetPos(&mouseX, &mouseY)
        pixelColor := PixelGetColor(mouseX, mouseY)
        A_Clipboard := pixelColor
        MsgBox pixelColor, "Color Copied" , 1
        SetTimer () => TrayTip(), -2000
    } catch as err {
        MsgBox "Error getting color: " err.Message
    }
}

ScanForColor() {
    global scanLeft, scanTop, scanRight, scanBottom, targetColor, scanning
    global clickColors, clickColorVariation, clickScanRadius
    global clickDelay, clickCooldown, lastClickTime, lastFoundX, lastFoundY, mouseBuffer
    global lastPixelFoundTime, recoveryActive, clickLoopActive, recoveryCycleEnabled
    static searchDirection := "RightToLeft"
    
    if (!scanning)
        return

    if (lastFoundX >= scanRight - mouseBuffer) {
        searchDirection := "LeftToRight"
    } 
    else if (lastFoundX <= scanLeft + mouseBuffer) {
        searchDirection := "RightToLeft"
    }

    if (searchDirection = "RightToLeft") {
        startX := scanRight
        endX := scanLeft
    } else {
        startX := scanLeft
        endX := scanRight
    }

    if (PixelSearch(&foundX, &foundY, startX, scanTop, endX, scanBottom, targetColor, 0)) {
        if (recoveryActive) {
            recoveryActive := false
            clickLoopActive := false
            Send "{Right up}"
            if (recoveryCycleEnabled) {
                Send "{WheelDown}"
            }
            ToolTip("Recovery mode ended - Scrolled down", 10, 50)
            SetTimer(() => ToolTip(), -2000)
        }

        lastPixelFoundTime := A_TickCount

        if (Abs(foundX - lastFoundX) > 2 || lastFoundX = 0) {
            MouseMove(foundX, foundY - 30, 0)
            lastFoundX := foundX
            lastFoundY := foundY
        }

        if ((A_TickCount - lastClickTime) >= clickCooldown) {
            mouseX := foundX
            mouseY := foundY - 30

            cLeft := Max(mouseX - clickScanRadius, 0)
            cTop := Max(mouseY - clickScanRadius, 0)
            cRight := Min(mouseX + clickScanRadius, A_ScreenWidth)
            cBottom := Min(mouseY + clickScanRadius, A_ScreenHeight)

            for color in clickColors {
                if (PixelSearch(&cX, &cY, cLeft, cTop, cRight, cBottom, color, clickColorVariation)) {
                    Click(mouseX, mouseY)
                    lastClickTime := A_TickCount
                    break
                }
            }
        }
    }
    else {
        searchDirection := (searchDirection = "RightToLeft") ? "LeftToRight" : "RightToLeft"
    }
}

CheckPixelTimeout() {
    global lastPixelFoundTime, scanning, recoveryActive, clickLoopActive, recoveryCycleEnabled
    global recoveryCycleCount, autoSellEnabled, lastAutoSellCycle
    
    if (!scanning || recoveryActive || !recoveryCycleEnabled)
        return

    if (A_TickCount - lastPixelFoundTime > 7500) {
        recoveryActive := true
        clickLoopActive := true
        recoveryCycleCount++
        UpdateCycleCountDisplay()
        SaveSettings()

        if (autoSellEnabled && recoveryCycleCount >= lastAutoSellCycle + 5) {
            ToolTip("Auto Sell triggered - Pausing before recovery", 10, 70)
            CheckAutoSell()
            
            Sleep 4000
            
            ToolTip("Auto Sell completed - Starting recovery", 10, 70)
            SetTimer(() => ToolTip(), -2000)
        }

        Send "{WheelUp}"
        Sleep 300
        Send "{Right down}"
        SetTimer(RecoveryClickLoop, clickCooldown)
        ToolTip("Pixel not found - Started recovery #" . recoveryCycleCount, 10, 50)
    }
}

RecoveryClickLoop() {
    global recoveryActive, clickLoopActive, clickCooldown, lastPixelFoundTime, recoveryCycleEnabled
    
    if (!recoveryActive || !clickLoopActive || !recoveryCycleEnabled) {
        SetTimer(, 0)
        return
    }

    Click
    lastPixelFoundTime := A_TickCount

    if (A_TickCount - lastPixelFoundTime > 3000) {
        Send "{Right down}"
    }
}
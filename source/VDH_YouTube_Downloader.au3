#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Res_Comment=nothing
#AutoIt3Wrapper_Res_Description=This software allows you to search YouTube, download videos, or even play videos if you want. I created this software to help you conveniently watch YouTube videos without worrying about where to listen to them.
#AutoIt3Wrapper_Res_Fileversion=1.2
#AutoIt3Wrapper_Res_ProductName=Vdh_youtube_downloader+
#AutoIt3Wrapper_Res_ProductVersion=1.2
#AutoIt3Wrapper_Res_CompanyName=vdh productions
#AutoIt3Wrapper_Res_LegalCopyright=copyright 2026 by vdh productions
#AutoIt3Wrapper_Res_LegalTradeMarks=nothing
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=None
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <GUIConstants.au3>
#include <ColorConstants.au3>
#include <GuiListBox.au3>
#include <WindowsConstants.au3>
#include <Constants.au3>
#include <Misc.au3>
#include <Array.au3>
#include <GuiMenu.au3>

Global $version = "1.2"
Global $YT_DLP_PATH = @ScriptDir & "\lib\yt-dlp.exe"
Global $DESC_EXE_PATH = @ScriptDir & "\lib\description.exe" ; Định nghĩa đường dẫn file python exe
Global $dll = DllOpen("user32.dll")

Global $aSearchIds[1]
Global $aSearchTitles[1]
Global $sCurrentKeyword = ""
Global $iTotalLoaded = 0
Global $bIsSearching = False
Global $bEndReached = False
Global $g_bAutoPlay = True

Global $mainform
Global $edit, $cbo_dl_format, $btn_start_dl, $openbtn, $paste
Global $linkedit, $play_btn, $online_play_btn
Global $inp_search, $btn_search_go, $lst_results, $btn_search_hist
Global $hCurrentSubGui = 0
Global $hResultsGui = 0 
Global $hFavoritesGui = 0 
Global $hHistoryGui = 0
Global $hSearchHistoryGui = 0

Global $FAVORITES_FILE = @ScriptDir & "\favorites.dat"
Global $HISTORY_FILE = @ScriptDir & "\watch_history.dat"
Global $SEARCH_HISTORY_FILE = @ScriptDir & "\search_history.dat"

; Migrate old history if it exists
If FileExists(@ScriptDir & "\history.dat") And Not FileExists($HISTORY_FILE) Then
    FileMove(@ScriptDir & "\history.dat", $HISTORY_FILE)
EndIf

If Not FileExists("download") Then DirCreate("download")

If Not FileExists($YT_DLP_PATH) Then
    MsgBox(16, "Error", "The file lib\yt-dlp.exe does not exist!" & @CRLF & "Please double-check the lib folder.")
EndIf

$lding=GUICreate("loading",300,300)
GUISetBkColor($COLOR_BLUE)
GuiCtrlCreateLabel("Welcome to VDH Productions", 10, 25)
GUISetState()
SoundPlay("sounds/start.wav")
Sleep(6000) 
GUIDelete($lding)

$mainform = GUICreate("VDH_YouTube_Downloader version" & $version, 300, 250)
GUISetBkColor($COLOR_BLUE)
GUISetFont(9, 400, 0, "Segoe UI")

GUICtrlCreateLabel("Press the Alt key to go the help menu, then press tab to quick access.", 10, 20, 280, 30, $SS_CENTER)
GUICtrlSetFont(-1, 14, 800)
GUICtrlSetColor(-1, 0xFFFFFF)

Global $btn_Menu_DL = GUICtrlCreateButton("Download YouTube link (Alt+D)", 50, 70, 200, 40)
Global $btn_Menu_PL = GUICtrlCreateButton("Play YouTube link (Alt+P)", 50, 120, 200, 40)
Global $btn_Menu_SC = GUICtrlCreateButton("Search on YouTube (Alt+S)", 50, 170, 200, 40)
Global $btn_Menu_FV = GUICtrlCreateButton("Favorite Videos (Alt+F)", 50, 210, 100, 40)
Global $btn_Menu_HS = GUICtrlCreateButton("Watch History (Alt+H)", 150, 210, 100, 40)

Global $menu = GUICtrlCreateMenu("Help")
Global $menu_about = GUICtrlCreateMenuItem("About...", $menu)
Global $menu_readme = GUICtrlCreateMenuItem("Readme...", $menu)
Global $menu_contact = GUICtrlCreateMenuItem("Contact...", $menu)
Global $menu_update_ytdlp = GUICtrlCreateMenuItem("Checked for updates &yt_dlp...", $menu)
Global $menu_Update_app = GUICtrlCreateMenuItem("Checked for &Updates...", $menu)
Global $menu_exit = GUICtrlCreateMenuItem("Exit...", $menu)
Global $menuChangelog = GuiCtrlCreateMenuItem("view changelog...", $menu)

GUISetState(@SW_SHOW, $mainform)

Local $hDummyUpdateApp = GUICtrlCreateDummy()
Local $hDummyUpdateYTDLP = GUICtrlCreateDummy()
Local $hDummyReadme = GUICtrlCreateDummy()

Local $aAccel[8][2] = [ _
    ["^+u", $hDummyUpdateApp], _
    ["^+y", $hDummyUpdateYTDLP], _
    ["{F1}", $hDummyReadme], _
    ["!d", $btn_Menu_DL], _
    ["!p", $btn_Menu_PL], _
    ["!s", $btn_Menu_SC], _
    ["!f", $btn_Menu_FV], _
    ["!h", $btn_Menu_HS] _
]
GUISetAccelerators($aAccel, $mainform)

_AutoDetectClipboardLink()

While 1
    Local $msg = GUIGetMsg()
    Switch $msg
        Case $GUI_EVENT_CLOSE, $menu_exit
            SoundPlay(@ScriptDir & "\sounds\exit.wav", 1)
            DllClose($dll)
            Exit

        Case $btn_Menu_DL
            SoundPlay("sounds/enter.wav")
            _ShowDownloader()

        Case $btn_Menu_PL
            SoundPlay("sounds/enter.wav")
            _ShowPlayer()

        Case $btn_Menu_SC
            SoundPlay("sounds/enter.wav")
            _ShowSearch()

        Case $btn_Menu_FV
            SoundPlay("sounds/enter.wav")
            _ShowFavorites()

        Case $btn_Menu_HS
            SoundPlay("sounds/enter.wav")
            _ShowHistory()

        Case $menu_about
            SoundPlay("sounds/enter.wav")
            _Show_About_Window()
        Case $menu_readme
            SoundPlay("sounds/enter.wav")
            _Show_Readme_Window()
        Case $menu_contact
            SoundPlay("sounds/enter.wav")
            _Show_Contact_Window()
        Case $menu_update_ytdlp
            SoundPlay("sounds/enter.wav")
            _Check_YTDLP_Update()
        Case $menu_Update_app, $hDummyUpdateApp
            SoundPlay("sounds/enter.wav")
            _CheckGithubUpdate()
        Case $menuChangelog
            SoundPlay("sounds/enter.wav")
            _ShowChangelog()
        Case $hDummyUpdateYTDLP
            SoundPlay("sounds/enter.wav")
            _Check_YTDLP_Update()
        Case $hDummyReadme
            SoundPlay("sounds/enter.wav")
            _Show_Readme_Window()
    EndSwitch
WEnd

Func _ShowDownloader()
    GUISetState(@SW_HIDE, $mainform)
    Local $hGuiDL = GUICreate("YouTube Downloader", 400, 300)
    GUISetBkColor($COLOR_BLUE)

    GUICtrlCreateLabel("Enter the URL link of the video you want to download here:", 10, 20, 380, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    $edit = GUICtrlCreateInput("", 10, 45, 380, 20)
    Local $clip = ClipGet()
    If StringInStr($clip, "youtube.com") Or StringInStr($clip, "youtu.be") Then GUICtrlSetData($edit, $clip)

    $paste = GUICtrlCreateButton("Paste Link (Alt+P)", 320, 75, 70, 20)

    GUICtrlCreateLabel("Select Format:", 10, 75, 200, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    $cbo_dl_format = GUICtrlCreateCombo("Video MP4 (Best)", 10, 100, 280, 20)
    GUICtrlSetData(-1, "Video WebM|Audio MP3|Audio M4A|Audio WAV")

    $btn_start_dl = GUICtrlCreateButton("Download (Alt+D)", 10, 150, 380, 40)
    $openbtn = GUICtrlCreateButton("Open Download Folder (Alt+O)", 10, 200, 380, 30)

    Local $aAccelDL[3][2] = [["!p", $paste], ["!d", $btn_start_dl], ["!o", $openbtn]]
    GUISetAccelerators($aAccelDL, $hGuiDL)

    GUISetState(@SW_SHOW, $hGuiDL)

    While 1
        Local $nMsg = GUIGetMsg()
        Switch $nMsg
            Case $GUI_EVENT_CLOSE
                GUIDelete($hGuiDL)
                GUISetState(@SW_SHOW, $mainform)
                ExitLoop

            Case $paste
                GUICtrlSetData($edit, ClipGet())

            Case $openbtn
                ShellExecute(@ScriptDir & "\download")

            Case $btn_start_dl
                Local $url = GUICtrlRead($edit)
                If $url = "" Then
                    MsgBox(16, "Error", "Please enter the URL!")
                Else
                    Local $sTxt = GUICtrlRead($cbo_dl_format)
                    Local $sFmt = ""

                    If StringInStr($sTxt, "MP3") Then
                        $sFmt = "-x --audio-format mp3"
                    ElseIf StringInStr($sTxt, "WAV") Then
                        $sFmt = "-x --audio-format wav"
                    ElseIf StringInStr($sTxt, "M4A") Then
                        $sFmt = "-x --audio-format m4a"
                    ElseIf StringInStr($sTxt, "WebM") Then
                        $sFmt = "bestvideo+bestaudio --merge-output-format webm"
                    Else
                        $sFmt = "-f bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
                    EndIf

                    Local $sExtraArgs = ""
                    If StringInStr($url, "watch?v=") And StringInStr($url, "list=") Then
                        $sExtraArgs = " --no-playlist"
                    EndIf

                    GUICtrlSetState($btn_start_dl, $GUI_DISABLE)
                    Local $iPidDL = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" ' & $sFmt & $sExtraArgs & ' -o "download/%(title)s.%(ext)s" "' & $url & '""', @ScriptDir, @SW_SHOW)
                    While ProcessExists($iPidDL)
                        Local $m = GUIGetMsg()
                        If $m = $GUI_EVENT_CLOSE Then
                            ProcessClose($iPidDL)
                            GUIDelete($hGuiDL)
                            GUISetState(@SW_SHOW, $mainform)
                            Return
                        EndIf
                        Sleep(10)
                    WEnd
                    GUICtrlSetState($btn_start_dl, $GUI_ENABLE)
                    MsgBox(64, "Info", "Download Complete!")
                EndIf
        EndSwitch
    WEnd
EndFunc

Func _ShowPlayer()
    GUISetState(@SW_HIDE, $mainform)
    Local $hGuiPL = GUICreate("YouTube Player", 400, 250)
    GUISetBkColor($COLOR_BLUE)

    GUICtrlCreateLabel("Enter the video link you want to play:", 10, 20, 380, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    $linkedit = GUICtrlCreateInput("", 10, 50, 380, 20)

    $play_btn = GUICtrlCreateButton("Play (Default Player) (Alt+P)", 50, 80, 300, 35)
    $audio_play_btn = GUICtrlCreateButton("Play as Audio (Alt+A)", 50, 125, 300, 35)
    $online_play_btn = GUICtrlCreateButton("Play in Browser (Alt+B)", 50, 170, 300, 35)

    Local $aAccelPL[3][2] = [["!p", $play_btn], ["!a", $audio_play_btn], ["!b", $online_play_btn]]
    GUISetAccelerators($aAccelPL, $hGuiPL)

    GUISetState(@SW_SHOW, $hGuiPL)

    While 1
        Local $nMsg = GUIGetMsg()
        Switch $nMsg
            Case $GUI_EVENT_CLOSE
                GUIDelete($hGuiPL)
                GUISetState(@SW_SHOW, $mainform)
                ExitLoop

            Case $play_btn
                Local $input_text = GUICtrlRead($linkedit)
                If $input_text <> "" Then playmedia($input_text)

            Case $audio_play_btn
                Local $input_text = GUICtrlRead($linkedit)
                If $input_text <> "" Then playaudio($input_text)

            Case $online_play_btn
                Local $input_text = GUICtrlRead($linkedit)
                If $input_text <> "" Then online_play($input_text)
        EndSwitch
    WEnd
EndFunc

Func _ShowSearch()
    GUISetState(@SW_HIDE, $mainform)
    $hCurrentSubGui = GUICreate("Search", 400, 120)
    GUISetBkColor($COLOR_BLUE)

    GUICtrlCreateLabel("Enter keyword to search:", 10, 15, 80, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    $inp_search = GUICtrlCreateInput("", 100, 12, 210, 20)
    $btn_search_go = GUICtrlCreateButton("Search (Alt+S)", 320, 10, 70, 25)
    GUICtrlSetState(-1, $GUI_DEFBUTTON)

    $btn_search_hist = GUICtrlCreateButton("Search History (Alt+H)", 100, 50, 210, 30)

    Local $aAccelSC[2][2] = [["!s", $btn_search_go], ["!h", $btn_search_hist]]
    GUISetAccelerators($aAccelSC, $hCurrentSubGui)

    GUISetState(@SW_SHOW, $hCurrentSubGui)

    While 1
        Local $nMsg = GUIGetMsg()

        Switch $nMsg
            Case $GUI_EVENT_CLOSE
                $hCurrentSubGui = 0
                GUIDelete()
                GUISetState(@SW_SHOW, $mainform)
                ExitLoop

            Case $btn_search_go
                $sCurrentKeyword = GUICtrlRead($inp_search)
                If $sCurrentKeyword <> "" Then
                    _AddSearchHistory($sCurrentKeyword)
                    _ShowSearchResultsWindow($sCurrentKeyword)
                EndIf

            Case $btn_search_hist
                _ShowSearchHistoryWindow()
        EndSwitch
    WEnd
EndFunc

Func _AddSearchHistory($sKeyword)
    If $sKeyword = "" Then Return
    
    Local $sContent = ""
    If FileExists($SEARCH_HISTORY_FILE) Then
        $sContent = FileRead(FileOpen($SEARCH_HISTORY_FILE, 0 + 256))
    EndIf
    
    Local $aLines = StringSplit(StringStripCR($sContent), @LF)
    Local $sNewContent = ""
    
    For $i = 1 To $aLines[0]
        If $aLines[$i] <> "" And $aLines[$i] <> $sKeyword Then
            $sNewContent &= $aLines[$i] & @CRLF
        EndIf
    Next
    
    $sNewContent &= $sKeyword & @CRLF
    
    Local $hFile = FileOpen($SEARCH_HISTORY_FILE, 2 + 256)
    FileWrite($hFile, $sNewContent)
    FileClose($hFile)
EndFunc

Func _ShowSearchHistoryWindow()
    GUISetState(@SW_HIDE, $hCurrentSubGui)

    $hSearchHistoryGui = GUICreate("Search History", 350, 450)
    GUISetBkColor($COLOR_BLUE)
    
    Local $lst_hist = GUICtrlCreateList("", 10, 10, 330, 350, BitOR($LBS_NOTIFY, $WS_VSCROLL, $WS_BORDER))
    
    Local $btn_remove = GUICtrlCreateButton("Delete From History", 10, 370, 160, 30)
    Local $btn_clear = GUICtrlCreateButton("Clear All History", 180, 370, 160, 30)
    Local $btn_back = GUICtrlCreateButton("Go Back", 10, 410, 330, 30)

    GUISetState(@SW_SHOW, $hSearchHistoryGui)

    _LoadSearchHistoryList($lst_hist)

    While 1
        Local $nMsg = GUIGetMsg()
        
        If (_IsPressed("0D", $dll) And WinActive($hSearchHistoryGui) And ControlGetHandle($hSearchHistoryGui, "", ControlGetFocus($hSearchHistoryGui)) = GUICtrlGetHandle($lst_hist)) Then
            Local $sSelected = _GUICtrlListBox_GetText($lst_hist, _GUICtrlListBox_GetCurSel($lst_hist))
            If $sSelected <> "" Then
                GUIDelete($hSearchHistoryGui)
                $sCurrentKeyword = $sSelected
                GUICtrlSetData($inp_search, $sCurrentKeyword)
                _ShowSearchResultsWindow($sCurrentKeyword)
                Return
            EndIf
            Do
                Sleep(10)
            Until Not _IsPressed("0D", $dll)
        EndIf

        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $btn_back
                GUIDelete($hSearchHistoryGui)
                GUISetState(@SW_SHOW, $hCurrentSubGui)
                Return

            Case $btn_remove
                Local $iIndex = _GUICtrlListBox_GetCurSel($lst_hist)
                If $iIndex <> -1 Then
                    Local $sTxt = _GUICtrlListBox_GetText($lst_hist, $iIndex)
                    _RemoveSearchHistoryItem($sTxt)
                    _GUICtrlListBox_DeleteString($lst_hist, $iIndex)
                EndIf
                
            Case $btn_clear
                If MsgBox(36, "Confirm", "Are you sure you want to delete all search history?") = 6 Then
                    FileDelete($SEARCH_HISTORY_FILE)
                    GUICtrlSetData($lst_hist, "")
                EndIf
        EndSwitch
    WEnd
EndFunc

Func _LoadSearchHistoryList($hListCtrl)
    GUICtrlSetData($hListCtrl, "")
    If Not FileExists($SEARCH_HISTORY_FILE) Then Return
    
    Local $sContent = FileRead(FileOpen($SEARCH_HISTORY_FILE, 0 + 256))
    Local $aLines = StringSplit(StringStripCR($sContent), @LF)
    
    For $i = $aLines[0] To 1 Step -1
        If $aLines[$i] <> "" Then
            _GUICtrlListBox_AddString($hListCtrl, $aLines[$i])
        EndIf
    Next
EndFunc

Func _RemoveSearchHistoryItem($sKeyword)
    Local $sContent = FileRead(FileOpen($SEARCH_HISTORY_FILE, 0 + 256))
    Local $aLines = StringSplit(StringStripCR($sContent), @LF)
    Local $sNewContent = ""
    
    For $i = 1 To $aLines[0]
        If $aLines[$i] <> "" And $aLines[$i] <> $sKeyword Then
            $sNewContent &= $aLines[$i] & @CRLF
        EndIf
    Next
    
    Local $hFile = FileOpen($SEARCH_HISTORY_FILE, 2 + 256)
    FileWrite($hFile, $sNewContent)
    FileClose($hFile)
EndFunc

Func _ShowSearchResultsWindow($sKeyword)
    GUISetState(@SW_HIDE, $hCurrentSubGui)

    $hResultsGui = GUICreate("Search Results", 400, 440)
    GUISetBkColor($COLOR_BLUE)
    $lst_results = GUICtrlCreateList("", 10, 10, 380, 380, BitOR($LBS_NOTIFY, $WS_VSCROLL, $WS_BORDER))
    Local $btn_return_main = GUICtrlCreateButton("return to main window", 10, 400, 380, 30)

    Local $dummy_copy = GUICtrlCreateDummy()
    Local $dummy_browser = GUICtrlCreateDummy()
    Local $dummy_channel = GUICtrlCreateDummy()
    Local $aAccel[3][2] = [["^k", $dummy_copy], ["!b", $dummy_browser], ["!g", $dummy_channel]]
    GUISetAccelerators($aAccel, $hResultsGui)

    GUISetState(@SW_SHOW, $hResultsGui)

    _SearchYouTube($sKeyword, False)

    While 1
        Local $nMsg = GUIGetMsg()

        If _IsPressed("0D", $dll) And WinActive($hResultsGui) Then
            If ControlGetHandle($hResultsGui, "", ControlGetFocus($hResultsGui)) = GUICtrlGetHandle($lst_results) Then
                _ShowContextMenu()
                Do
                    Sleep(10)
                Until Not _IsPressed("0D", $dll)
            EndIf
        EndIf

        Local $iIndex = _GUICtrlListBox_GetCurSel($lst_results)
        Local $iCount = _GUICtrlListBox_GetCount($lst_results)
        If $iIndex <> -1 And $iIndex = $iCount - 1 And Not $bIsSearching And $sKeyword <> "" And Not _IsPressed("0D", $dll) And Not $bEndReached Then
            _SearchYouTube($sKeyword, True)
        EndIf

        Switch $nMsg
            Case $GUI_EVENT_CLOSE
                GUIDelete($hResultsGui)
                $hResultsGui = 0
                GUISetState(@SW_SHOW, $hCurrentSubGui)
                Return
            Case $btn_return_main
                GUIDelete($hResultsGui)
                $hResultsGui = 0
                GUISetState(@SW_SHOW, $mainform)
                Return
            Case $dummy_copy
                _Action_CopyLink(_GUICtrlListBox_GetCurSel($lst_results))
            Case $dummy_browser
                _Action_OpenBrowser(_GUICtrlListBox_GetCurSel($lst_results))
            Case $dummy_channel
                _Action_GoChannel(_GUICtrlListBox_GetCurSel($lst_results))
        EndSwitch
    WEnd
EndFunc

Func _SearchYouTube($sKeyword, $bAppend)
    $bIsSearching = True

    Local $hWaitGui = 0
    If Not $bAppend Then
        $hWaitGui = GUICreate("Searching...", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW), $hResultsGui)
        GUICtrlCreateLabel("Searching YouTube for: " & StringLeft($sKeyword, 20) & "...", 10, 25, 230, 20, $SS_CENTER)
        GUISetBkColor(0xFFFFFF, $hWaitGui)
        GUISetState(@SW_SHOW, $hWaitGui)
        GUISetCursor(15, 1)
    EndIf

    Local $iStart = $bAppend ? $iTotalLoaded + 1 : 1
    Local $iFetch = 20
    Local $iEnd = $iStart + $iFetch - 1

    Local $sEscapedKeyword = StringReplace($sKeyword, '"', '\"')
    Local $sSearchQuery = "ytsearch" & $iEnd & ":" & $sEscapedKeyword
    ; Improved params: filter live streams, suppress some errors, and use more robust printing
    Local $sParams = '--flat-playlist --print "T:%(title)s" --print "I:%(id)s" --print "D:%(duration_string)s" --print "U:%(uploader)s" --match-filter "!is_live" --playlist-start ' & $iStart & ' --playlist-end ' & $iEnd & ' --no-warnings --encoding utf-8 "' & $sSearchQuery & '"'

    Local $iPID = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" ' & $sParams & '"', @ScriptDir, @SW_HIDE, $STDOUT_CHILD)

    Local $bData = Binary("")
    While ProcessExists($iPID)
        $bData &= StdoutRead($iPID, False, True)
        Sleep(10)
    WEnd
    $bData &= StdoutRead($iPID, False, True)

    Local $sOutput = BinaryToString($bData, 4)

    If Not $bAppend Then
        GUICtrlSetData($lst_results, "")
        Global $aSearchIds[1]
        Global $aSearchTitles[1]
        $iTotalLoaded = 0
        $bEndReached = False
    EndIf

    Local $iLoadedBefore = $iTotalLoaded
    Local $aLines = StringSplit(StringStripCR($sOutput), @LF)

    If $aLines[0] > 0 Then
        Local $sCurrentTitle = "", $sCurrentId = "", $sCurrentDur = "", $sCurrentUp = ""
        
        ; Efficiently ReDim in chunks to avoid excessive ReDimming
        Local $iInitialCount = UBound($aSearchIds)
        ReDim $aSearchIds[$iInitialCount + $aLines[0]]
        ReDim $aSearchTitles[$iInitialCount + $aLines[0]]
        Local $iCount = $iInitialCount

        For $i = 1 To $aLines[0]
            Local $sLine = StringStripWS($aLines[$i], 3)
            If $sLine = "" Then ContinueLoop

            If StringLeft($sLine, 2) = "T:" Then
                $sCurrentTitle = StringTrimLeft($sLine, 2)
            ElseIf StringLeft($sLine, 2) = "I:" Then
                $sCurrentId = StringTrimLeft($sLine, 2)
            ElseIf StringLeft($sLine, 2) = "D:" Then
                $sCurrentDur = StringTrimLeft($sLine, 2)
                If $sCurrentDur == "NA" Then $sCurrentDur = "Live/N/A"
            ElseIf StringLeft($sLine, 2) = "U:" Then
                $sCurrentUp = StringTrimLeft($sLine, 2)
            EndIf

            If $sCurrentTitle <> "" And $sCurrentId <> "" And $sCurrentUp <> "" Then
                $iTotalLoaded += 1
                Local $sDisplay = $sCurrentTitle & " [" & $sCurrentDur & "] - " & $sCurrentUp
                _GUICtrlListBox_AddString($lst_results, $sDisplay)

                $aSearchIds[$iCount] = $sCurrentId
                $aSearchTitles[$iCount] = $sCurrentTitle
                
                $iCount += 1
                $sCurrentTitle = ""
                $sCurrentId = ""
                $sCurrentDur = ""
                $sCurrentUp = ""
            EndIf
        Next
        
        ; Shrink arrays to actual size
        ReDim $aSearchIds[$iCount]
        ReDim $aSearchTitles[$iCount]
    EndIf

    If $iTotalLoaded = $iLoadedBefore And $bAppend Then
        $bEndReached = True
    EndIf

    If $iTotalLoaded = 0 And Not $bAppend Then
         MsgBox(16, "Search", "No results found for: " & $sKeyword)
    ElseIf Not $bAppend Then
        SoundPlay(@ScriptDir & "\sounds\result.wav")
    EndIf

    If Not $bAppend And IsHWnd($hWaitGui) Then
        GUIDelete($hWaitGui)
        GUISetCursor(2, 0)
        ControlFocus($hResultsGui, "", $lst_results)
    EndIf

    $bIsSearching = False
EndFunc

Func _ShowContextMenu($bIsFavContext = False)
    Local $iIndex = _GUICtrlListBox_GetCurSel($lst_results)
    If $iIndex = -1 Then Return

    Local $sTitle = $aSearchTitles[$iIndex + 1]

    Local $hMenu = _GUICtrlMenu_CreatePopup()
    
    _GUICtrlMenu_AddMenuItem($hMenu, "Play...", 1001)
    _GUICtrlMenu_AddMenuItem($hMenu, "Play as &audio...", 1002)
    _GUICtrlMenu_AddMenuItem($hMenu, "Download...", 1003)
    _GUICtrlMenu_AddMenuItem($hMenu, "Go to channel...", 1004)
    _GUICtrlMenu_AddMenuItem($hMenu, "Open in Browser...", 1005)
    _GUICtrlMenu_AddMenuItem($hMenu, "Copy Link...", 1006)
    _GUICtrlMenu_AddMenuItem($hMenu, "&Video Description...", 1008)

    Local $sID = $aSearchIds[$iIndex + 1]
    Local $bIsAlreadyFav = _IsFavorite($sID)

    Local $sFavText
    If $bIsFavContext = 1 Then
        $sFavText = "Remove from Favorite..."
    ElseIf $bIsFavContext = 2 Then
        $sFavText = "Delete from &History..."
    Else
        $sFavText = $bIsAlreadyFav ? "Remove from Favorite..." : "Add to &Favorite..."
    EndIf
    _GUICtrlMenu_AddMenuItem($hMenu, $sFavText, 1007)

    Local $iCmd = _GUICtrlMenu_TrackPopupMenu($hMenu, $hResultsGui, MouseGetPos(0), MouseGetPos(1), 1, 1, 2)
    
    _GUICtrlMenu_DestroyMenu($hMenu)

    Switch $iCmd
        Case 1007
            If $bIsFavContext = 1 Or ($bIsFavContext = 0 And $bIsAlreadyFav) Then
                If _RemoveFavorite($sID) Then
                    MsgBox(64, "Success", "Removed from favorites successfully!")
                    Return "REFRESH"
                EndIf
            ElseIf $bIsFavContext = 2 Then
                If _RemoveHistory($sID) Then
                    MsgBox(64, "Success", "Removed from history successfully!")
                    Return "REFRESH"
                EndIf
            Else
                _AddFavorite($sID, $sTitle)
            EndIf
        Case 1001
            _PlayLoop($iIndex, False) ; Video
        Case 1002
            _PlayLoop($iIndex, True) ; Audio
        Case 1003
            _ShowDownloadDialog($aSearchIds[$iIndex + 1], $sTitle)
        Case 1004
            _Action_GoChannel($iIndex)
        Case 1005
            _Action_OpenBrowser($iIndex)
        Case 1006
            _Action_CopyLink($iIndex)
        Case 1008
            _Action_ShowDescription($iIndex)
    EndSwitch
EndFunc

Func _Action_CopyLink($iIndex)
    If $iIndex < 0 Or $iIndex >= UBound($aSearchIds) - 1 Then Return
    Local $sUrl = "https://www.youtube.com/watch?v=" & $aSearchIds[$iIndex + 1]
    ClipPut($sUrl)
    MsgBox(64, "Info", "Link copied to clipboard!")
EndFunc

Func _Action_OpenBrowser($iIndex)
    If $iIndex < 0 Or $iIndex >= UBound($aSearchIds) - 1 Then Return
    ShellExecute("https://www.youtube.com/watch?v=" & $aSearchIds[$iIndex + 1])
EndFunc

Func _Action_ShowDescription($iIndex)
    If $iIndex < 0 Or $iIndex >= UBound($aSearchIds) - 1 Then Return
    Local $sID = $aSearchIds[$iIndex + 1]
    
    If Not FileExists($DESC_EXE_PATH) Then
        MsgBox(16, "Error", "description.exe not found in lib folder!")
        Return
    EndIf

    Local $hWait = GUICreate("Loading...", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW), $hResultsGui)
    GUICtrlCreateLabel("Fetching Description from YouTube...", 10, 25, 230, 20, $SS_CENTER)
    GUISetBkColor(0xFFFFFF, $hWait)
    GUISetState(@SW_SHOW, $hWait)

    Local $iPID = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" --get-description --no-playlist --encoding utf-8 ' & $sID & '"', @ScriptDir, @SW_HIDE, $STDOUT_CHILD)
    Local $bData = Binary("")
    
    While ProcessExists($iPID)
        $bData &= StdoutRead($iPID, False, True) ; True = Binary Mode
        Sleep(10)
    WEnd
    $bData &= StdoutRead($iPID, False, True)
    
    GUIDelete($hWait)
    
    Local $sDesc = BinaryToString($bData, 4) ; 4 = UTF-8

    If $sDesc = "" Then
        MsgBox(64, "Info", "No description available for this video.")
    Else
        Local $sTempFile = @TempDir & "\temp_desc.txt"
        Local $hFile = FileOpen($sTempFile, 2 + 256) ; 2 = Write, 256 = UTF-8 encoding
        FileWrite($hFile, $sDesc)
        FileClose($hFile)

        Run('"' & $DESC_EXE_PATH & '" "' & $sTempFile & '"')
    EndIf
EndFunc

Func _Action_GoChannel($iIndex)
    If $iIndex < 0 Or $iIndex >= UBound($aSearchIds) - 1 Then Return
    Local $sID = $aSearchIds[$iIndex + 1]
    
    Local $hLoading = GUICreate("Working...", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW), $hResultsGui)
    GUICtrlCreateLabel("Fetching channel information...", 10, 25, 230, 20, $SS_CENTER)
    GUISetBkColor(0xFFFFFF, $hLoading)
    GUISetState(@SW_SHOW, $hLoading)

    Local $pid_channel = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" --print "https://www.youtube.com/channel/%(channel_id)s" --no-playlist ' & $sID & '"', @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
    Local $sChannelUrl = ""
    While ProcessExists($pid_channel)
        $sChannelUrl &= StdoutRead($pid_channel)
        Sleep(10)
    WEnd
    $sChannelUrl &= StdoutRead($pid_channel)
    GUIDelete($hLoading)

    $sChannelUrl = StringStripWS($sChannelUrl, 3)
    ; More robust regex for various channel URL formats
    Local $pattern = "(https://www\.youtube\.com/(channel/|@)[^ \r\n]+)"
    Local $aMatch = StringRegExp($sChannelUrl, $pattern, 3)
    
    If IsArray($aMatch) Then
        ShellExecute($aMatch[0])
    Else
        MsgBox(16, "Error", "Cannot get channel URL. The video might be from a deleted channel or restricted.")
    EndIf
EndFunc

Func _PlayLoop($iCurrentIndex, $bAudioOnly = False)
    While 1
        If $iCurrentIndex < 0 Or $iCurrentIndex >= ($iTotalLoaded) Then ExitLoop

        Local $sID = $aSearchIds[$iCurrentIndex + 1]
        Local $sTitle = $aSearchTitles[$iCurrentIndex + 1]

        _AddHistory($sID, $sTitle) ; Save to history when playing

        ; Show Loading Dialog
        Local $hLoading = GUICreate("Playing...", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW), $hResultsGui)
        GUICtrlCreateLabel("Loading stream URL for:" & @CRLF & StringLeft($sTitle, 35) & "...", 10, 15, 230, 40, $SS_CENTER)
        GUISetBkColor(0xFFFFFF, $hLoading)
        GUISetState(@SW_SHOW, $hLoading)
        WinActivate($hLoading)

        Local $sFormat = $bAudioOnly ? "bestaudio" : "best[ext=mp4]/best"
        ; Added --no-playlist, --no-check-certificate, -4 and better error capturing
        Local $pid_url = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" -g -f "' & $sFormat & '" --no-playlist --no-check-certificate -4 ' & $sID & '"', @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
        Local $sUrl = "", $sErr = ""
        While ProcessExists($pid_url)
            $sUrl &= StdoutRead($pid_url)
            $sErr &= StderrRead($pid_url)
            Sleep(10)
        WEnd
        $sUrl &= StdoutRead($pid_url)
        $sErr &= StderrRead($pid_url)
        
        $sUrl = StringStripWS($sUrl, 3)

        If $sUrl = "" Then
            GUIDelete($hLoading)
            Local $sErrMsg = "Cannot get stream URL."
            If StringInStr($sErr, "age restricted") Then
                $sErrMsg &= " This video is age-restricted."
            ElseIf StringInStr($sErr, "private") Then
                $sErrMsg &= " This video is private."
            ElseIf StringInStr($sErr, "not available") Then
                $sErrMsg &= " This video is not available."
            ElseIf $sErr <> "" Then
                $sErrMsg &= " Details: " & StringLeft(StringStripWS($sErr, 3), 100)
            EndIf
            MsgBox(16, "Error", $sErrMsg)
            ExitLoop
        EndIf

        Local $sAction = _PlayInternal($sUrl, $sTitle, $bAudioOnly, $hLoading, True) ; True = Allow AutoPlay toggle

        If $sAction = "NEXT" Or ($sAction = "FINISHED" And $g_bAutoPlay) Then
            $iCurrentIndex += 1
        ElseIf $sAction = "BACK" Then
            $iCurrentIndex -= 1
        Elseif $sAction = "RESTART" Then
            ; Do nothing, loop will restart with same index
        Else
            ; "STOP", "CLOSE", or "FINISHED" (if auto-play is off)
            ExitLoop
        EndIf
    WEnd
EndFunc

Func _ShowDownloadDialog($sID, $sTitle)
    Local $sUrl = "https://www.youtube.com/watch?v=" & $sID
    Local $hDLGui = GUICreate("Download Options", 300, 150, -1, -1, -1, -1)
    GUICtrlCreateLabel("Select Format:", 10, 20, 280, 20)
    Local $cboFormat = GUICtrlCreateCombo("Video MP4 (Best)", 10, 40, 280, 20)
    GUICtrlSetData(-1, "Video WebM|Audio MP3|Audio M4A|Audio WAV")
    Local $btn_DownloadNow = GUICtrlCreateButton("Download", 100, 80, 100, 30)

    GUISetState(@SW_SHOW, $hDLGui)

    While 1
        Local $nMsg = GUIGetMsg()
        If $nMsg = $GUI_EVENT_CLOSE Then
            GUIDelete($hDLGui)
            ExitLoop
        ElseIf $nMsg = $btn_DownloadNow Then
            Local $sTxt = GUICtrlRead($cboFormat)
            GUIDelete($hDLGui)

            Local $sFmt = ""
            If StringInStr($sTxt, "MP3") Then
                $sFmt = "-x --audio-format mp3"
            ElseIf StringInStr($sTxt, "WAV") Then
                $sFmt = "-x --audio-format wav"
            ElseIf StringInStr($sTxt, "M4A") Then
                $sFmt = "-x --audio-format m4a"
            ElseIf StringInStr($sTxt, "WebM") Then
                $sFmt = "bestvideo+bestaudio --merge-output-format webm"
            Else
                $sFmt = "-f bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
            EndIf

            Local $iPidDLNow = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" ' & $sFmt & ' -o "download/%(title)s.%(ext)s" "' & $sUrl & '""', @ScriptDir, @SW_SHOW)
            While ProcessExists($iPidDLNow)
                Local $mDL = GUIGetMsg()
                If $mDL = $GUI_EVENT_CLOSE Then
                    ProcessClose($iPidDLNow)
                    GUIDelete($hDLGui)
                    Return
                EndIf
                Sleep(10)
            WEnd
            MsgBox(64, "Info", "Download Complete!")
            ExitLoop
        EndIf
    WEnd
EndFunc

Func playmedia($url)
    ; Show Loading Dialog (Matching Searching style)
    Local $hLoading = GUICreate("Playing...", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
    GUICtrlCreateLabel("Loading YouTube Video, please wait...", 10, 25, 230, 30, $SS_CENTER)
    GUISetBkColor(0xFFFFFF, $hLoading)
    GUISetState(@SW_SHOW, $hLoading)

    Local $pid = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" -g -f "best" --no-check-certificate -4 "' & $url & '""', @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
    Local $dlink = "", $sErr = ""
    While ProcessExists($pid)
        $dlink &= StdoutRead($pid)
        $sErr &= StderrRead($pid)
    WEnd
    $dlink = StringStripWS($dlink, 3)

    If $dlink <> "" Then
        Local $id = _GetYoutubeID($url)
        Local $sTitle = _GetYoutubeTitle($url)
        If $sTitle = "" Then $sTitle = "YouTube Video"
        _AddHistory($id, $sTitle)
        _PlayInternal($dlink, "YouTube Player", False, $hLoading, False)
    Else
        If $hLoading <> 0 Then GUIDelete($hLoading)
        Local $sErrMsg = "Cannot get video stream from this link."
        If $sErr <> "" Then $sErrMsg &= " Details: " & StringLeft(StringStripWS($sErr, 3), 100)
        MsgBox(16, "Error", $sErrMsg)
    EndIf
EndFunc

Func playaudio($url)
    ; Show Loading Dialog (Matching Searching style)
    Local $hLoading = GUICreate("Playing...", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
    GUICtrlCreateLabel("Loading YouTube Audio, please wait...", 10, 25, 230, 30, $SS_CENTER)
    GUISetBkColor(0xFFFFFF, $hLoading)
    GUISetState(@SW_SHOW, $hLoading)

    Local $pid = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" -g -f "bestaudio" --no-check-certificate -4 "' & $url & '""', @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
    Local $dlink = "", $sErr = ""
    While ProcessExists($pid)
        $dlink &= StdoutRead($pid)
        $sErr &= StderrRead($pid)
    WEnd
    $dlink = StringStripWS($dlink, 3)

    If $dlink <> "" Then
        Local $id = _GetYoutubeID($url)
        Local $sTitle = _GetYoutubeTitle($url)
        If $sTitle = "" Then $sTitle = "YouTube Audio"
        _AddHistory($id, $sTitle)
        _PlayInternal($dlink, "YouTube Audio Player", True, $hLoading, False)
    Else
        If $hLoading <> 0 Then GUIDelete($hLoading)
        Local $sErrMsg = "Cannot get audio stream from this link."
        If $sErr <> "" Then $sErrMsg &= " Details: " & StringLeft(StringStripWS($sErr, 3), 100)
        MsgBox(16, "Error", $sErrMsg)
    EndIf
EndFunc

Func _PlayInternal($sUrl, $sTitle, $bAudioOnly = False, $hLoading = 0, $allowAutoPlayToggle = False)
    Local $iWidth = 640, $iHeight = 360
    If $bAudioOnly Then
        $iWidth = 400
        $iHeight = 150
    EndIf

    Local $hPlayGui = GUICreate($sTitle, $iWidth, $iHeight + 40, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU, $WS_POPUP), $WS_EX_TOPMOST)
    GUISetBkColor(0x000000)

    Local $oWMP = ObjCreate("WMPlayer.OCX.7")
    If Not IsObj($oWMP) Then
        If $hLoading <> 0 Then GUIDelete($hLoading)
        MsgBox(16, "Error", "Windows Media Player ActiveX control could not be created.")
        GUIDelete($hPlayGui)
        Return ""
    EndIf

    GUICtrlCreateObj($oWMP, 0, 0, $iWidth, $iHeight)

    $oWMP.url = $sUrl
    $oWMP.settings.volume = 100
    $oWMP.uiMode = "none"

    Local $lblInfo = GUICtrlCreateLabel("Playing: " & $sTitle, 10, $iHeight + 10, $iWidth - 100, 20)
    GUICtrlSetColor(-1, 0x00FF00)
    Local $lblAuto = GUICtrlCreateLabel("Auto: ON", $iWidth - 80, $iHeight + 10, 70, 20)
    GUICtrlSetColor(-1, 0xFFFF00)
    If (Not $allowAutoPlayToggle) Or (Not $g_bAutoPlay) Then GUICtrlSetState($lblAuto, $GUI_HIDE)
    If $allowAutoPlayToggle And $g_bAutoPlay Then GUICtrlSetData($lblAuto, "Auto: ON")
    If $allowAutoPlayToggle And Not $g_bAutoPlay Then GUICtrlSetData($lblAuto, "Auto: OFF")

    GUISetState(@SW_SHOW, $hPlayGui)

    Local $sAction = ""
    Local $bLoaded = False
    While 1
        Local $nMsg = GUIGetMsg()
        If $nMsg = $GUI_EVENT_CLOSE Then
            $sAction = "CLOSE"
            ExitLoop
        EndIf

        ; Check if loaded to close loading dialog
        If Not $bLoaded And ($oWMP.playState = 3 Or $oWMP.playState = 2) Then ; Playing or Paused
            If $hLoading <> 0 Then
                GUIDelete($hLoading)
                $hLoading = 0
            EndIf
            $bLoaded = True
        EndIf

        ; Space to Toggle Pause/Play - [FIX: Added WinActive]
        If WinActive($hPlayGui) And _IsPressed("20", $dll) Then
            Local $ps = $oWMP.playState
            If $ps = 3 Then ; Playing
                $oWMP.controls.pause()
                _ReportStatus("Paused")
            ElseIf $ps = 2 Or $ps = 1 Then ; Paused or Stopped
                $oWMP.controls.play()
                _ReportStatus("Playing")
            EndIf
            Do
                Sleep(10)
            Until Not _IsPressed("20", $dll)
        EndIf

        ; Enter for Full Screen (Video only) - [FIX: Added WinActive]
        If WinActive($hPlayGui) And Not $bAudioOnly And _IsPressed("0D", $dll) Then
            $oWMP.fullScreen = Not $oWMP.fullScreen
            _ReportStatus($oWMP.fullScreen ? "Full Screen Mode Enable" : "Full Screen Mode Disable")
            Do
                Sleep(10)
            Until Not _IsPressed("0D", $dll)
        EndIf

        ; N to Toggle Auto-Play - [FIX: Added WinActive]
        If WinActive($hPlayGui) And $allowAutoPlayToggle And _IsPressed("4E", $dll) Then ; 'N' key
            $g_bAutoPlay = Not $g_bAutoPlay
            GUICtrlSetData($lblAuto, $g_bAutoPlay ? "Auto: ON" : "Auto: OFF")
            GUICtrlSetState($lblAuto, $g_bAutoPlay ? $GUI_SHOW : $GUI_SHOW)
            _ReportStatus($g_bAutoPlay ? "Auto Play Next Track ON" : "Auto Play Next Track OFF")
            Do
                Sleep(10)
            Until Not _IsPressed("4E", $dll)
        EndIf

        ; Handle shortcuts - [FIX: Added WinActive to all checks]
        If WinActive($hPlayGui) And _IsPressed("26", $dll) Then ; UP ARROW (Volume Up)
            $oWMP.settings.volume = ($oWMP.settings.volume + 10 > 100) ? 100 : $oWMP.settings.volume + 10
            ToolTip("Volume: " & $oWMP.settings.volume, 0, 0)
            AdlibRegister("_ClearToolTip", 1000)
            Do
                Sleep(10)
            Until Not _IsPressed("26", $dll)
        EndIf
        If WinActive($hPlayGui) And _IsPressed("28", $dll) Then ; DOWN ARROW (Volume Down)
            $oWMP.settings.volume = ($oWMP.settings.volume - 10 < 0) ? 0 : $oWMP.settings.volume - 10
            ToolTip("Volume: " & $oWMP.settings.volume, 0, 0)
            AdlibRegister("_ClearToolTip", 1000)
            Do
                Sleep(10)
            Until Not _IsPressed("28", $dll)
        EndIf
        If WinActive($hPlayGui) And _IsPressed("25", $dll) And Not _IsPressed("11", $dll) Then ; LEFT ARROW (Seek Back)
            $oWMP.controls.currentPosition = ($oWMP.controls.currentPosition - 5 < 0) ? 0 : $oWMP.controls.currentPosition - 5
            Do
                Sleep(10)
            Until Not _IsPressed("25", $dll)
        EndIf
        If WinActive($hPlayGui) And _IsPressed("27", $dll) And Not _IsPressed("11", $dll) Then ; RIGHT ARROW (Seek Forward)
            $oWMP.controls.currentPosition = $oWMP.controls.currentPosition + 5
            Do
                Sleep(10)
            Until Not _IsPressed("27", $dll)
        EndIf

        If WinActive($hPlayGui) And _IsPressed("11", $dll) Then ; CTRL Key
            If _IsPressed("25", $dll) Then ; LEFT ARROW (Back)
                $sAction = "BACK"
                ExitLoop
            EndIf
            If _IsPressed("27", $dll) Then ; RIGHT ARROW (Next)
                $sAction = "NEXT"
                ExitLoop
            EndIf
        EndIf

        ; Home Key (Restart track) - [FIX: Added WinActive]
        If WinActive($hPlayGui) And _IsPressed("24", $dll) Then ; Home key
            $oWMP.controls.stop()
            $oWMP.controls.play()
            _ReportStatus("Restart Track")
            Do
                Sleep(10)
            Until Not _IsPressed("24", $dll)
        EndIf

        ; End Key - [FIX: Added WinActive]
        If WinActive($hPlayGui) And _IsPressed("23", $dll) Then ; End
            $sAction = "STOP"
            ExitLoop
        EndIf

        ; Check if finished
        If $oWMP.playState = 1 And $bLoaded Then ; 1 = Stopped
             $sAction = "FINISHED"
             ExitLoop
        EndIf

        Sleep(50)
    WEnd

    If $hLoading <> 0 Then GUIDelete($hLoading)
    $oWMP.controls.stop()
    $oWMP = 0
    GUIDelete($hPlayGui)
    Return $sAction
EndFunc

Func online_play($url)
    ShellExecute($url)
EndFunc

Func _ReportStatus($sText)
    ; Center the ToolTip for better visibility and screen reader detection
    ToolTip($sText, @DesktopWidth / 2, @DesktopHeight / 2, "Status", 1, 1) ; 1 = Balloon, 1 = Center icon
    AdlibRegister("_ClearToolTip", 1500) ; Slightly longer for reading
EndFunc

Func _ClearToolTip()
    ToolTip("")
    AdlibUnRegister("_ClearToolTip")
EndFunc

Func _Show_About_Window()
    Local $gui = GUICreate("About", 520, 300)
    GUISetBkColor($COLOR_BLUE)
    Local $txtAbout = FileExists(@ScriptDir & "\docs\about.txt") ? FileRead(@ScriptDir & "\docs\about.txt") : "VDH YouTube Downloader"
    Local $idEdit = GUICtrlCreateEdit($txtAbout, 10, 10, 400, 280, BitOR($ES_READONLY, $WS_VSCROLL))
    Local $btn_Close = GUICtrlCreateButton("Close", 420, 10, 80, 35)
    GUICtrlSetState(-1, $GUI_DEFBUTTON)

    ; Thiết lập phím tắt để điều hướng giữa các thành phần
    Local $dummy_tab = GUICtrlCreateDummy()
    Local $aAccel[2][2] = [["{TAB}", $dummy_tab], ["+{TAB}", $dummy_tab]]
    GUISetAccelerators($aAccel, $gui)

    GUISetState(@SW_SHOW, $gui)

    While 1
        Local $msg = GUIGetMsg()
        Switch $msg
            Case $GUI_EVENT_CLOSE, $btn_Close
                GUIDelete($gui)
                ExitLoop
            Case $dummy_tab
                ; Chuyển đổi tiêu điểm giữa nút Close và ô nhập liệu
                If ControlGetHandle($gui, "", ControlGetFocus($gui)) = GUICtrlGetHandle($idEdit) Then
                    ControlFocus($gui, "", $btn_Close)
                Else
                    ControlFocus($gui, "", $idEdit)
                EndIf
        EndSwitch
    WEnd
EndFunc

Func _Show_Readme_Window()
    Local $gui = GUICreate("Read Me", 520, 300)
    GUISetBkColor($COLOR_BLUE)
    Local $txtRead = FileExists(@ScriptDir & "\docs\readme.txt") ? FileRead(@ScriptDir & "\docs\readme.txt") : "Read Me"
    Local $idEdit = GUICtrlCreateEdit($txtRead, 10, 10, 400, 280, BitOR($ES_READONLY, $WS_VSCROLL))
    Local $btn_Close = GUICtrlCreateButton("Close", 420, 10, 80, 35)
    GUICtrlSetState(-1, $GUI_DEFBUTTON)

    ; Thiết lập phím tắt để điều hướng giữa các thành phần
    Local $dummy_tab = GUICtrlCreateDummy()
    Local $aAccel[2][2] = [["{TAB}", $dummy_tab], ["+{TAB}", $dummy_tab]]
    GUISetAccelerators($aAccel, $gui)

    GUISetState(@SW_SHOW, $gui)

    While 1
        Local $msg = GUIGetMsg()
        Switch $msg
            Case $GUI_EVENT_CLOSE, $btn_Close
                GUIDelete($gui)
                ExitLoop
            Case $dummy_tab
                ; Chuyển đổi tiêu điểm giữa nút Close và ô nhập liệu
                If ControlGetHandle($gui, "", ControlGetFocus($gui)) = GUICtrlGetHandle($idEdit) Then
                    ControlFocus($gui, "", $btn_Close)
                Else
                    ControlFocus($gui, "", $idEdit)
                EndIf
        EndSwitch
    WEnd
EndFunc

Func _Show_Contact_Window()
    Local $gui = GUICreate("Contact", 300, 200)
    GUISetBkColor($COLOR_BLUE)

    Local $fb = GUICtrlCreateButton("Facebook", 50, 30, 200, 30)
    Local $email = GUICtrlCreateButton("Email", 50, 70, 200, 30)

    GUISetState(@SW_SHOW, $gui)

    While 1
        Local $msg = GUIGetMsg()
        Switch $msg
            Case $GUI_EVENT_CLOSE
                GUIDelete($gui)
                ExitLoop
            Case $fb
                ShellExecute("https://www.facebook.com/profile.php?id=100083295244149")
            Case $email
                ShellExecute("https://mail.google.com/mail/u/0/?fs=1&tf=cm&source=mailto&to=vodinhhungtnlg@gmail.com")
        EndSwitch
    WEnd
EndFunc
Func _GetYoutubeID($url)
    Local $id = ""
    If StringInStr($url, "v=") Then
        $id = StringRegExpReplace($url, ".*v=([^&]*).*", "$1")
    ElseIf StringInStr($url, "youtu.be/") Then
        $id = StringRegExpReplace($url, ".*/([^?]*).*", "$1")
    EndIf
    Return $id
EndFunc

Func _GetYoutubeTitle($url)
    Local $pid = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" --encoding utf-8 --get-title "' & $url & '""', @ScriptDir, @SW_HIDE, $STDOUT_CHILD)
    Local $bData = Binary("")
    While ProcessExists($pid)
        $bData &= StdoutRead($pid, False, True)
        Sleep(10)
    WEnd
    $bData &= StdoutRead($pid, False, True)
    Return StringStripWS(BinaryToString($bData, 4), 3)
EndFunc

Func _AddHistory($sID, $sTitle)
    If $sID = "" Or $sTitle = "" Then Return

    ; Prevent duplicates (optional but good for history)
    Local $sContent = FileRead($HISTORY_FILE)
    If StringInStr($sContent, $sID & "|") Then
        _RemoveHistory($sID) ; Remove old entry to move it to the top
    EndIf

    Local $hFile = FileOpen($HISTORY_FILE, 1 + 8 + 256) ; 1=Append, 8=DirCreate, 256=UTF8
    If $hFile = -1 Then Return
    FileWriteLine($hFile, $sID & "|" & $sTitle)
    FileClose($hFile)
EndFunc

Func _RemoveHistory($sID)
    Local $sContent = FileRead(FileOpen($HISTORY_FILE, 0 + 256)) ; Read as UTF-8
    Local $aLines = StringSplit(StringStripCR($sContent), @LF)
    Local $sNewContent = ""
    Local $bRemoved = False

    For $i = 1 To $aLines[0]
        If $aLines[$i] = "" Then ContinueLoop
        Local $aParts = StringSplit($aLines[$i], "|")
        If $aParts[0] >= 1 And $aParts[1] = $sID Then
            $bRemoved = True
            ContinueLoop
        EndIf
        $sNewContent &= $aLines[$i] & @CRLF
    Next

    If $bRemoved Then
        Local $hFile = FileOpen($HISTORY_FILE, 2 + 256) ; 2=Write, 256=UTF8
        FileWrite($hFile, $sNewContent)
        FileClose($hFile)
        Return True
    EndIf
    Return False
EndFunc

Func _ClearHistory()
    Local $hFile = FileOpen($HISTORY_FILE, 2 + 256) ; 2=Write, 256=UTF8
    If $hFile <> -1 Then
        FileWrite($hFile, "")
        FileClose($hFile)
        Return True
    EndIf
    Return False
EndFunc

Func _AddFavorite($sID, $sTitle)
    Local $hFile = FileOpen($FAVORITES_FILE, 1 + 8 + 256) ; 1=Append, 8=DirCreate, 256=UTF8
    If $hFile = -1 Then
        MsgBox(16, "Error", "Cannot open favorites file.")
        Return
    EndIf
    FileWriteLine($hFile, $sID & "|" & $sTitle)
    FileClose($hFile)
    MsgBox(64, "Success", "Added to favorites successfully!")
EndFunc

Func _RemoveFavorite($sID)
    Local $sContent = FileRead(FileOpen($FAVORITES_FILE, 0 + 256)) ; Read as UTF-8
    Local $aLines = StringSplit(StringStripCR($sContent), @LF)
    Local $sNewContent = ""
    Local $bRemoved = False

    For $i = 1 To $aLines[0]
        If $aLines[$i] = "" Then ContinueLoop
        Local $aParts = StringSplit($aLines[$i], "|")
        If $aParts[0] >= 1 And $aParts[1] = $sID Then
            $bRemoved = True
            ContinueLoop
        EndIf
        $sNewContent &= $aLines[$i] & @CRLF
    Next

    If $bRemoved Then
        Local $hFile = FileOpen($FAVORITES_FILE, 2 + 256) ; 2=Write, 256=UTF8
        FileWrite($hFile, $sNewContent)
        FileClose($hFile)
        Return True
    EndIf
    Return False
EndFunc

Func _ClearFavorites()
    Local $hFile = FileOpen($FAVORITES_FILE, 2 + 256) ; 2=Write, 256=UTF8
    If $hFile <> -1 Then
        FileWrite($hFile, "")
        FileClose($hFile)
        Return True
    EndIf
    Return False
EndFunc

Func _IsFavorite($sID)
    If Not FileExists($FAVORITES_FILE) Then Return False
    Local $sContent = FileRead(FileOpen($FAVORITES_FILE, 0 + 256))
    Return StringInStr($sContent, $sID & "|") > 0
EndFunc


Func _ShowFavorites()
    GUISetState(@SW_HIDE, $mainform)

    ; Increased height to 480 to match History window and fit the extra button comfortably
    $hFavoritesGui = GUICreate("Favorite Videos", 400, 480)
    GUISetBkColor($COLOR_BLUE)
    $lst_results = GUICtrlCreateList("", 10, 10, 380, 380, BitOR($LBS_NOTIFY, $WS_VSCROLL, $WS_BORDER))
    
    Local $btn_clear_fav = GUICtrlCreateButton("Clear all favorites", 10, 400, 380, 30)
    Local $btn_go_back = GUICtrlCreateButton("go back", 10, 440, 380, 30)

    Local $dummy_copy = GUICtrlCreateDummy()
    Local $dummy_browser = GUICtrlCreateDummy()
    Local $dummy_channel = GUICtrlCreateDummy()
    Local $aAccel[3][2] = [["^k", $dummy_copy], ["!b", $dummy_browser], ["!g", $dummy_channel]]
    GUISetAccelerators($aAccel, $hFavoritesGui)

    GUISetState(@SW_SHOW, $hFavoritesGui)

    _LoadFavorites()

    While 1
        Local $nMsg = GUIGetMsg()

        If _IsPressed("0D", $dll) And WinActive($hFavoritesGui) Then
            If ControlGetHandle($hFavoritesGui, "", ControlGetFocus($hFavoritesGui)) = GUICtrlGetHandle($lst_results) Then
                Local $oldResultsGui = $hResultsGui
                $hResultsGui = $hFavoritesGui
                Local $res = _ShowContextMenu(True)
                $hResultsGui = $oldResultsGui
                
                If $res = "REFRESH" Then
                    _LoadFavorites()
                EndIf

                Do
                    Sleep(10)
                Until Not _IsPressed("0D", $dll)
            EndIf
        EndIf

        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $btn_go_back
                GUIDelete($hFavoritesGui)
                $hFavoritesGui = 0
                GUISetState(@SW_SHOW, $mainform)
                Return
            Case $btn_clear_fav
                If MsgBox(36, "Confirm", "Are you sure you want to clear all favorites?") = 6 Then
                    _ClearFavorites()
                    _LoadFavorites()
                EndIf
            Case $dummy_copy
                _Action_CopyLink(_GUICtrlListBox_GetCurSel($lst_results))
            Case $dummy_browser
                _Action_OpenBrowser(_GUICtrlListBox_GetCurSel($lst_results))
            Case $dummy_channel
                _Action_GoChannel(_GUICtrlListBox_GetCurSel($lst_results))
        EndSwitch
    WEnd
EndFunc

Func _LoadFavorites()
    GUICtrlSetData($lst_results, "")
    Local $hFile = FileOpen($FAVORITES_FILE, 0 + 256) ; Read as UTF-8
    Global $aSearchIds[1]
    Global $aSearchTitles[1]
    $iTotalLoaded = 0
    $bEndReached = True ; No pagination for favorites yet

    If $hFile <> -1 Then
        While 1
            Local $sLine = FileReadLine($hFile)
            If @error = -1 Then ExitLoop
            Local $aParts = StringSplit($sLine, "|")
            If $aParts[0] >= 2 Then
                Local $sID = $aParts[1]
                Local $sTitle = $aParts[2]
                $iTotalLoaded += 1
                _GUICtrlListBox_AddString($lst_results, $iTotalLoaded & ". " & $sTitle)
                ReDim $aSearchIds[$iTotalLoaded + 1]
                ReDim $aSearchTitles[$iTotalLoaded + 1]
                $aSearchIds[$iTotalLoaded] = $sID
                $aSearchTitles[$iTotalLoaded] = $sTitle
            EndIf
        WEnd
        FileClose($hFile)
    EndIf


EndFunc

Func _ShowHistory()
    GUISetState(@SW_HIDE, $mainform)

    $hHistoryGui = GUICreate("Watch History", 400, 480)
    GUISetBkColor($COLOR_BLUE)
    $lst_results = GUICtrlCreateList("", 10, 10, 380, 380, BitOR($LBS_NOTIFY, $WS_VSCROLL, $WS_BORDER))
    Local $btn_clear_all = GUICtrlCreateButton("Clear all history", 10, 400, 380, 30)
    Local $btn_go_back = GUICtrlCreateButton("go back", 10, 440, 380, 30)

    Local $dummy_copy = GUICtrlCreateDummy()
    Local $dummy_browser = GUICtrlCreateDummy()
    Local $dummy_channel = GUICtrlCreateDummy()
    Local $aAccel[3][2] = [["^k", $dummy_copy], ["!b", $dummy_browser], ["!g", $dummy_channel]]
    GUISetAccelerators($aAccel, $hHistoryGui)

    GUISetState(@SW_SHOW, $hHistoryGui)

    _LoadHistory()

    While 1
        Local $nMsg = GUIGetMsg()

        If _IsPressed("0D", $dll) And WinActive($hHistoryGui) Then
            If ControlGetHandle($hHistoryGui, "", ControlGetFocus($hHistoryGui)) = GUICtrlGetHandle($lst_results) Then
                Local $oldResultsGui = $hResultsGui
                $hResultsGui = $hHistoryGui
                Local $res = _ShowContextMenu(2) ; 2 = History Context
                $hResultsGui = $oldResultsGui
                
                If $res = "REFRESH" Then
                    _LoadHistory()
                EndIf

                Do
                    Sleep(10)
                Until Not _IsPressed("0D", $dll)
            EndIf
        EndIf

        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $btn_go_back
                GUIDelete($hHistoryGui)
                GUISetState(@SW_SHOW, $mainform)
                Return
            Case $btn_clear_all
                If MsgBox(36, "Confirm", "Are you sure you want to clear all history?") = 6 Then
                    _ClearHistory()
                    _LoadHistory()
                EndIf
            Case $dummy_copy
                _Action_CopyLink(_GUICtrlListBox_GetCurSel($lst_results))
            Case $dummy_browser
                _Action_OpenBrowser(_GUICtrlListBox_GetCurSel($lst_results))
            Case $dummy_channel
                _Action_GoChannel(_GUICtrlListBox_GetCurSel($lst_results))
        EndSwitch
    WEnd
EndFunc

Func _LoadHistory()
    GUICtrlSetData($lst_results, "")
    If Not FileExists($HISTORY_FILE) Then Return

    Local $hFile = FileOpen($HISTORY_FILE, 0 + 256) ; Read as UTF-8
    Local $sContent = FileRead($hFile)
    FileClose($hFile)

    If $sContent = "" Then 
        MsgBox(64, "Info", "No history yet.")
        Return
    EndIf

    Local $aHistoryLines = StringSplit(StringStripCR($sContent), @LF)
    Global $aSearchIds[1]
    Global $aSearchTitles[1]
    $iTotalLoaded = 0
    $bEndReached = True 

    ; Show from newest to oldest
    For $i = $aHistoryLines[0] To 1 Step -1
        Local $sLine = $aHistoryLines[$i]
        If $sLine = "" Then ContinueLoop
        
        Local $iPos = StringInStr($sLine, "|")
        If $iPos > 0 Then
            Local $sID = StringLeft($sLine, $iPos - 1)
            Local $sTitle = StringTrimLeft($sLine, $iPos)
            
            $iTotalLoaded += 1
            _GUICtrlListBox_AddString($lst_results, $iTotalLoaded & ". " & $sTitle)
            
            ReDim $aSearchIds[$iTotalLoaded + 1]
            ReDim $aSearchTitles[$iTotalLoaded + 1]
            $aSearchIds[$iTotalLoaded] = $sID
            $aSearchTitles[$iTotalLoaded] = $sTitle
        EndIf
    Next

    If $iTotalLoaded = 0 Then
        MsgBox(64, "Info", "No history found.")
    EndIf
EndFunc

Func _AutoDetectClipboardLink()
    Local $clip = ClipGet()
    If Not (StringInStr($clip, "youtube.com") Or StringInStr($clip, "youtu.be")) Then Return

    ; Check if focus is in an edit box (per requirement)
    Local $focus = ControlGetFocus($mainform)
    If StringInStr($focus, "Edit") Then Return

    Local $hAutoGui = GUICreate("Link detected", 300, 150, -1, -1, BitOR($WS_CAPTION, $WS_POPUP, $WS_SYSMENU), -1, $mainform)
    GUISetBkColor(0xFFFFFF)
    GUICtrlCreateLabel("A YouTube link was found in your clipboard. What would you like to do?", 10, 10, 280, 40)

    Local $btn_Play = GUICtrlCreateButton("Play", 10, 60, 135, 30)
    Local $btn_DL = GUICtrlCreateButton("Download", 155, 60, 135, 30)
    Local $btn_Cancel = GUICtrlCreateButton("Cancel", 10, 100, 280, 30)

    GUISetState(@SW_SHOW, $hAutoGui)

    While 1
        Local $nMsg = GUIGetMsg()
        Select
            Case $nMsg = $GUI_EVENT_CLOSE Or $nMsg = $btn_Cancel
                GUIDelete($hAutoGui)
                ExitLoop
            Case $nMsg = $btn_Play
                GUIDelete($hAutoGui)
                playmedia($clip)
                ExitLoop
            Case $nMsg = $btn_DL
                GUIDelete($hAutoGui)
                Local $id = _GetYoutubeID($clip)
                If $id <> "" Then
                    Local $sTitle = _GetYoutubeTitle($clip)
                    _ShowDownloadDialog($id, $sTitle)
                Else
                    MsgBox(16, "Error", "Could not extract video ID from link.")
                EndIf
                ExitLoop
        EndSelect
    WEnd
EndFunc
Func _Check_YTDLP_Update()
    Local $hWait = GUICreate("loading", 300, 300, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
    GUICtrlCreateLabel("Checking for yt-dlp updates, please wait...", 10, 25, 280, 50, $SS_CENTER)
    GUISetBkColor(0xFFFFFF, $hWait)
    GUISetState(@SW_SHOW, $hWait)
    
    Local $iPID = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" --update --simulate"', @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
    Local $sOutput = ""
    While ProcessExists($iPID)
        $sOutput &= StdoutRead($iPID)
        Sleep(10)
    WEnd
    $sOutput &= StdoutRead($iPID)
    GUIDelete($hWait)
    
    If StringInStr($sOutput, "is up to date") Then
        MsgBox(64, "yt-dlp Update", "You are already using the latest version of yt-dlp.")
    ElseIf StringInStr($sOutput, "Latest version") Or StringInStr($sOutput, "Updating to") Then
        Local $iRes = MsgBox(36, "yt-dlp Update", "A new version of yt-dlp is available. Would you like to update now?")
        If $iRes = 6 Then ; Yes
            Local $hUpd = GUICreate("loading", 300, 300, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
            GUICtrlCreateLabel("Updating yt-dlp, please wait...", 10, 25, 280, 50, $SS_CENTER)
            GUISetBkColor(0xFFFFFF, $hUpd)
            GUISetState(@SW_SHOW, $hUpd)
            RunWait(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" --update"', @ScriptDir, @SW_HIDE)
            GUIDelete($hUpd)
            MsgBox(64, "Success", "yt-dlp has been updated successfully!")
        EndIf
    Else
        MsgBox(16, "Error", "Could not check for updates. Please check your internet connection." & @CRLF & @CRLF & "Output: " & $sOutput)
    EndIf
EndFunc
Func _CheckGithubUpdate()

    Local $sCheckingText = "Checking for updates..."
    Local $hCheckGUI = GuiCreate("", 300, 80, -1, -1, BitOR($WS_CAPTION, $WS_POPUP), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
    GuiSetBkColor(0xFFFFFF, $hCheckGUI)
    Local $lblCheck = GuiCtrlCreateLabel($sCheckingText, 10, 25, 280, 30, $ES_CENTER)
    GuiCtrlSetFont($lblCheck, 10, 400, 0, "Arial")
    GuiSetState(@SW_SHOW, $hCheckGUI)
    Sleep(3000)
    GuiDelete($hCheckGUI)

    If Ping("github.com", 2000) = 0 And Ping("google.com", 2000) = 0 Then
         MsgBox(48, "Check Update", "No internet connection.")
         Return
    EndIf

    Local $sRepoOwner = "vo-dinh-hung"
    Local $sRepoName = "vdh_youtube_downloader"
    Local $sApiUrl = "https://api.github.com/repos/vo-dinh-hung/vdh_youtube_downloader/releases/latest"

    Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")
    If Not IsObj($oHTTP) Then
        MsgBox(16, "Error", "Cannot create HTTP Object.")
        Return
    EndIf

    $oHTTP.Open("GET", $sApiUrl, False)

    $oHTTP.Send()

    If @error Then
        MsgBox(48, "Check Update", "Connection failed. Please check your internet.")
        Return
    EndIf

    If $oHTTP.Status <> 200 Then
        MsgBox(48, "Check Update", "Cannot connect to update server or no release found." & @CRLF & "Status Code: " & $oHTTP.Status)
        Return
    EndIf

    Local $sResponse = $oHTTP.ResponseText

    Local $aMatch = StringRegExp($sResponse, '"tag_name":\s*"([^"]+)"', 3)

    If IsArray($aMatch) Then
        Local $sLatestVersion = $aMatch[0]
        $sLatestVersion = StringReplace($sLatestVersion, "v", "")
        If $sLatestVersion <> $version Then
            SoundPlay("sounds/update.wav")
            Local $iMsg = MsgBox(36, "Update Available", "A new version (" & $sLatestVersion & ") is available!" & @CRLF & _
                                     "Your version: " & $version & @CRLF & @CRLF & _
                                     "Do you want to download it now?")
            If $iMsg = 6 Then
                $downloadtext = "please wait"
                $downloadGui = GuiCreate("downloading update", 400, 400, -1, -1)
                GuiSetBkColor($COLOR_WHITE)
                GuiCtrlCreateLabel($downloadtext, 40, 60)
                GuiSetState(@SW_SHOW, $downloadGui)
                Local $sDownloadURL = "https://github.com/vo-dinh-hung/vdh_youtube_downloader/releases/latest/download/vdh_youtube_downloader.zip"
                Local $sSavePath = @ScriptDir & "\vdh_youtube_downloader.zip"

                ProgressOn("Downloading Update", "Please wait while downloading...", "0%")

                DllCall("winmm.dll", "int", "PlaySoundW", "wstr", @ScriptDir & "\sounds\updating.wav", "ptr", 0, "dword", 0x0009)

                Local $hDownload = InetGet($sDownloadURL, $sSavePath, 1, 1)

                Do
                    Sleep(100)
                    Local $iBytesRead = InetGetInfo($hDownload, 0)
                    Local $iFileSize = InetGetInfo($hDownload, 1)

                    If $iFileSize > 0 Then
                        Local $iPct = Round(($iBytesRead / $iFileSize) * 100)
                        ProgressSet($iPct, $iPct & "% complete")
                    Else
                        ProgressSet(0, "Connecting...")
                    EndIf

                Until InetGetInfo($hDownload, 2)

                InetClose($hDownload)

                DllCall("winmm.dll", "int", "PlaySoundW", "ptr", 0, "ptr", 0, "dword", 0)

                ProgressOff()
                GuiDelete($downloadGui)

                SoundPlay("sounds/updated.wav")

                MsgBox(64, "Success", "Downloaded successfully!" & @CRLF & "File saved as: " & $sSavePath)
Run("unzip.bat")
                ; ShellExecute($sSavePath)
Exit
            EndIf
        Else
            MsgBox(64, "no update available", "You are using the latest version (" & $version & ").") ; [SỬA LỖI] Đổi $sAppVersion thành $version
        EndIf
    Else
        MsgBox(16, "Error", "Could not parse version information.")
    EndIf
EndFunc
Func _ShowChangelog()
    Local $sFilePath = "docs\changelog.txt"
    Local $sContent = "No changelog found."

    If FileExists($sFilePath) Then
        $sContent = FileRead($sFilePath)
    EndIf

    Local $hChangelogGUI = GuiCreate("Changelog", 400, 450)
    Local $editChangelog = GUICtrlCreateEdit($sContent, 10, 10, 380, 380, BitOR($ES_AUTOVSCROLL, $ES_READONLY, $WS_VSCROLL, $WS_TABSTOP))
    Local $btnClose = GUICtrlCreateButton("&Close", 150, 400, 100, 30, $WS_TABSTOP)

    GuiSetState(@SW_SHOW, $hChangelogGUI)

    While 1
        Switch GuiGetMSG()
            Case $GUI_EVENT_CLOSE, $btnClose
                GuiDelete($hChangelogGUI)
                ExitLoop
        EndSwitch
    WEnd
EndFunc
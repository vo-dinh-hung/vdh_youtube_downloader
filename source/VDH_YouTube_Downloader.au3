#include <GUIConstants.au3>
#include <ColorConstants.au3>
#include <GuiListBox.au3>
#include <WindowsConstants.au3>
#include <Constants.au3>
#include <Misc.au3>
#include <Array.au3>

Global $version = "1.0"
Global $YT_DLP_PATH = @ScriptDir & "\lib\yt-dlp.exe"
Global $FFPLAY_PATH = @ScriptDir & "\lib\ffplay.exe"
Global $dll = DllOpen("user32.dll")

Global $aSearchIds[1]
Global $aSearchTitles[1]
Global $sCurrentKeyword = ""
Global $iTotalLoaded = 0
Global $bIsSearching = False
Global $bEndReached = False

Global $mainform
Global $edit, $cbo_dl_format, $btn_start_dl, $openbtn, $paste
Global $linkedit, $play_btn, $online_play_btn
Global $inp_search, $btn_search_go, $lst_results
Global $hCurrentSubGui = 0
Global $hResultsGui = 0 ; Biến mới cho cửa sổ kết quả

If Not FileExists("download") Then DirCreate("download")

If Not FileExists($YT_DLP_PATH) Then
    MsgBox(16, "Error", "The file lib\yt-dlp.exe does not exist!" & @CRLF & "Please double-check the lib folder.")
EndIf

$lding=GUICreate("loading",300,300)
GuiCtrlCreateLabel("please wait!", 10, 25)
GUISetState()
RunWait(@ComSpec & " /c """ & $YT_DLP_PATH & """ -U", @ScriptDir, @SW_HIDE)
GUIDelete($lding)

$mainform = GUICreate("VDH_YouTube_Downloader+", 300, 250)
GUISetBkColor($COLOR_BLUE)

GUICtrlCreateLabel("Press the Alt key to go the help menu, then press tab to quick access.", 10, 20, 280, 30, $SS_CENTER)
GUICtrlSetFont(-1, 14, 800)
GUICtrlSetColor(-1, 0xFFFFFF)

Global $btn_Menu_DL = GUICtrlCreateButton("&Download YouTube link", 50, 70, 200, 40)
Global $btn_Menu_PL = GUICtrlCreateButton("&Play YouTube link", 50, 120, 200, 40)
Global $btn_Menu_SC = GUICtrlCreateButton("&Search on YouTube", 50, 170, 200, 40)

Global $menu = GUICtrlCreateMenu("Help")
Global $menu_about = GUICtrlCreateMenuItem("&About", $menu)
Global $menu_readme = GUICtrlCreateMenuItem("&Read Me", $menu)
Global $menu_contact = GUICtrlCreateMenuItem("&Contact", $menu)
Global $menu_sep = GUICtrlCreateMenuItem("", $menu) ; Dòng kẻ ngang
Global $menu_exit = GUICtrlCreateMenuItem("E&xit", $menu)

GUISetState(@SW_SHOW, $mainform)

_AutoDetectClipboardLink()

While 1
    Local $msg = GUIGetMsg()
    Switch $msg
        Case $GUI_EVENT_CLOSE, $menu_exit
            DllClose($dll)
            Exit

        Case $btn_Menu_DL
            _ShowDownloader()

        Case $btn_Menu_PL
            _ShowPlayer()

        Case $btn_Menu_SC
            _ShowSearch()

        Case $menu_about
            _Show_About_Window()
        Case $menu_readme
            _Show_Readme_Window()
        Case $menu_contact
            _Show_Contact_Window()
    EndSwitch
WEnd

Func _ShowDownloader()
    GUISetState(@SW_HIDE, $mainform)
    Local $hGuiDL = GUICreate("YouTube Downloader", 400, 300)
    GUISetBkColor($COLOR_BLUE)

    GUICtrlCreateLabel("&Enter the URL link of the video you want to download here:", 10, 20, 380, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    $edit = GUICtrlCreateInput("", 10, 45, 380, 20)
    Local $clip = ClipGet()
    If StringInStr($clip, "youtube.com") Or StringInStr($clip, "youtu.be") Then GUICtrlSetData($edit, $clip)

    $paste = GUICtrlCreateButton("&Paste Link", 320, 75, 70, 20)

    GUICtrlCreateLabel("Select Format:", 10, 75, 200, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    $cbo_dl_format = GUICtrlCreateCombo("Video MP4 (Best)", 10, 100, 280, 20)
    GUICtrlSetData(-1, "Video WebM|Audio MP3|Audio M4A|Audio WAV")

    $btn_start_dl = GUICtrlCreateButton("&Download", 10, 150, 380, 40)
    $openbtn = GUICtrlCreateButton("&Open Download Folder", 10, 200, 380, 30)

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
                    RunWait(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" ' & $sFmt & $sExtraArgs & ' -o "download/%(title)s.%(ext)s" "' & $url & '""', @ScriptDir, @SW_SHOW)
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

    GUICtrlCreateLabel("&Enter the video link you want to play:", 10, 20, 380, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    $linkedit = GUICtrlCreateInput("", 10, 50, 380, 20)

    $play_btn = GUICtrlCreateButton("Play (&Default Player)", 50, 100, 300, 40)
    $online_play_btn = GUICtrlCreateButton("Play in &Browser", 50, 160, 300, 40)

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

            Case $online_play_btn
                Local $input_text = GUICtrlRead($linkedit)
                If $input_text <> "" Then online_play($input_text)
        EndSwitch
    WEnd
EndFunc

Func _ShowSearch()
    GUISetState(@SW_HIDE, $mainform)
    $hCurrentSubGui = GUICreate("Search", 400, 80)
    GUISetBkColor($COLOR_BLUE)

    GUICtrlCreateLabel("&Enter keyword to search:", 10, 15, 80, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    $inp_search = GUICtrlCreateInput("", 100, 12, 210, 20)
    $btn_search_go = GUICtrlCreateButton("&Search", 320, 10, 70, 25)

    GUISetState(@SW_SHOW, $hCurrentSubGui)

    While 1
        Local $nMsg = GUIGetMsg()

        If _IsPressed("0D", $dll) And WinActive($hCurrentSubGui) Then
            If ControlGetHandle($hCurrentSubGui, "", ControlGetFocus($hCurrentSubGui)) = GUICtrlGetHandle($inp_search) Then
                $sCurrentKeyword = GUICtrlRead($inp_search)
                If $sCurrentKeyword <> "" Then
                    _ShowSearchResultsWindow($sCurrentKeyword)
                EndIf
                Do
                    Sleep(10)
                Until Not _IsPressed("0D", $dll)
            EndIf
        EndIf

        Switch $nMsg
            Case $GUI_EVENT_CLOSE
                $hCurrentSubGui = 0
                GUIDelete()
                GUISetState(@SW_SHOW, $mainform)
                ExitLoop

            Case $btn_search_go
                $sCurrentKeyword = GUICtrlRead($inp_search)
                If $sCurrentKeyword <> "" Then
                    _ShowSearchResultsWindow($sCurrentKeyword)
                EndIf
        EndSwitch
    WEnd
EndFunc

Func _ShowSearchResultsWindow($sKeyword)
    GUISetState(@SW_HIDE, $hCurrentSubGui)

    $hResultsGui = GUICreate("Search Results", 400, 400)
    GUISetBkColor($COLOR_BLUE)
    $lst_results = GUICtrlCreateList("", 10, 10, 380, 380, BitOR($LBS_NOTIFY, $WS_VSCROLL, $WS_BORDER))

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
    Local $sParams = '--flat-playlist --print "T:%(title)s" --print "I:%(id)s" --playlist-start ' & $iStart & ' --playlist-end ' & $iEnd & ' --no-warnings --encoding utf-8 "' & $sSearchQuery & '"'

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
        Local $iCount = UBound($aSearchIds)
        Local $sLastTitle = ""
        For $i = 1 To $aLines[0]
            Local $sLine = $aLines[$i]
            If StringLeft($sLine, 2) = "T:" Then
                $sLastTitle = StringTrimLeft($sLine, 2)
            ElseIf StringLeft($sLine, 2) = "I:" And $sLastTitle <> "" Then
                Local $sId = StringTrimLeft($sLine, 2)

                $iTotalLoaded += 1
                _GUICtrlListBox_AddString($lst_results, $iTotalLoaded & ". " & $sLastTitle)

                ReDim $aSearchIds[$iCount + 1]
                ReDim $aSearchTitles[$iCount + 1]
                $aSearchIds[$iCount] = $sId
                $aSearchTitles[$iCount] = $sLastTitle
                $iCount += 1
                $sLastTitle = ""
            EndIf
        Next
    EndIf

    If $iTotalLoaded = $iLoadedBefore And $bAppend Then
        $bEndReached = True
    EndIf

    If $iTotalLoaded = 0 And Not $bAppend Then
         MsgBox(16, "Info", "No results found for: " & $sKeyword)
    EndIf

    If Not $bAppend And IsHWnd($hWaitGui) Then
        GUIDelete($hWaitGui)
        GUISetCursor(2, 0)
        ControlFocus($hResultsGui, "", $lst_results)
    EndIf

    $bIsSearching = False
EndFunc

Func _ShowContextMenu()
    Local $iIndex = _GUICtrlListBox_GetCurSel($lst_results)
    If $iIndex = -1 Then Return

    Local $sTitle = $aSearchTitles[$iIndex + 1]

    ; Popup menu hiện lên trên cửa sổ kết quả ($hResultsGui)
    Local $hMenuGui = GUICreate("Options", 250, 200, -1, -1, BitOR($WS_CAPTION, $WS_POPUP, $WS_SYSMENU), -1, $hResultsGui)
    GUISetBkColor(0xFFFFFF)
    GUICtrlCreateLabel(StringLeft($sTitle, 35) & "...", 10, 10, 230, 20)

    Local $btn_Play = GUICtrlCreateButton("Play", 10, 35, 230, 30)
    Local $btn_DL = GUICtrlCreateButton("Download", 10, 70, 230, 30)
    Local $btn_Web = GUICtrlCreateButton("Open in Browser", 10, 105, 230, 30)
    Local $btn_Copy = GUICtrlCreateButton("Copy Link", 10, 140, 230, 30)

    GUISetState(@SW_SHOW, $hMenuGui)

    While 1
        Local $nMsg = GUIGetMsg()
        Switch $nMsg
            Case $GUI_EVENT_CLOSE
                GUIDelete($hMenuGui)
                ExitLoop
            Case $btn_Play
                GUIDelete($hMenuGui)
                _PlayLoop($iIndex)
                ExitLoop
            Case $btn_DL
                GUIDelete($hMenuGui)
                _ShowDownloadDialog($aSearchIds[$iIndex + 1])
                ExitLoop
            Case $btn_Web
                GUIDelete($hMenuGui)
                ShellExecute("https://www.youtube.com/watch?v=" & $aSearchIds[$iIndex + 1])
                ExitLoop
            Case $btn_Copy
                GUIDelete($hMenuGui)
                Local $sUrl = "https://www.youtube.com/watch?v=" & $aSearchIds[$iIndex + 1]
                ClipPut($sUrl)
                MsgBox(64, "Info", "Link copied to clipboard!")
                ExitLoop
        EndSwitch
    WEnd
EndFunc

Func _PlayLoop($iCurrentIndex)
    While 1
        If $iCurrentIndex < 0 Or $iCurrentIndex >= ($iTotalLoaded) Then ExitLoop

        Local $sID = $aSearchIds[$iCurrentIndex + 1]
        Local $sTitle = $aSearchTitles[$iCurrentIndex + 1]

        Local $pid_url = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" -g -f "best[ext=mp4]/best" ' & $sID & '"', @ScriptDir, @SW_HIDE, $STDOUT_CHILD)
        Local $sUrl = ""
        While ProcessExists($pid_url)
            $sUrl &= StdoutRead($pid_url)
        WEnd
        $sUrl = StringStripWS($sUrl, 3)

        If $sUrl = "" Then
            MsgBox(16, "Error", "Cannot get stream URL.")
            ExitLoop
        EndIf

        Local $iPID_Play = Run('"' & $FFPLAY_PATH & '" -window_title "' & $sTitle & '" -autoexit -infbuf -x 640 -y 360 "' & $sUrl & '"', @ScriptDir, @SW_SHOW)

        Local $hPlayingGui = GUICreate("Now Playing", 300, 70, -1, -1, BitOR($WS_POPUP, $WS_BORDER), $WS_EX_TOPMOST)
        GUICtrlCreateLabel("Playing:", 10, 5, 280, 20)
        GUICtrlSetColor(-1, 0xFFFFFF)
        GUICtrlCreateLabel(StringLeft($sTitle, 40) & "...", 10, 25, 280, 40)
        GUICtrlSetFont(-1, 10, 600)
        GUICtrlSetColor(-1, 0x00FF00) ; Green text
        GUISetBkColor(0x222222, $hPlayingGui)
        GUISetState(@SW_SHOW, $hPlayingGui)

        Local $sAction = ""
        While ProcessExists($iPID_Play)
            If _IsPressed("11", $dll) Then ; CTRL Key
                If _IsPressed("25", $dll) Then ; LEFT ARROW (Back)
                    $sAction = "BACK"
                    ProcessClose($iPID_Play)
                    ExitLoop
                EndIf
                If _IsPressed("27", $dll) Then ; RIGHT ARROW (Next)
                    $sAction = "NEXT"
                    ProcessClose($iPID_Play)
                    ExitLoop
                EndIf
            EndIf
            If _IsPressed("24", $dll) Then ; Home
                _ReportStatus("Start of track")
                $sAction = "RESTART"
                ProcessClose($iPID_Play)
                ExitLoop
            EndIf
            If _IsPressed("23", $dll) Then ; End
                _ReportStatus("End of track")
                $sAction = "END"
                ProcessClose($iPID_Play)
                ExitLoop
            EndIf
            Sleep(50)
        WEnd

        ; --- Xóa hộp thoại Playing khi video tắt ---
        GUIDelete($hPlayingGui)
        ; -------------------------------------------

        If $sAction = "NEXT" Then
            $iCurrentIndex += 1
        ElseIf $sAction = "BACK" Then
            $iCurrentIndex -= 1
        ElseIf $sAction = "RESTART" Then
            ; Do nothing
        ElseIf $sAction = "END" Then
             $iCurrentIndex += 1
        Else
            ExitLoop
        EndIf
    WEnd
EndFunc

Func _ShowDownloadDialog($sID)
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

            RunWait(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" ' & $sFmt & ' -o "download/%(title)s.%(ext)s" "' & $sUrl & '""', @ScriptDir, @SW_SHOW)
            MsgBox(64, "Info", "Download Complete!")
            ExitLoop
        EndIf
    WEnd
EndFunc

Func playmedia($url)
    Local $pid = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" -g -f "best" "' & $url & '""', @ScriptDir, @SW_HIDE, $STDOUT_CHILD)
    ProcessWaitClose($pid)
    Local $dlink = StdoutRead($pid)
    $dlink = StringStripWS($dlink, 3)

    If $dlink <> "" Then
        Local $sCmd = '"' & $FFPLAY_PATH & '" -autoexit -window_title "YouTube Player" -infbuf -x 640 -y 360 "' & $dlink & '"'
        Local $pid_play = Run($sCmd, @ScriptDir, @SW_SHOW)

        Local $hPlayingGui = GUICreate("Playing", 250, 50, -1, -1, BitOR($WS_POPUP, $WS_BORDER), $WS_EX_TOPMOST)
        GUICtrlCreateLabel("Now Playing Video...", 10, 15, 230, 20, $SS_CENTER)
        GUICtrlSetColor(-1, 0xFFFFFF)
        GUISetBkColor(0x222222, $hPlayingGui)
        GUISetState(@SW_SHOW, $hPlayingGui)

        While ProcessExists($pid_play)
            If _IsPressed("24", $dll) Then ; HOME
                _ReportStatus("Start of track")
                ProcessClose($pid_play)
                $pid_play = Run($sCmd, @ScriptDir, @SW_SHOW)
                Do
                    Sleep(10)
                Until Not _IsPressed("24", $dll)
            EndIf
            If _IsPressed("23", $dll) Then ; END
                _ReportStatus("End of track")
                ProcessClose($pid_play)
                ExitLoop
            EndIf
            Sleep(50)
        WEnd

        GUIDelete($hPlayingGui)
    Else
        MsgBox(16, "Error", "Cannot get video stream from this link.")
    EndIf
EndFunc

Func online_play($url)
    ShellExecute($url)
EndFunc

Func _ReportStatus($sText)
    ToolTip($sText, 0, 0, "Info", 1)
    Sleep(1000)
    ToolTip("")
EndFunc

Func _Show_About_Window()
    Local $gui = GUICreate("About", 400, 300)
    GUISetBkColor($COLOR_BLUE)
    Local $txtAbout = FileExists(@ScriptDir & "\data\docs\about.txt") ? FileRead(@ScriptDir & "\data\docs\about.txt") : "VDH YouTube Downloader"
    GUICtrlCreateEdit($txtAbout, 10, 10, 380, 280, BitOR($ES_READONLY, $WS_VSCROLL))
    GUISetState(@SW_SHOW, $gui)

    While 1
        If GUIGetMsg() = $GUI_EVENT_CLOSE Then
            GUIDelete($gui)
            ExitLoop
        EndIf
    WEnd
EndFunc

Func _Show_Readme_Window()
    Local $gui = GUICreate("Read Me", 400, 300)
    GUISetBkColor($COLOR_BLUE)
    Local $txtRead = FileExists(@ScriptDir & "\data\docs\readme.txt") ? FileRead(@ScriptDir & "\data\docs\readme.txt") : "Read Me"
    GUICtrlCreateEdit($txtRead, 10, 10, 380, 280, BitOR($ES_READONLY, $WS_VSCROLL))
    GUISetState(@SW_SHOW, $gui)

    While 1
        If GUIGetMsg() = $GUI_EVENT_CLOSE Then
            GUIDelete($gui)
            ExitLoop
        EndIf
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
                    _ShowDownloadDialog($id)
                Else
                    MsgBox(16, "Error", "Could not extract video ID from link.")
                EndIf
                ExitLoop
        EndSelect
    WEnd
EndFunc

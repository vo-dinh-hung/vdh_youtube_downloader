;#RequireAdmin
#include <GUIConstants.au3>
#include <ColorConstants.au3>
#include <GuiListBox.au3>
#include <WindowsConstants.au3>
#include <Constants.au3>
#include <Misc.au3>
#include <Array.au3>
#include <GuiMenu.au3>
#include <GuiTab.au3>
#include <GuiEdit.au3>
#include <WinAPISys.au3>

FileChangeDir(@ScriptDir)
 ; Ensure working directory is correct, especially for startup with Windows

; Mở khóa UIPI cho toàn bộ tiến trình ngay khi khởi động
Local $aGlobalMsgs = [0x0100, 0x0101, 0x0102, 0x0104, 0x0105, 0x010D, 0x010E, 0x010F, 0x0281, 0x0282, 0x0283, 0x0284, 0x0285, 0x0286, 0x0288, 0x0290, 0x0291, 0x004A, 0x003D, 0x0302, 0x0303, 0x0304, 0x0305]
For $iMsg In $aGlobalMsgs
    DllCall("user32.dll", "bool", "ChangeWindowMessageFilter", "uint", $iMsg, "dword", 1)
Next

Global $version = "1.4"
Global $YTDLP_version = "2026.02.21"
Global $YT_DLP_PATH = @ScriptDir & "\lib\yt-dlp.exe"
Global $DESC_EXE_PATH = @ScriptDir & "\lib\description.exe" ; Định nghĩa đường dẫn file python exe
Global $COMMENTS_EXE_PATH = @ScriptDir & "\lib\comments.exe"
Global $VOICE_SEARCH_EXE_PATH = @ScriptDir & "\lib\voice_search.exe"
Global $g_hNVDADll = -1 ; Handle cho NVDA DLL
Global $oVoice = 0 ; Đối tượng SAPI 5 (Lazy init)

Global $aSearchIds[1]
Global $aSearchTitles[1]
Global $aSearchTypes[1] ; Thêm mảng lưu trữ loại (video/playlist)
Global $sCurrentKeyword = ""
Global $iTotalLoaded = 0
Global $bIsSearching = False
Global $bEndReached = False
Global $g_bAutoPlay = True
Global $g_bRepeat = False
Global $g_iFFStep = 10
Global $g_iRWStep = 10
Global $g_iSeekStep = 10


Global $mainform
Global $edit, $cbo_dl_format, $btn_start_dl, $openbtn, $paste
Global $linkedit, $play_btn, $online_play_btn
Global $inp_search, $btn_search_go, $lst_results, $btn_search_hist
Global $hCurrentSubGui = 0
Global $hResultsGui = 0
Global $hFavoritesGui = 0
Global $hHistoryGui = 0
Global $hSearchHistoryGui = 0
Global $hPlayGui = 0, $oWMP = 0, $oWMPCtrl = 0
Global $g_hStatusLabel = 0, $g_lblPlayerInfo = 0, $g_lblAuto = 0, $g_lblRepeat = 0
Global $menu_item_download = -1, $menu_item_channel = -1, $menu_item_browser = -1, $menu_item_copy = -1, $menu_item_desc = -1, $menu_item_comments = -1, $menu_item_fav = -1, $menu_item_goto = -1
Global $g_fSelectionStart = -1, $g_fSelectionEnd = -1
Global $g_bCinemaMode = False
Global $g_iOriginalX, $g_iOriginalY, $g_iOriginalW, $g_iOriginalH
Global $hDummySpace, $hDummyEnter, $hDummyN, $hDummyUp, $hDummyDown, $hDummyLeft, $hDummyRight, $hDummyAltO
Global $hDummyCtrlLeft, $hDummyCtrlRight, $hDummyCtrlT, $hDummyCtrlShiftT, $hDummyHome, $hDummyEnd
Global $hDummy1, $hDummy2, $hDummy3, $hDummy4, $hDummy5, $hDummy6, $hDummy7, $hDummy8, $hDummy9
Global $hDummyR, $hDummyShiftN, $hDummyShiftB, $hDummyCtrlW, $hDummyMinus, $hDummyEqual, $hDummyS, $hDummyD, $hDummyF, $hDummyCtrlShiftE, $hDummyEsc, $hDummyG, $hDummyApps, $hDummyBracketLeft, $hDummyBracketRight, $hDummyCtrlS, $hDummyCtrlK, $hDummyCtrlC, $hDummyCtrlShiftC, $hDummyCtrlShiftD, $hDummyAltB, $hDummyAltG
Global $g_sLastReportedText = "", $g_iLastReportedTime = 0
Global $g_sCurrentVideoTitle = ""
Global $g_sSearchFilter = "No Filter"
Global $g_hSettingsGui, $g_hSettingsTab, $g_hSettingsDummyNext, $g_hSettingsDummyPrev

Global $SETTINGS_DIR = @AppDataDir & "\VDHYouTubeDownloader"
If Not FileExists($SETTINGS_DIR) Then DirCreate($SETTINGS_DIR)

Global $FAVORITES_FILE = $SETTINGS_DIR & "\favorites.dat"
Global $HISTORY_FILE = $SETTINGS_DIR & "\watch_history.dat"
Global $SEARCH_HISTORY_FILE = $SETTINGS_DIR & "\search_history.dat"
Global $CONFIG_FILE = $SETTINGS_DIR & "\settings.ini"

; Migration logic: Move files from old location to AppData if they exist
Func _MigrateFiles()
    Local $aFilesToMove[3] = ["favorites.dat", "watch_history.dat", "search_history.dat"]
    For $sFile In $aFilesToMove
        If FileExists(@ScriptDir & "\" & $sFile) And Not FileExists($SETTINGS_DIR & "\" & $sFile) Then
            FileMove(@ScriptDir & "\" & $sFile, $SETTINGS_DIR & "\" & $sFile)
        EndIf
    Next
    ; Special case for very old history file
    If FileExists(@ScriptDir & "\history.dat") And Not FileExists($HISTORY_FILE) Then
        FileMove(@ScriptDir & "\history.dat", $HISTORY_FILE)
    EndIf
EndFunc
_MigrateFiles()

; Settings variables
Global $g_bAutoUpdate = IniRead($CONFIG_FILE, "Settings", "AutoUpdate", "1") = "1"
Global $g_bAutoStart = IniRead($CONFIG_FILE, "Settings", "AutoStart", "0") = "1"
Global $g_bSkipSilence = IniRead($CONFIG_FILE, "Settings", "SkipSilence", "0") = "1"
Global $g_bSpeakStatus = IniRead($CONFIG_FILE, "Settings", "SpeakStatus", "1") = "1"
Global $g_iAfterVideoAction = Int(IniRead($CONFIG_FILE, "Settings", "AfterVideoAction", "2")) ; 0: Close, 1: Replay, 2: Do nothing
Global $g_bAutoDetectLink = IniRead($CONFIG_FILE, "Settings", "AutoDetectLink", "1") = "1"
$g_iFFStep = Int(IniRead($CONFIG_FILE, "Settings", "FFStep", "10"))
$g_iRWStep = Int(IniRead($CONFIG_FILE, "Settings", "RWStep", "10"))
$g_iSeekStep = $g_iFFStep

If Not FileExists("download") Then DirCreate("download")

If Not FileExists($YT_DLP_PATH) Then
    MsgBox(16, "Error", "The file lib\yt-dlp.exe does not exist!" & @CRLF & "Please double-check the lib folder.")
EndIf

$lding=GUICreate("loading",300,300)
GUISetBkColor($COLOR_BLUE)
GuiCtrlCreateLabel("Welcome to VDH Productions", 10, 25)
GUISetState()
SoundPlay(@ScriptDir & "\sounds\start.wav")
Sleep(3000)
GUIDelete($lding)

$mainform = GUICreate("VDH_YouTube_Downloader version" & $version, 300, 250)
GUISetBkColor($COLOR_BLUE)
GUISetFont(9, 400, 0, "Segoe UI")

Local $sGreeting = "Good Evening"
If @HOUR >= 0 And @HOUR < 12 Then
    $sGreeting = "Good morning"
ElseIf @HOUR >= 12 And @HOUR < 18 Then
    $sGreeting = "Good afternoon"
ElseIf @HOUR >= 18 And @HOUR < 22 Then
    $sGreeting = "Good evening"
Else
    $sGreeting = "Good night"
EndIf
$label = GUICtrlCreateLabel($sGreeting & " and warm welcome to VDHYouTubeDownloader application.", 10, 20, 280, 50, BitOR($SS_LEFT, $WS_TABSTOP))
GUICtrlSetFont(-1, 14, 800)
GUICtrlSetColor(-1, 0xFFFFFF)

Global $btn_Menu_DL = GUICtrlCreateButton("Download YouTube link (Alt+D)", 50, 70, 200, 40)
Global $btn_Menu_PL = GUICtrlCreateButton("Play YouTube link (Alt+P)", 50, 120, 200, 40)
Global $btn_Menu_SC = GUICtrlCreateButton("Search on YouTube (Alt+S)", 50, 170, 200, 40)
Global $btn_Menu_FV = GUICtrlCreateButton("Favorite Videos (Alt+F)", 50, 210, 100, 40)
Global $btn_Menu_HS = GUICtrlCreateButton("Watch History (Alt+H)", 150, 210, 100, 40)

Global $menu_main = GUICtrlCreateMenu("Main")
Global $menu_settings = GUICtrlCreateMenuItem("Settings... (Ctrl+Shift+S)", $menu_main)
Global $menu_exit = GUICtrlCreateMenuItem("Exit...", $menu_main)

Global $menu_help = GUICtrlCreateMenu("Help")
Global $menu_about = GUICtrlCreateMenuItem("About...", $menu_help)
Global $menu_readme = GUICtrlCreateMenuItem("Readme...", $menu_help)
Global $menu_contact = GUICtrlCreateMenuItem("Contact...", $menu_help)
Global $menu_update_ytdlp = GUICtrlCreateMenuItem("Checked for updates &yt_dlp...", $menu_help)
Global $menu_Update_app = GUICtrlCreateMenuItem("Checked for &Updates...", $menu_help)
Global $menuChangelog = GuiCtrlCreateMenuItem("view changelog...", $menu_help)

GUISetState(@SW_SHOW, $mainform)
_AllowUIPI($mainform)
ControlFocus($mainform, "", $label)

; ... (đoạn mã tiếp theo)

Func _AllowUIPI($hWnd)
    Local $hTarget = IsHWnd($hWnd) ? $hWnd : GUICtrlGetHandle($hWnd)
    ; Danh sách thông điệp: WM_KEYDOWN, WM_KEYUP, WM_CHAR, WM_SYSKEYDOWN, WM_SYSKEYUP, WM_GETOBJECT, WM_COPYDATA, WM_IME_...
    Local $aMessages = [0x0100, 0x0101, 0x0102, 0x0104, 0x0105, 0x003D, 0x004A, 0x010D, 0x010E, 0x010F, 0x0281, 0x0282, 0x0286]
    For $iMsg In $aMessages
        DllCall("user32.dll", "bool", "ChangeWindowMessageFilterEx", "hwnd", $hTarget, "uint", $iMsg, "dword", 1, "ptr", 0)
    Next
EndFunc
Local $hDummyUpdateApp = GUICtrlCreateDummy()
Local $hDummyUpdateYTDLP = GUICtrlCreateDummy()
Local $hDummyReadme = GUICtrlCreateDummy()
Local $hDummyChangelog = GUICtrlCreateDummy()
Local $hDummyEscMain = GUICtrlCreateDummy()
Local $hDummySettings = GUICtrlCreateDummy()

Local $aAccel[12][2] = [ _
    ["^+u", $hDummyUpdateApp], _
    ["^+y", $hDummyUpdateYTDLP], _
    ["{F1}", $hDummyReadme], _
    ["!d", $btn_Menu_DL], _
    ["!p", $btn_Menu_PL], _
    ["!s", $btn_Menu_SC], _
    ["!f", $btn_Menu_FV], _
    ["!h", $btn_Menu_HS], _
    ["{F2}", $hDummyChangelog], _
    ["^w", $menu_exit], _
    ["{ESC}", $hDummyEscMain], _
    ["^+s", $hDummySettings] _
]
GUISetAccelerators($aAccel, $mainform)

If $g_bAutoDetectLink Then _AutoDetectClipboardLink()
_AddDefenderExclusion()

; Auto update check if enabled
If $g_bAutoUpdate Then
    AdlibRegister("_CheckUpdatesSilently", 5000) ; Wait 5s after start to not bother user immediately
EndIf

While 1
    Local $msg = GUIGetMsg()
    Switch $msg
        Case $GUI_EVENT_CLOSE, $menu_exit
            SoundPlay(@ScriptDir & "\sounds\exit.wav", 1)
            ProcessClose("comments.exe")
            ProcessClose("description.exe")
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
        Case $menu_update_ytdlp, $hDummyUpdateYTDLP
            SoundPlay("sounds/enter.wav")
            _Check_YTDLP_Update()
        Case $menu_Update_app, $hDummyUpdateApp
            SoundPlay("sounds/enter.wav")
            _CheckGithubUpdate()
        Case $menuChangelog, $hDummyChangelog
            SoundPlay("sounds/enter.wav")
            _ShowChangelog()
        Case $menu_settings, $hDummySettings
            SoundPlay("sounds/enter.wav")
            _ShowSettings()
        Case $hDummyEscMain
            ; Prevent closing with Escape
    EndSwitch
WEnd

Func _CheckUpdatesSilently()
    AdlibUnRegister("_CheckUpdatesSilently")
    ; Only check if connected to internet
    If Ping("github.com", 1000) > 0 Then
        _CheckGithubUpdate()
    EndIf
EndFunc

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

    GUICtrlCreateLabel("Select Format :", 10, 75, 200, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    $cbo_dl_format = GUICtrlCreateCombo("Video MP4 (Best)", 10, 100, 280, 20, $CBS_DROPDOWNLIST)
    GUICtrlSetTip(-1, "Use Arrow keys to select download format")
    GUICtrlSetData(-1, "Video WebM|Audio MP3|Audio M4A|Audio WAV")

    GUICtrlCreateLabel("Select Bitrate:", 210, 75, 130, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    $cbo_dl_bitrate = GUICtrlCreateCombo("320 kbps", 210, 100, 180, 20, $CBS_DROPDOWNLIST)
    GUICtrlSetTip(-1, "Use Arrow keys to select bitrate")
    GUICtrlSetData(-1, "256 kbps|192 kbps|128 kbps")

    $btn_start_dl = GUICtrlCreateButton("Download (Alt+D)", 10, 150, 380, 40)
    $openbtn = GUICtrlCreateButton("Open Download Folder (Alt+O)", 10, 200, 380, 30)

    Local $hDummyEscDL = GUICtrlCreateDummy()
    Local $aAccelDL[4][2] = [["!p", $paste], ["!d", $btn_start_dl], ["!o", $openbtn], ["{ESC}", $hDummyEscDL]]
    GUISetAccelerators($aAccelDL, $hGuiDL)

    GUISetState(@SW_SHOW, $hGuiDL)
    _AllowUIPI($hGuiDL)
    _AllowUIPI($edit)
    ControlFocus($hGuiDL, "", $edit)

    While 1
        Local $nMsg = GUIGetMsg()
        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $hDummyEscDL
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
            Local $sBitrate = GUICtrlRead($cbo_dl_bitrate)
            Local $iKbps = StringRegExpReplace($sBitrate, "[^0-9]", "")
            If $iKbps <> "" And (StringInStr($sTxt, "Audio") Or StringInStr($sTxt, "MP3") Or StringInStr($sTxt, "WAV") Or StringInStr($sTxt, "M4A")) Then
                $sFmt &= " --audio-quality " & $iKbps & "k"
            EndIf

                    Local $sExtraArgs = ""
                    If StringInStr($url, "watch?v=") And StringInStr($url, "list=") Then
                        $sExtraArgs = " --no-playlist"
                    EndIf

                    GUICtrlSetState($btn_start_dl, $GUI_DISABLE)
                    Local $iPidDL = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" ' & $sFmt & $sExtraArgs & ' -o "download/%(title)s.%(ext)s" -- "' & $url & '""', @ScriptDir, @SW_SHOW)
                    While ProcessExists($iPidDL)
                        Local $m = GUIGetMsg()
                        If $m = $GUI_EVENT_CLOSE Then
                            ProcessClose($iPidDL)
                            GUIDelete($hGuiDL)
                            GUISetState(@SW_SHOW, $mainform)
                            Return
                        EndIf
                        Sleep(1)
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

    Local $hDummyEscPL = GUICtrlCreateDummy()
    Local $aAccelPL[4][2] = [["!p", $play_btn], ["!a", $audio_play_btn], ["!b", $online_play_btn], ["{ESC}", $hDummyEscPL]]
    GUISetAccelerators($aAccelPL, $hGuiPL)

    GUISetState(@SW_SHOW, $hGuiPL)
    _AllowUIPI($hGuiPL)
    _AllowUIPI($linkedit)
    ControlFocus($hGuiPL, "", $linkedit)

    While 1
        Local $nMsg = GUIGetMsg()
        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $hDummyEscPL
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
    $hCurrentSubGui = GUICreate("Search", 400, 160)
    GUISetBkColor($COLOR_BLUE)

    GUICtrlCreateLabel("Enter keyword to search:", 10, 15, 80, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    $inp_search = GUICtrlCreateInput("", 100, 12, 210, 20)

    GUICtrlCreateLabel("Filter:", 10, 50, 80, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    Local $cbo_filter = GUICtrlCreateCombo("No Filter", 100, 47, 210, 20, $CBS_DROPDOWNLIST)
    GUICtrlSetData(-1, "Playlist|lives|upload date|Most viewed")

    $btn_search_go = GUICtrlCreateButton("Search (Alt+S)", 320, 10, 70, 25)
    GUICtrlSetState(-1, $GUI_DEFBUTTON)

    Local $btn_voice_search = GUICtrlCreateButton("Voice search (Alt+V)", 320, 47, 70, 25)

    $btn_search_hist = GUICtrlCreateButton("Search History (Alt+H)", 100, 90, 210, 30)

    Local $aAccelSC[3][2] = [["!s", $btn_search_go], ["!h", $btn_search_hist], ["!v", $btn_voice_search]]
    GUISetAccelerators($aAccelSC, $hCurrentSubGui)

    GUISetState(@SW_SHOW, $hCurrentSubGui)
    _AllowUIPI($hCurrentSubGui)
    _AllowUIPI($inp_search)
    ControlFocus($hCurrentSubGui, "", $inp_search)

    While 1
        Local $nMsg = GUIGetMsg()

        Switch $nMsg
            Case $GUI_EVENT_CLOSE
                GUIDelete($hCurrentSubGui)
                $hCurrentSubGui = 0
                GUISetState(@SW_SHOW, $mainform)
                Return
            Case $btn_voice_search
                If FileExists($VOICE_SEARCH_EXE_PATH) Then
                    GUICtrlSetState($btn_voice_search, $GUI_DISABLE)
                    _NVDA_Speak("Voice search activated. Please speak clearly into your microphone.")
                    ; Âm thanh bắt đầu tìm kiếm
                    SoundPlay(@ScriptDir & "\sounds\start_voice_search.wav")

                    Local $pid = Run(@ComSpec & ' /c ""' & $VOICE_SEARCH_EXE_PATH & '""', @ScriptDir, @SW_HIDE, $STDOUT_CHILD)
                    Local $bBinaryOutput = Binary("")
                    While ProcessExists($pid)
                        $bBinaryOutput &= StdoutRead($pid, False, True)
                        Sleep(10)
                    WEnd
                    $bBinaryOutput &= StdoutRead($pid, False, True)

                    ; Âm thanh kết thúc tìm kiếm
                    SoundPlay(@ScriptDir & "\sounds\stop_voice_search.wav")

                    Local $sFullOutput = BinaryToString($bBinaryOutput, 4)

                    ; Common encoding fixes if StdoutRead still catches broken UTF-8 as ANSI
                    If StringInStr($sFullOutput, "vÃ´ hiá»‡u hÃ³a") Then
                        $sFullOutput = StringReplace($sFullOutput, "vÃ´ hiá»‡u hÃ³a", "vô hiệu hóa")
                    EndIf

                    Local $sResult = ""
                    Local $sError = ""
                    Local $aLines = StringSplit(StringReplace($sFullOutput, @CR, ""), @LF)
                    For $i = 1 To $aLines[0]
                        Local $sLine = StringStripWS($aLines[$i], 3)
                        If $sLine == "" Then ContinueLoop
                        If StringInStr($sLine, "ERROR:") Then
                            $sError = StringStripWS(StringReplace($sLine, "ERROR:", ""), 3)
                        ElseIf Not StringInStr($sLine, "INFO:") And Not StringInStr($sLine, "LISTENING") And Not StringInStr($sLine, "RECOGNIZING") Then
                            $sResult = $sLine
                        EndIf
                    Next

                    If $sError <> "" Then
                        Local $sTranslatedError = $sError
                        If StringInStr($sError, "Could not understand audio") Then
                            $sTranslatedError = "Could not recognize speech. Please speak more clearly or check your microphone."
                        ElseIf StringInStr($sError, "check your microphone") Then
                            $sTranslatedError = "Microphone connection error. Please check your recording device."
                        EndIf
                        _NVDA_Speak("Voice search error: " & $sTranslatedError)
                        MsgBox(16, "Voice Search Error", $sTranslatedError)
                    ElseIf $sResult <> "" Then
                        GUICtrlSetData($inp_search, $sResult)
                        ControlFocus($hCurrentSubGui, "", $inp_search)
                        _NVDA_Speak("Voice input received: " & $sResult)
                    Else
                        _NVDA_Speak("Voice search did not recognize any speech.")
                    EndIf
                    GUICtrlSetState($btn_voice_search, $GUI_ENABLE)
                Else
                    MsgBox(16, "Error", "voice_search.exe not found in lib folder!")
                EndIf

            Case $btn_search_go
                $sCurrentKeyword = GUICtrlRead($inp_search)
                $g_sSearchFilter = GUICtrlRead($cbo_filter)
                If $sCurrentKeyword <> "" Then
                    _AddSearchHistory($sCurrentKeyword)
                    Local $sRes = _ShowSearchResultsWindow($sCurrentKeyword, $g_sSearchFilter)
                    If $sRes = "RETURN_MAIN" Then
                        GUIDelete($hCurrentSubGui)
                        $hCurrentSubGui = 0
                        GUISetState(@SW_SHOW, $mainform)
                        Return
                    EndIf
                EndIf

            Case $btn_search_hist
                Local $sRes = _ShowSearchHistoryWindow()
                If $sRes = "RETURN_MAIN" Then
                    GUIDelete($hCurrentSubGui)
                    $hCurrentSubGui = 0
                    GUISetState(@SW_SHOW, $mainform)
                    Return
                EndIf
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
    _GUICtrlListBox_SetCurSel($lst_hist, 0)
    ControlFocus($hSearchHistoryGui, "", $lst_hist)

    Local $hDummyEnterSearchHist = GUICtrlCreateDummy()
    Local $aAccelSearchHist[1][2] = [["{ENTER}", $hDummyEnterSearchHist]]
    GUISetAccelerators($aAccelSearchHist, $hSearchHistoryGui)

    While 1
        Local $nMsg = GUIGetMsg()

        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $btn_back
                GUIDelete($hSearchHistoryGui)
                GUISetState(@SW_SHOW, $hCurrentSubGui)
    _AllowUIPI($hCurrentSubGui)
    _AllowUIPI($inp_search)
    ControlFocus($hCurrentSubGui, "", $inp_search)
                Return

            Case $hDummyEnterSearchHist
                If ControlGetHandle($hSearchHistoryGui, "", ControlGetFocus($hSearchHistoryGui)) = GUICtrlGetHandle($lst_hist) Then
                    Local $sSelected = _GUICtrlListBox_GetText($lst_hist, _GUICtrlListBox_GetCurSel($lst_hist))
                    If $sSelected <> "" Then
                        GUIDelete($hSearchHistoryGui)
                        $hSearchHistoryGui = 0
                        $sCurrentKeyword = $sSelected
                        GUICtrlSetData($inp_search, $sCurrentKeyword)
                        Local $sRes = _ShowSearchResultsWindow($sCurrentKeyword, "No Filter")
                        If $sRes = "RETURN_MAIN" Then Return "RETURN_MAIN"
                        GUISetState(@SW_SHOW, $hCurrentSubGui)
    _AllowUIPI($hCurrentSubGui)
    _AllowUIPI($inp_search)
    ControlFocus($hCurrentSubGui, "", $inp_search)
                        Return
                    EndIf
                EndIf

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

Func _ShowSearchResultsWindow($sKeyword, $sFilter = "No Filter")
    GUISetState(@SW_HIDE, $hCurrentSubGui)

    $hResultsGui = GUICreate("Search Results", 400, 440)
    GUISetBkColor($COLOR_BLUE)
    $lst_results = GUICtrlCreateList("", 10, 10, 380, 380, BitOR($LBS_NOTIFY, $WS_VSCROLL, $WS_BORDER))
    Local $btn_return_main = GUICtrlCreateButton("return to main window", 10, 400, 380, 30)

    Local $hDummyAudio = GUICtrlCreateDummy()
    Local $hDummyEnterResults = GUICtrlCreateDummy()
    Local $hDummyHomeResults = GUICtrlCreateDummy()
    Local $hDummyEndResults = GUICtrlCreateDummy()
    Local $hDummyEscResults = GUICtrlCreateDummy()
    Local $aAccel[5][2] = [ _
        ["^{ENTER}", $hDummyAudio], _
        ["{ENTER}", $hDummyEnterResults], _
        ["{HOME}", $hDummyHomeResults], _
        ["{END}", $hDummyEndResults], _
        ["{ESC}", $hDummyEscResults] _
    ]
    GUISetAccelerators($aAccel, $hResultsGui)

    GUISetState(@SW_SHOW, $hResultsGui)

    _SearchYouTube($sKeyword, False)

    While 1
        Local $nMsg = GUIGetMsg()

        Switch $nMsg
            Case $GUI_EVENT_CLOSE
                GUIDelete($hResultsGui)
                $hResultsGui = 0
                GUISetState(@SW_SHOW, $hCurrentSubGui)
    _AllowUIPI($hCurrentSubGui)
    _AllowUIPI($inp_search)
    ControlFocus($hCurrentSubGui, "", $inp_search)
                Return
            Case $btn_return_main
                GUIDelete($hResultsGui)
                $hResultsGui = 0
                Return "RETURN_MAIN"
            Case $hDummyEnterResults
                If ControlGetHandle($hResultsGui, "", ControlGetFocus($hResultsGui)) = GUICtrlGetHandle($lst_results) Then
                    Local $iSel = _GUICtrlListBox_GetCurSel($lst_results)
                    If $iSel <> -1 Then
                        If $aSearchTypes[$iSel + 1] = "playlist" Then
                            _ShowPlaylistVideos($aSearchIds[$iSel + 1], $aSearchTitles[$iSel + 1])
                        Else
                            _PlayLoop($iSel, False) ; Video
                        EndIf
                    EndIf
                EndIf
            Case $hDummyHomeResults
                _GUICtrlListBox_SetCurSel($lst_results, 0)
            Case $hDummyEndResults
                _GUICtrlListBox_SetCurSel($lst_results, _GUICtrlListBox_GetCount($lst_results) - 1)
                _CheckAutoLoadMore()
            Case $hDummyEscResults
                GUIDelete($hResultsGui)
                $hResultsGui = 0
                GUISetState(@SW_SHOW, $hCurrentSubGui)
    _AllowUIPI($hCurrentSubGui)
    _AllowUIPI($inp_search)
    ControlFocus($hCurrentSubGui, "", $inp_search)
                Return
            Case $lst_results
                _CheckAutoLoadMore()
            Case $hDummyAudio
                If ControlGetHandle($hResultsGui, "", ControlGetFocus($hResultsGui)) = GUICtrlGetHandle($lst_results) Then
                    _PlayLoop(_GUICtrlListBox_GetCurSel($lst_results), True) ; Ctrl+Enter = Play Audio
                EndIf
        EndSwitch
    WEnd
EndFunc

Func _SearchYouTube($sKeyword, $bAppend)
    $bIsSearching = True

    Local $hWaitGui = 0
    If Not $bAppend Then
        Local $sLoadingText = $sKeyword
        If $g_sSearchFilter <> "No Filter" Then $sLoadingText &= " (" & $g_sSearchFilter & ")"
        $hWaitGui = GUICreate("Searching", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW), $hResultsGui)
        GUICtrlCreateLabel($sLoadingText & "...", 10, 25, 230, 20, $SS_CENTER)
        GUISetBkColor(0xFFFFFF, $hWaitGui)
        GUISetState(@SW_SHOW, $hWaitGui)
        GUISetCursor(15, 1)
        Sleep(1)
    EndIf

    Local $iStart = $bAppend ? $iTotalLoaded + 1 : 1
    Local $iFetch = 20
    Local $iEnd = $iStart + $iFetch - 1

    Local $sUrlKeyword = StringReplace($sKeyword, " ", "+")
    $sUrlKeyword = StringReplace($sUrlKeyword, '"', '%22')
    Local $sSearchTarget = ""

    Switch $g_sSearchFilter
        Case "Playlist"
            $sSearchTarget = 'https://www.youtube.com/results?search_query=' & $sUrlKeyword & '&sp=EgIQAw%3D%3D'
        Case "lives"
            $sSearchTarget = 'https://www.youtube.com/results?search_query=' & $sUrlKeyword & '&sp=EgJAAQ%3D%3D'
        Case "upload date"
            $sSearchTarget = 'https://www.youtube.com/results?search_query=' & $sUrlKeyword & '&sp=CAI%3D'
        Case "Most viewed"
            $sSearchTarget = 'https://www.youtube.com/results?search_query=' & $sUrlKeyword & '&sp=CAM%3D'
        Case Else
            $sSearchTarget = "ytsearch" & $iEnd & ":" & $sKeyword
    EndSwitch

    ; Use JSON output to ensure all video metadata stays together
    Local $sParams = '--flat-playlist --print-json --playlist-start ' & $iStart & ' --playlist-end ' & $iEnd & ' --no-warnings --encoding utf-8 -- "' & $sSearchTarget & '"'

    Local $sFullCmd = @ComSpec & ' /c ""' & $YT_DLP_PATH & '" ' & $sParams & '"'
    Local $iPID = Run($sFullCmd, @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)

    Local $bData = Binary("")
    Local $sErr = ""
    While ProcessExists($iPID)
        $bData &= StdoutRead($iPID, False, True)
        $sErr &= StderrRead($iPID)
        Sleep(1)
    WEnd
    $bData &= StdoutRead($iPID, False, True)
    $sErr &= StderrRead($iPID)

    Local $sOutput = BinaryToString($bData, 4)

    If Not $bAppend Then
        GUICtrlSetData($lst_results, "")
        Global $aSearchIds[1]
        Global $aSearchTitles[1]
        Global $aSearchTypes[1] ; Reset Types as well
        $iTotalLoaded = 0
        $bEndReached = False
    EndIf

    Local $iLoadedBefore = $iTotalLoaded
    Local $aLines = StringSplit(StringStripCR($sOutput), @LF)

    If $aLines[0] > 0 Then
        Local $sDefaultType = ($g_sSearchFilter == "Playlist" ? "playlist" : "video")
        Local $sCurrentTitle = "", $sCurrentId = "", $sCurrentDur = "", $sCurrentUp = "", $sCurrentType = $sDefaultType
        Local $sCurrentViews = "", $sCurrentDate = "", $sCurrentLive = ""

        ; Efficiently ReDim in chunks to avoid excessive ReDimming
        Local $iInitialCount = UBound($aSearchIds)
        ReDim $aSearchIds[$iInitialCount + $aLines[0]]
        ReDim $aSearchTitles[$iInitialCount + $aLines[0]]
        ReDim $aSearchTypes[$iInitialCount + $aLines[0]]
        Local $iCount = $iInitialCount

        For $i = 1 To $aLines[0]
            Local $sLine = StringStripWS($aLines[$i], 3)
            If $sLine = "" Then ContinueLoop

            ; Simple but effective JSON extraction for ID, Title and Duration
            Local $sIdMatch = StringRegExp($sLine, '"id":\s*"([^"]+)"', 3)
            Local $sTitleMatch = StringRegExp($sLine, '"title":\s*"([^"]+)"', 3)
            Local $sDurMatch = StringRegExp($sLine, '"duration_string":\s*"([^"]+)"', 3)
            Local $sUploaderMatch = StringRegExp($sLine, '"uploader":\s*"([^"]+)"', 3)
            Local $sViewMatch = StringRegExp($sLine, '"view_count_text":\s*"([^"]+)"', 3)
            Local $sDateMatch = StringRegExp($sLine, '"upload_date":\s*"([^"]+)"', 3)
            Local $sLiveMatch = StringInStr($sLine, '"is_live": true')
            Local $sTypeMatch = StringRegExp($sLine, '"_type":\s*"([^"]+)"', 3)

            If IsArray($sIdMatch) And IsArray($sTitleMatch) Then
                $sCurrentId = $sIdMatch[0]
                $sCurrentTitle = _UnescapeJSON($sTitleMatch[0])

                If IsArray($sDurMatch) Then $sCurrentDur = $sDurMatch[0]
                If IsArray($sUploaderMatch) Then $sCurrentUp = _UnescapeJSON($sUploaderMatch[0])
                If IsArray($sViewMatch) Then $sCurrentViews = $sViewMatch[0]
                If IsArray($sDateMatch) Then $sCurrentDate = $sDateMatch[0]
                If IsArray($sTypeMatch) Then $sCurrentType = $sTypeMatch[0]

                If $sLiveMatch Then $sCurrentLive = "True"
                ; Tự động nhận diện Playlist dựa trên ID nếu các cách trên thất bại
                If $sCurrentType <> "playlist" Then
                    If StringLen($sCurrentId) > 11 Or StringLeft($sCurrentId, 2) = "PL" Or StringLeft($sCurrentId, 2) = "RD" Or StringLeft($sCurrentId, 2) = "OL" Then
                        $sCurrentType = "playlist"
                    EndIf
                EndIf

                $iTotalLoaded += 1
                If $sCurrentTitle == "" Or $sCurrentTitle == "NA" Then ContinueLoop ; Skip unknown titles
                Local $sDisplay = $sCurrentTitle

                If $sCurrentLive == "True" Then $sDisplay = "[LIVE] " & $sDisplay
                If $sCurrentDur <> "" And $sCurrentDur <> "NA" Then $sDisplay &= " [" & $sCurrentDur & "]"

                If $g_sSearchFilter == "upload date" And $sCurrentDate <> "" And $sCurrentDate <> "NA" Then
                    ; Format YYYYMMDD to DD/MM/YYYY for display
                    Local $sFormattedDate = $sCurrentDate
                    If StringLen($sCurrentDate) == 8 Then
                        $sFormattedDate = StringMid($sCurrentDate, 7, 2) & "/" & StringMid($sCurrentDate, 5, 2) & "/" & StringLeft($sCurrentDate, 4)
                    EndIf
                    $sDisplay &= " (" & $sFormattedDate & ")"
                EndIf

                If $g_sSearchFilter == "Most viewed" And $sCurrentViews <> "" And $sCurrentViews <> "NA" Then
                    $sDisplay &= " - " & $sCurrentViews
                EndIf

                If $sCurrentUp <> "" And $sCurrentUp <> "NA" Then $sDisplay &= " - " & $sCurrentUp

                _GUICtrlListBox_AddString($lst_results, $sDisplay)

                $aSearchIds[$iCount] = $sCurrentId
                $aSearchTitles[$iCount] = $sCurrentTitle
                $aSearchTypes[$iCount] = $sCurrentType ; Lưu loại kết quả chính xác

                $iCount += 1
            EndIf
        Next

        ; Shrink arrays to actual size
        ReDim $aSearchIds[$iCount]
        ReDim $aSearchTitles[$iCount]
        ReDim $aSearchTypes[$iCount]
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
        _GUICtrlListBox_SetCurSel($lst_results, 0)
        ControlFocus($hResultsGui, "", $lst_results)
    EndIf

    $bIsSearching = False
EndFunc

Func _CheckAutoLoadMore()
    If $hResultsGui = 0 Or $bIsSearching Or $bEndReached Then Return
    Local $iCur = _GUICtrlListBox_GetCurSel($lst_results)
    Local $iCount = _GUICtrlListBox_GetCount($lst_results)
    ; Trigger earlier (10 items remaining) for smoother experience
    If $iCur <> -1 And $iCur >= $iCount - 10 Then
        _SearchYouTube($sCurrentKeyword, True)
    EndIf
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
    _GUICtrlMenu_AddMenuItem($hMenu, "Copy &Link...", 1006)
    _GUICtrlMenu_AddMenuItem($hMenu, "&Video Description...", 1008)
    _GUICtrlMenu_AddMenuItem($hMenu, "Video Com&ments...", 1009)
    _GUICtrlMenu_AddMenuItem($hMenu, "Go to &Time...", 1010)

    Local $sID = $aSearchIds[$iIndex + 1]
    Local $bIsAlreadyFav = _IsFavorite($sID)

    Local $sFavText
    If $bIsFavContext = 1 Then
        $sFavText = "&Remove from Favorite..."
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
        Case 1009
            _Action_ShowComments($iIndex)
        Case 1010
            _ShowGoToTime()
    EndSwitch
EndFunc

Func _Action_CopyLink($iIndex)
    If $iIndex < 0 Or $iIndex >= UBound($aSearchIds) - 1 Then Return
    Local $sUrl = "https://www.youtube.com/watch?v=" & $aSearchIds[$iIndex + 1]
    ClipPut($sUrl)
    MsgBox(64, "Info", "Link copied to clipboard!")
EndFunc


Func _AddDefenderExclusion()
    If Not IsAdmin() Then Return ; Skip if not admin to avoid triggering UAC or shell crashes
    Local $sDir = @ScriptDir
    If StringRight($sDir, 1) <> "\" Then $sDir &= "\"

    ; Use PowerShell to add exclusion. Added a small delay check to prevent rapid fire
    Local $sCmd = 'powershell -Command "Add-MpPreference -ExclusionPath ''' & $sDir & '''" -WindowStyle Hidden'
    Run($sCmd, @SystemDir, @SW_HIDE)
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

    Local $iPID = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" --get-description --no-playlist --encoding utf-8 -- "' & $sID & '""', @ScriptDir, @SW_HIDE, $STDOUT_CHILD)
    Local $bData = Binary("")

    While ProcessExists($iPID)
        $bData &= StdoutRead($iPID, False, True) ; True = Binary Mode
        Sleep(1)
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

Func _Action_ShowComments($iIndex)
    If $iIndex < 0 Or $iIndex >= UBound($aSearchIds) - 1 Then Return
    Local $sID = $aSearchIds[$iIndex + 1]

    If Not FileExists($COMMENTS_EXE_PATH) Then
        MsgBox(16, "Error", "comments.exe not found in lib folder!")
        Return
    EndIf

    ; Directly run comments.exe with the YouTube URL.
    ; comments.exe already handles fetching comments internally.
    Local $sUrl = "https://www.youtube.com/watch?v=" & $sID
    Run('"' & $COMMENTS_EXE_PATH & '" "' & $sUrl & '"')
EndFunc

Func _Action_GoChannel($iIndex)
    If $iIndex < 0 Or $iIndex >= UBound($aSearchIds) - 1 Then Return
    Local $sID = $aSearchIds[$iIndex + 1]

    Local $hLoading = GUICreate("Working...", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW), $hResultsGui)
    GUICtrlCreateLabel("Fetching channel information...", 10, 25, 230, 20, $SS_CENTER)
    GUISetBkColor(0xFFFFFF, $hLoading)
    GUISetState(@SW_SHOW, $hLoading)

    Local $pid_channel = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" --print "https://www.youtube.com/channel/%(channel_id)s" --no-playlist -- "' & $sID & '""', @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
    Local $sChannelUrl = ""
    While ProcessExists($pid_channel)
        $sChannelUrl &= StdoutRead($pid_channel)
        Sleep(1)
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

		Local $sType = "video"
		If UBound($aSearchTypes) > $iCurrentIndex + 1 Then
			If $aSearchTypes[$iCurrentIndex + 1] <> "" Then $sType = $aSearchTypes[$iCurrentIndex + 1]
		EndIf
        _AddHistory($sID, $sTitle, $sType) ; Save to history when playing

        ; Update existing player info or show status if GUI exists
        If IsHWnd($hPlayGui) Then
            GUICtrlSetData($g_lblPlayerInfo, "Loading: " & $sTitle)
            GUICtrlSetData($g_hStatusLabel, "Fetching URL...")
        Else
            ; Show a small loading popup ONLY if player isn't open yet
            $hLoading = GUICreate("Playing", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW), $hResultsGui)
            GUICtrlCreateLabel("playing...", 10, 15, 230, 40, $SS_CENTER)
            GUISetBkColor(0xFFFFFF, $hLoading)
            GUISetState(@SW_SHOW, $hLoading)
            WinActivate($hLoading)
        Sleep(1)
        EndIf

        Local $sFormat = $bAudioOnly ? "bestaudio/best" : "best[ext=mp4]/best"
        ; Sửa lỗi 153: Chuyển hẳn sang client Android/iOS để tránh bị YouTube quét bot trên nền tảng Web
        Local $sParams = '-g -f "' & $sFormat & '" --no-playlist --no-check-certificate --no-warnings --no-mtime --socket-timeout 10 --geo-bypass --extractor-args "youtube:player-client=android,ios" --encoding utf-8'
        Local $sCmd = @ComSpec & ' /c ""' & $YT_DLP_PATH & '" ' & $sParams & ' -- "' & $sID & '""'
        Local $pid_url = Run($sCmd, @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
        Local $sUrl = "", $sErr = ""
        While ProcessExists($pid_url)
            $sUrl &= StdoutRead($pid_url)
            $sErr &= StderrRead($pid_url)
            Sleep(1)
        WEnd
        $sUrl &= StdoutRead($pid_url)
        $sErr &= StderrRead($pid_url)

        $sUrl = StringStripWS($sUrl, 3)

        If $sUrl = "" Then
            ; Nếu lỗi, thử xóa cache yt-dlp một lần rồi báo lỗi chi tiết
            RunWait(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" --rm-cache-dir"', @ScriptDir, @SW_HIDE)

            If IsHWnd($hLoading) Then GUIDelete($hLoading)
            Local $sErrMsg = "Lỗi 153: YouTube đã chặn yêu cầu trích xuất link."
            If StringInStr($sErr, "sign in") Or StringInStr($sErr, "confirm you are not a bot") Then
                $sErrMsg &= " YouTube yêu cầu xác minh người dùng."
            ElseIf StringInStr($sErr, "age restricted") Then
                $sErrMsg &= " Video bị giới hạn độ tuổi."
            Else
                $sErrMsg &= " (Cảnh báo: YouTube đang quét Bot, hãy thử lại sau vài phút)."
            EndIf
            _NVDA_Speak($sErrMsg)
            MsgBox(16, "Error", $sErrMsg & @CRLF & @CRLF & "Mẹo: Hãy thử mở video khác hoặc khởi động lại modem mạng để đổi IP.")
            ExitLoop
        EndIf

        Local $sAction = _PlayInternal($sUrl, $sTitle, $bAudioOnly, $hLoading, True, $sID) ; True = Allow AutoPlay toggle

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

    If IsHWnd($hPlayGui) Then
        $oWMP.controls.stop()
        GUIDelete($hPlayGui)
        $hPlayGui = 0
        $oWMP = 0
    EndIf
EndFunc

Func _ShowDownloadDialog($sID, $sTitle)
    Local $sUrl = "https://www.youtube.com/watch?v=" & $sID
    Local $hDLGui = GUICreate("Download Options", 300, 150, -1, -1, -1, -1)
    GUICtrlCreateLabel("Select Format :", 10, 20, 280, 20)
    Local $cboFormat = GUICtrlCreateCombo("Video MP4 (Best)", 10, 40, 280, 20, $CBS_DROPDOWNLIST)
    GUICtrlSetTip(-1, "Use Arrow keys to select download format")
    GUICtrlSetData(-1, "Video WebM|Audio MP3|Audio M4A|Audio WAV")
    GUICtrlCreateLabel("Select Bitrate:", 210, 75, 130, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    $cbo_dl_bitrate = GUICtrlCreateCombo("320 kbps", 210, 100, 180, 20, $CBS_DROPDOWNLIST)
    GUICtrlSetTip(-1, "Use Arrow keys to select bitrate")
    GUICtrlSetData(-1, "256 kbps|192 kbps|128 kbps")

    Local $btn_DownloadNow = GUICtrlCreateButton("Download", 100, 80, 100, 30)

    GUISetState(@SW_SHOW, $hDLGui)

    While 1
        Local $nMsg = GUIGetMsg()
        If $nMsg = $GUI_EVENT_CLOSE Then
            GUIDelete($hDLGui)
            ExitLoop
        ElseIf $nMsg = $btn_DownloadNow Then
            Local $sTxt = GUICtrlRead($cboFormat)
            Local $sBitrate = GUICtrlRead($cbo_dl_bitrate)
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
            Local $sBitrate = GUICtrlRead($cbo_dl_bitrate)
            Local $iKbps = StringRegExpReplace($sBitrate, "[^0-9]", "")
            If $iKbps <> "" And (StringInStr($sTxt, "Audio") Or StringInStr($sTxt, "MP3") Or StringInStr($sTxt, "WAV") Or StringInStr($sTxt, "M4A")) Then
                $sFmt &= " --audio-quality " & $iKbps & "k"
            EndIf

            Local $iPidDLNow = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" ' & $sFmt & ' -o "download/%(title)s.%(ext)s" -- "' & $sUrl & '""', @ScriptDir, @SW_SHOW)
            While ProcessExists($iPidDLNow)
                Local $mDL = GUIGetMsg()
                If $mDL = $GUI_EVENT_CLOSE Then
                    ProcessClose($iPidDLNow)
                    GUIDelete($hDLGui)
                    Return
                EndIf
                Sleep(1)
            WEnd
            MsgBox(64, "Info", "Download Complete!")
            ExitLoop
        EndIf
    WEnd
EndFunc

Func playmedia($url)
    ; Update existing player info or show status if GUI exists
    Local $hLoading = 0
    If IsHWnd($hPlayGui) Then
        GUICtrlSetData($g_lblPlayerInfo, "Loading video...")
        GUICtrlSetData($g_hStatusLabel, "Fetching stream URL...")
    Else
        $hLoading = GUICreate("Playing", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
        GUICtrlCreateLabel("Loading, please wait...", 10, 25, 230, 30, $SS_CENTER)
        GUISetBkColor(0xFFFFFF, $hLoading)
        GUISetState(@SW_SHOW, $hLoading)
        Sleep(1)
    EndIf

    Local $sCmd = @ComSpec & ' /c ""' & $YT_DLP_PATH & '" -g -f "best" --no-playlist --no-check-certificate --no-warnings --no-mtime --socket-timeout 5 --geo-bypass --encoding utf-8 -4 -- "' & $url & '""'
    Local $pid = Run($sCmd, @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
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
        _PlayInternal($dlink, $sTitle, False, $hLoading, False, $id)
    Else
        If $hLoading <> 0 Then GUIDelete($hLoading)
        Local $sErrMsg = "Cannot get video stream from this link."
        If $sErr <> "" Then $sErrMsg &= " Details: " & StringLeft(StringStripWS($sErr, 3), 100)
        MsgBox(16, "Error", $sErrMsg)
    EndIf
EndFunc

Func playaudio($url)
    ; Update existing player info or show status if GUI exists
    Local $hLoading = 0
    If IsHWnd($hPlayGui) Then
        GUICtrlSetData($g_lblPlayerInfo, "Loading audio...")
        GUICtrlSetData($g_hStatusLabel, "Fetching stream URL...")
    Else
        $hLoading = GUICreate("Playing", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
        GUICtrlCreateLabel("Loading, please wait...", 10, 25, 230, 30, $SS_CENTER)
        GUISetBkColor(0xFFFFFF, $hLoading)
        GUISetState(@SW_SHOW, $hLoading)
        Sleep(1)
    EndIf

    Local $sCmd = @ComSpec & ' /c ""' & $YT_DLP_PATH & '" -g -f "bestaudio" --no-playlist --no-check-certificate --no-warnings --no-mtime --socket-timeout 5 --geo-bypass --encoding utf-8 -4 -- "' & $url & '""'
    Local $pid = Run($sCmd, @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
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
        _PlayInternal($dlink, "YouTube Audio Player", True, $hLoading, False, $id)
    Else
        If $hLoading <> 0 Then GUIDelete($hLoading)
        Local $sErrMsg = "Cannot get audio stream from this link."
        If $sErr <> "" Then $sErrMsg &= " Details: " & StringLeft(StringStripWS($sErr, 3), 100)
        MsgBox(16, "Error", $sErrMsg)
    EndIf
EndFunc

Func _PlayInternal($sUrl, $sTitle, $bAudioOnly = False, $hLoading = 0, $allowAutoPlayToggle = False, $sID = "")
    Local $iWidth = 640, $iHeight = 360
    If $bAudioOnly Then
        $iWidth = 400
        $iHeight = 150
    EndIf

    If Not IsHWnd($hPlayGui) Then
        $g_sCurrentVideoTitle = $sTitle
        ; Sử dụng style tiêu chuẩn hơn để Menu Bar hiển thị tốt nhất
        $hPlayGui = GUICreate($sTitle, $iWidth, $iHeight + 60, -1, -1, BitOR($WS_OVERLAPPEDWINDOW, $WS_CLIPCHILDREN), $WS_EX_TOPMOST)
        GUISetBkColor(0x000000)
        GUISwitch($hPlayGui)

        ; Tạo Menu Bar - Không dùng biến Local để tránh nhầm lẫn, dùng biến Global đã khai báo
        Local $hMenu_Options = GUICtrlCreateMenu("&Options")
        $menu_item_download = GUICtrlCreateMenuItem("&Download...", $hMenu_Options)
        $menu_item_channel = GUICtrlCreateMenuItem("Go to &Channel...", $hMenu_Options)
        $menu_item_browser = GUICtrlCreateMenuItem("Open in &Browser...", $hMenu_Options)
        $menu_item_copy = GUICtrlCreateMenuItem("Copy &Link...", $hMenu_Options)
        $menu_item_desc = GUICtrlCreateMenuItem("&Video Description...", $hMenu_Options)
        $menu_item_comments = GUICtrlCreateMenuItem("Video Com&ments...", $hMenu_Options)

        Local $sFavText = _IsFavorite($sID) ? "&Remove from Favorite..." : "Add to &Favorite..."
        $menu_item_fav = GUICtrlCreateMenuItem($sFavText, $hMenu_Options)

        $menu_item_goto = GUICtrlCreateMenuItem("Go to &Time... (Ctrl+G)", $hMenu_Options)

        ; Vẽ lại thanh menu để đảm bảo hiển thị
        _GUICtrlMenu_DrawMenuBar($hPlayGui)

        $oWMP = ObjCreate("WMPlayer.OCX.7")
        If Not IsObj($oWMP) Then
            if $hLoading <> 0 Then GUIDelete($hLoading)
            MsgBox(16, "Error", "Windows Media Player ActiveX control could not be created.")
            GUIDelete($hPlayGui)
            $hPlayGui = 0
            Return ""
        EndIf

        $oWMPCtrl = GUICtrlCreateObj($oWMP, 0, 0, $iWidth, $iHeight)

        $g_hStatusLabel = GUICtrlCreateLabel("", 10, $iHeight + 5, $iWidth - 100, 20)
        GUICtrlSetState(-1, $GUI_DISABLE)
        GUICtrlSetFont(-1, 10, 800)
        GUICtrlSetColor(-1, 0xFFFF00)

        $g_lblPlayerInfo = GUICtrlCreateLabel("Playing: ", 10, $iHeight + 22, $iWidth - 100, 18)
        GUICtrlSetColor(-1, 0x00FF00)

        $g_lblAuto = GUICtrlCreateLabel("Auto: ON", $iWidth - 80, $iHeight + 22, 70, 18)
        GUICtrlSetColor(-1, 0xFFFF00)

        $g_lblRepeat = GUICtrlCreateLabel("Repeat: OFF", $iWidth - 80, $iHeight + 5, 70, 18)
        GUICtrlSetColor(-1, 0xFFFF00)

        GUISetState(@SW_SHOW, $hPlayGui)

        ; Initialize Hidden Controls and Accelerators
        $hDummySpace = GUICtrlCreateDummy()
        $hDummyEnter = GUICtrlCreateDummy()
        $hDummyN = GUICtrlCreateDummy()
        $hDummyUp = GUICtrlCreateDummy()
        $hDummyDown = GUICtrlCreateDummy()
        $hDummyLeft = GUICtrlCreateDummy()
        $hDummyRight = GUICtrlCreateDummy()
        $hDummyCtrlLeft = GUICtrlCreateDummy()
        $hDummyCtrlRight = GUICtrlCreateDummy()
        $hDummyCtrlT = GUICtrlCreateDummy()
        $hDummyCtrlShiftT = GUICtrlCreateDummy()
        $hDummyHome = GUICtrlCreateDummy()
        $hDummyEnd = GUICtrlCreateDummy()
        $hDummy1 = GUICtrlCreateDummy()
        $hDummy2 = GUICtrlCreateDummy()
        $hDummy3 = GUICtrlCreateDummy()
        $hDummy4 = GUICtrlCreateDummy()
        $hDummy5 = GUICtrlCreateDummy()
        $hDummy6 = GUICtrlCreateDummy()
        $hDummy7 = GUICtrlCreateDummy()
        $hDummy8 = GUICtrlCreateDummy()
        $hDummy9 = GUICtrlCreateDummy()

        $hDummyR = GUICtrlCreateDummy()
        $hDummyShiftN = GUICtrlCreateDummy()
        $hDummyShiftB = GUICtrlCreateDummy()
        $hDummyCtrlW = GUICtrlCreateDummy()
        $hDummyMinus = GUICtrlCreateDummy()
        $hDummyEqual = GUICtrlCreateDummy()
        $hDummyS = GUICtrlCreateDummy()
        $hDummyD = GUICtrlCreateDummy()
        $hDummyF = GUICtrlCreateDummy()
        $hDummyCtrlShiftE = GUICtrlCreateDummy()
        $hDummyEsc = GUICtrlCreateDummy()
        $hDummyG = GUICtrlCreateDummy()
        $hDummyApps = GUICtrlCreateDummy()
        $hDummyAltO = GUICtrlCreateDummy() ; Vẫn giữ Dummy nhưng không dùng accelerator để tránh loop

        $hDummyAltB = GUICtrlCreateDummy() ; Alt+B: Open Browser
        $hDummyAltG = GUICtrlCreateDummy() ; Alt+G: Go Channel

        ; New hotkeys for selection and actions
        $hDummyBracketLeft = GUICtrlCreateDummy()
        $hDummyBracketRight = GUICtrlCreateDummy()
        $hDummyCtrlS = GUICtrlCreateDummy()
        $hDummyCtrlK = GUICtrlCreateDummy()
        $hDummyCtrlC = GUICtrlCreateDummy()
        $hDummyCtrlShiftC = GUICtrlCreateDummy()
        $hDummyCtrlShiftD = GUICtrlCreateDummy() ; Ctrl+Shift+D: Description

        ; Lưu ý: Xóa !o khỏi Accelerator để Windows tự xử lý menu tiêu chuẩn &Options
        ; Khôi phục lại phím tắt đơn theo yêu cầu người dùng
        Local $aAccelPlay[44][2] = [ _
            ["{SPACE}", $hDummySpace], _
            ["n", $hDummyN], _ ; Next
            ["r", $hDummyR], _ ; Repeat
            ["+n", $hDummyShiftN], _ ; Force Next
            ["+b", $hDummyShiftB], _ ; Force Back
            ["{UP}", $hDummyUp], _
            ["{DOWN}", $hDummyDown], _
            ["{LEFT}", $hDummyLeft], _
            ["{RIGHT}", $hDummyRight], _
            ["^{LEFT}", $hDummyCtrlLeft], _
            ["^{RIGHT}", $hDummyCtrlRight], _
            ["^t", $hDummyCtrlT], _
            ["^+t", $hDummyCtrlShiftT], _
            ["{HOME}", $hDummyHome], _
            ["{END}", $hDummyEnd], _
            ["1", $hDummy1], _
            ["2", $hDummy2], _
            ["3", $hDummy3], _
            ["4", $hDummy4], _
            ["5", $hDummy5], _
            ["6", $hDummy6], _
            ["7", $hDummy7], _
            ["8", $hDummy8], _
            ["9", $hDummy9], _
            ["^w", $hDummyCtrlW], _
            ["-", $hDummyMinus], _
            ["=", $hDummyEqual], _
            ["s", $hDummyS], _
            ["d", $hDummyD], _
            ["f", $hDummyF], _
            ["^+e", $hDummyCtrlShiftE], _
            ["{ESC}", $hDummyEsc], _
            ["^g", $hDummyG], _
            ["{APPS}", $hDummyApps], _
            ["+{F10}", $hDummyApps], _
            ["!b", $hDummyAltB], _
            ["!g", $hDummyAltG], _
            ["{[}", $hDummyBracketLeft], _
            ["{]}", $hDummyBracketRight], _
            ["^s", $hDummyCtrlS], _
            ["^k", $hDummyCtrlK], _
            ["^c", $hDummyCtrlC], _
            ["^+c", $hDummyCtrlShiftC], _
            ["^+d", $hDummyCtrlShiftD] _
        ]
        GUISetAccelerators($aAccelPlay, $hPlayGui)
    Else
        $g_sCurrentVideoTitle = $sTitle
        WinSetTitle($hPlayGui, "", $sTitle)
        GUICtrlSetData($g_lblPlayerInfo, "Playing: ")
    EndIf

    ; Reset selection on new track
    $g_fSelectionStart = -1
    $g_fSelectionEnd = -1

    While GUIGetMsg() <> 0
    WEnd

    $oWMP.url = $sUrl
    $oWMP.settings.volume = 100
    $oWMP.uiMode = "none"

    If (Not $allowAutoPlayToggle) Or (Not $g_bAutoPlay) Then GUICtrlSetState($g_lblAuto, $GUI_HIDE)
    If $allowAutoPlayToggle And $g_bAutoPlay Then
        GUICtrlSetState($g_lblAuto, $GUI_SHOW)
        GUICtrlSetData($g_lblAuto, "Auto: ON")
    EndIf
    If $allowAutoPlayToggle And Not $g_bAutoPlay Then
        GUICtrlSetState($g_lblAuto, $GUI_SHOW)
        GUICtrlSetData($g_lblAuto, "Auto: OFF")
    EndIf

    If Not $g_bRepeat Then GUICtrlSetData($g_lblRepeat, "Repeat: OFF")
    If $g_bRepeat Then GUICtrlSetData($g_lblRepeat, "Repeat: ON")

    Local $sAction = ""
    Local $bLoaded = False
    Local $iLoadStartTime = TimerInit()

    While 1
        Local $nMsg = GUIGetMsg()
        If $nMsg = 0 Then
            Sleep(1)
            ContinueLoop
        EndIf

        Switch $nMsg
            Case $GUI_EVENT_CLOSE
                $sAction = "CLOSE"
                ExitLoop

            Case $menu_item_download
                _ShowDownloadDialog($sID, $sTitle)
            Case $menu_item_channel, $hDummyAltG
                Local $hLoadingTmp = GUICreate("Working...", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW), $hPlayGui)
                GUICtrlCreateLabel("Fetching channel information...", 10, 25, 230, 20, $SS_CENTER)
                GUISetBkColor(0xFFFFFF, $hLoadingTmp)
                GUISetState(@SW_SHOW, $hLoadingTmp)
                Local $pid_channel = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" --print "https://www.youtube.com/channel/%(channel_id)s" --no-playlist -- "' & $sID & '""', @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
                Local $sChannelUrl = ""
                While ProcessExists($pid_channel)
                    $sChannelUrl &= StdoutRead($pid_channel)
                    Sleep(1)
                WEnd
                $sChannelUrl &= StdoutRead($pid_channel)
                GUIDelete($hLoadingTmp)
                $sChannelUrl = StringStripWS($sChannelUrl, 3)
                Local $pattern = "(https://www\.youtube\.com/(channel/|@)[^ \r\n]+)"
                Local $aMatch = StringRegExp($sChannelUrl, $pattern, 3)
                If IsArray($aMatch) Then
                    ShellExecute($aMatch[0])
                Else
                    MsgBox(16, "Error", "Cannot get channel URL.")
                EndIf
            Case $menu_item_browser, $hDummyAltB
                ShellExecute("https://www.youtube.com/watch?v=" & $sID)
            Case $menu_item_copy
                ClipPut("https://www.youtube.com/watch?v=" & $sID)
                MsgBox(64, "Info", "Link copied to clipboard!")
            Case $menu_item_desc, $hDummyCtrlShiftD
                Local $hWaitDesc = GUICreate("Loading...", 250, 80, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW), $hPlayGui)
                GUICtrlCreateLabel("Fetching Description...", 10, 25, 230, 20, $SS_CENTER)
                GUISetBkColor(0xFFFFFF, $hWaitDesc)
                GUISetState(@SW_SHOW, $hWaitDesc)
                Local $iPIDDesc = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" --get-description --no-playlist --encoding utf-8 -- "' & $sID & '""', @ScriptDir, @SW_HIDE, $STDOUT_CHILD)
                Local $bDataDesc = Binary("")
                While ProcessExists($iPIDDesc)
                    $bDataDesc &= StdoutRead($iPIDDesc, False, True)
                    Sleep(1)
                WEnd
                $bDataDesc &= StdoutRead($iPIDDesc, False, True)
                GUIDelete($hWaitDesc)
                Local $sDescStr = BinaryToString($bDataDesc, 4)
                If $sDescStr = "" Then
                    MsgBox(64, "Info", "No description available.")
                Else
                    Local $sTempFileDesc = @TempDir & "\temp_desc.txt"
                    Local $hFileDesc = FileOpen($sTempFileDesc, 2 + 256)
                    FileWrite($hFileDesc, $sDescStr)
                    FileClose($hFileDesc)
                    Run('"' & $DESC_EXE_PATH & '" "' & $sTempFileDesc & '"')
                EndIf
            Case $menu_item_comments
                Run('"' & $COMMENTS_EXE_PATH & '" "https://www.youtube.com/watch?v=' & $sID & '"')
            Case $menu_item_fav
                If _IsFavorite($sID) Then
                    If _RemoveFavorite($sID) Then
                        GUICtrlSetData($menu_item_fav, "Add to &Favorite...")
                        _ReportStatus("Removed from favorites")
                    EndIf
                Else
                    _AddFavorite($sID, $sTitle)
                    GUICtrlSetData($menu_item_fav, "Remove from &Favorite...")
                    _ReportStatus("Added to favorites")
                EndIf
            Case $menu_item_goto
                _ShowGoToTime()

            Case $hDummyAltO
                ; Mở menu Options chuẩn xác bằng tổ hợp F10 và phím tắt menu
                ControlSend($hPlayGui, "", "", "{F10}")
                ControlSend($hPlayGui, "", "", "o")

            Case $hDummyCtrlK
                ClipPut("https://www.youtube.com/watch?v=" & $sID)
                _ReportStatus("Link copied to clipboard")

            Case $hDummyCtrlC
                Local $sCleanID = StringStripWS($sID, 3)
                Local $sFinalLink = ""
                Local $fPos = $oWMP.controls.currentPosition
                If $fPos <= 0 Then $fPos = $oWMP.currentPosition

                ; Nếu chưa đặt điểm [ thì tự động lấy thời gian hiện tại
                Local $iStart = ($g_fSelectionStart <> -1) ? Int($g_fSelectionStart) : Int($fPos)

                If $g_fSelectionEnd <> -1 Then
                    Local $iEnd = Int($g_fSelectionEnd)
                    ; Đảo ngược nếu điểm kết thúc nhỏ hơn điểm bắt đầu
                    If $iEnd < $iStart Then
                        Local $tmp = $iStart
                        $iStart = $iEnd
                        $iEnd = $tmp
                    EndIf
                    ; Tạo link đoạn (Range). Sử dụng link embed để trình duyệt tự động dừng ở điểm kết thúc.
                    $sFinalLink = "https://www.youtube.com/embed/" & $sCleanID & "?start=" & $iStart & "&end=" & $iEnd & "&autoplay=1"
                    _ReportStatus("Range link (Embed) copied: " & _FormatTime($iStart) & " to " & _FormatTime($iEnd))
                Else
                    ; Nếu không có điểm kết thúc, tạo link tại mốc thời gian bắt đầu
                    $sFinalLink = "https://www.youtube.com/watch?v=" & $sCleanID & "&t=" & $iStart & "s"
                    If $g_fSelectionStart <> -1 Then
                        _ReportStatus("Link from start point copied: " & _FormatTime($iStart))
                    Else
                        _ReportStatus("Current time link copied: " & _FormatTime($iStart))
                    EndIf
                EndIf

                ClipPut($sFinalLink)

            Case $hDummyCtrlShiftC
                Run('"' & $COMMENTS_EXE_PATH & '" "https://www.youtube.com/watch?v=' & $sID & '"')

            Case $hDummyBracketLeft
                ; Lấy vị trí hiện tại
                Local $fPos = $oWMP.controls.currentPosition
                If $fPos <= 0 Then $fPos = $oWMP.currentPosition
                $g_fSelectionStart = $fPos
                _ReportStatus("Start selection: " & _FormatTime($g_fSelectionStart))

            Case $hDummyBracketRight
                Local $fPos = $oWMP.controls.currentPosition
                If $fPos <= 0 Then $fPos = $oWMP.currentPosition
                $g_fSelectionEnd = $fPos
                _ReportStatus("End selection: " & _FormatTime($g_fSelectionEnd))

            Case $hDummyCtrlS
                If $g_fSelectionStart = -1 Or $g_fSelectionEnd = -1 Then
                    _ReportStatus("Please set both start and end selection points.")
                Else
                    _SaveSelection($sUrl, $sTitle)
                EndIf

            Case $hDummy1, $hDummy2, $hDummy3, $hDummy4, $hDummy5, $hDummy6, $hDummy7, $hDummy8, $hDummy9
                Local $iPercent = ($nMsg - $hDummy1 + 1) * 10
                Local $fDuration = $oWMP.currentMedia.duration
                If $fDuration > 0 Then
                    $oWMP.controls.currentPosition = ($iPercent / 100) * $fDuration
                    _ReportStatus("Seek to " & $iPercent & "%")
                EndIf

            Case $hDummySpace
                Local $ps = $oWMP.playState
                If $ps = 3 Then
                    $oWMP.controls.pause()
                    _ReportStatus("Paused")
                ElseIf $ps = 2 Or $ps = 1 Then
                    $oWMP.controls.play()
                    _ReportStatus("Play")
                EndIf

            Case $hDummyCtrlShiftE
                If Not $bAudioOnly Then
                    $g_bCinemaMode = Not $g_bCinemaMode
                    If $g_bCinemaMode Then
                        Local $aPos = WinGetPos($hPlayGui)
                        $g_iOriginalX = $aPos[0]
                        $g_iOriginalY = $aPos[1]
                        $g_iOriginalW = $aPos[2]
                        $g_iOriginalH = $aPos[3]
                        GUISetStyle(BitOR($WS_POPUP, $WS_VISIBLE), -1, $hPlayGui)
                        WinMove($hPlayGui, "", 0, 0, @DesktopWidth, @DesktopHeight)
                        GUICtrlSetPos($oWMPCtrl, 0, 0, @DesktopWidth, @DesktopHeight)
                        _ReportStatus("Cinema Mode Enabled")
                    Else
                        GUISetStyle(BitOR($WS_CAPTION, $WS_SYSMENU, $WS_POPUP, $WS_SIZEBOX, $WS_VISIBLE), -1, $hPlayGui)
                        WinMove($hPlayGui, "", $g_iOriginalX, $g_iOriginalY, $g_iOriginalW, $g_iOriginalH)
                        GUICtrlSetPos($oWMPCtrl, 0, 0, $iWidth, $iHeight)
                        _ReportStatus("Cinema Mode Disabled")
                    EndIf
                EndIf

            Case $hDummyN
                If $allowAutoPlayToggle Then
                    $g_bAutoPlay = Not $g_bAutoPlay
                    GUICtrlSetData($g_lblAuto, $g_bAutoPlay ? "Auto: ON" : "Auto: OFF")
                    _ReportStatus($g_bAutoPlay ? "Auto Play Next Track ON" : "Auto Play Next Track OFF")
                EndIf

            Case $hDummyR
                $g_bRepeat = Not $g_bRepeat
                GUICtrlSetData($g_lblRepeat, $g_bRepeat ? "Repeat: ON" : "Repeat: OFF")
                _ReportStatus($g_bRepeat ? "Repeat ON" : "Repeat OFF")

            Case $hDummyShiftN
                $sAction = "NEXT"
                ExitLoop

            Case $hDummyShiftB
                $sAction = "BACK"
                ExitLoop

            Case $hDummyHome
                $oWMP.controls.currentPosition = 0
                _ReportStatus("Restart from beginning")

            Case $hDummyEnd
                Local $fDuration = $oWMP.currentMedia.duration
                If $fDuration > 0 Then
                    $oWMP.controls.currentPosition = $fDuration - 20
                    _ReportStatus("Near end")
                Else
                    $sAction = "STOP"
                    ExitLoop
                EndIf

            Case $hDummyCtrlW
                SoundPlay(@ScriptDir & "\sounds\exit.wav", 1)
                ProcessClose("comments.exe")
                ProcessClose("description.exe")
                Exit

            Case $hDummyMinus
                If $g_iFFStep > 1 Then $g_iFFStep -= 1
                If $g_iRWStep > 1 Then $g_iRWStep -= 1
                $g_iSeekStep = $g_iFFStep
                _ReportStatus("Seek Step: Forward " & $g_iFFStep & "s, Backward " & $g_iRWStep & "s")

            Case $hDummyEqual
                $g_iFFStep += 1
                $g_iRWStep += 1
                $g_iSeekStep = $g_iFFStep
                _ReportStatus("Seek Step: Forward " & $g_iFFStep & "s, Backward " & $g_iRWStep & "s")

            Case $hDummyUp
                Local $iVol = $oWMP.settings.volume + 5
                If $iVol > 100 Then $iVol = 100
                $oWMP.settings.volume = $iVol
                _ReportStatus("Volume: " & $iVol & "%")

            Case $hDummyDown
                Local $iVol = $oWMP.settings.volume - 5
                If $iVol < 0 Then $iVol = 0
                $oWMP.settings.volume = $iVol
                _ReportStatus("Volume: " & $iVol & "%")

            Case $hDummyS
                Local $fRate = Round($oWMP.settings.rate - 0.1, 1)
                If $fRate < 0.1 Then $fRate = 0.1
                $oWMP.settings.rate = $fRate
                _ReportStatus("Speed: " & $fRate & "x")

            Case $hDummyD
                $oWMP.settings.rate = 1.0
                _ReportStatus("Speed: 1.0x (Normal)")

            Case $hDummyF
                Local $fRate = Round($oWMP.settings.rate + 0.1, 1)
                If $fRate > 5.0 Then $fRate = 5.0
                $oWMP.settings.rate = $fRate
                _ReportStatus("Speed: " & $fRate & "x")

            Case $hDummyLeft
                Local $fCurPos = $oWMP.controls.currentPosition
                $oWMP.controls.currentPosition = ($fCurPos - $g_iRWStep < 0) ? 0 : $fCurPos - $g_iRWStep

            Case $hDummyRight
                Local $fCurPos = $oWMP.controls.currentPosition
                $oWMP.controls.currentPosition = $fCurPos + $g_iFFStep

            Case $hDummyEsc
                $sAction = "CLOSE"
                ExitLoop

            Case $hDummyG
                _ShowGoToTime()

            Case $hDummyApps
                _ShowPlayerContextMenu()

            Case $hDummyCtrlT
                Local $sElapsed = $oWMP.controls.currentPositionString
                _ReportStatus("Elapsed Time: " & $sElapsed)

            Case $hDummyCtrlShiftT
                Local $sTotal = $oWMP.currentMedia.durationString
                _ReportStatus("Total Duration: " & $sTotal)
        EndSwitch

        Local $iCurState = $oWMP.playState
        If Not $bLoaded And ($iCurState = 3 Or $iCurState = 2 Or $iCurState = 6 Or TimerDiff($iLoadStartTime) > 30000) Then
            If $hLoading <> 0 Then GUIDelete($hLoading)
            $hLoading = 0
            $bLoaded = True
        EndIf

        If $oWMP.playState = 1 And $bLoaded Then
             If $g_bRepeat Then
                 $sAction = "RESTART"
             Else
                 Switch $g_iAfterVideoAction
                     Case 0
                         $sAction = "CLOSE"
                     Case 1
                         $sAction = "RESTART"
                     Case 2
                         $sAction = "FINISHED"
                 EndSwitch
             EndIf
             ExitLoop
        EndIf
        Sleep(30)
    WEnd
    HotKeySet("!o") ; Hủy đăng ký HotKey khi thoát trình phát
    If $hLoading <> 0 Then GUIDelete($hLoading)
    Return $sAction
EndFunc

Func _SaveSelection($sUrl, $sTitle)
    Local $fStart = $g_fSelectionStart
    Local $fEnd = $g_fSelectionEnd

    If $fStart = -1 Or $fEnd = -1 Then
        _ReportStatus("Error: Please set both start [ and end ] points.")
        Return
    EndIf

    If $fStart > $fEnd Then
        Local $tmp = $fStart
        $fStart = $fEnd
        $fEnd = $tmp
        _ReportStatus("Start/End swapped to match timeline.")
    EndIf

    Local $fDuration = $fEnd - $fStart
    If $fDuration <= 0 Then
        _ReportStatus("Invalid selection duration.")
        Return
    EndIf

    Local $sSafeTitle = StringRegExpReplace($sTitle, '[\\/:*?"<>|]', '_')

    ; Redesigned Save Selection: Use FileSaveDialog to let user choose name, type and path
    Local $sFilter = "MP3 Audio (*.mp3)|M4A Audio (*.m4a)|WAV Audio (*.wav)|FLAC Audio (*.flac)|All Files (*.*)"
    Local $sInitialDir = @ScriptDir & "\download"
    If Not FileExists($sInitialDir) Then DirCreate($sInitialDir)

    Local $sFilePath = FileSaveDialog("Save selection as...", $sInitialDir, $sFilter, 18, $sSafeTitle & "_selection.mp3")
    If @error Then
        _ReportStatus("Save cancelled.")
        Return
    EndIf

    ; Ensure correct extension if user didn't type it
    ; We check the filter index or just look at the filename
    Local $sAudioCodec = "-c:a libmp3lame -q:a 2" ; Default MP3
    If StringRegExp($sFilePath, "(?i)\.m4a$") Then
        $sAudioCodec = "-c:a aac -b:a 192k"
    ElseIf StringRegExp($sFilePath, "(?i)\.wav$") Then
        $sAudioCodec = "-c:a pcm_s16le"
    ElseIf StringRegExp($sFilePath, "(?i)\.flac$") Then
        $sAudioCodec = "-c:a flac"
    ElseIf Not StringRegExp($sFilePath, "(?i)\.mp3$") Then
        ; If no known extension, append .mp3 as default
        $sFilePath &= ".mp3"
    EndIf

    _ReportStatus("Saving selection... Please wait.")

    Local $sFFmpeg = @ScriptDir & "\lib\ffmpeg.exe"
    If Not FileExists($sFFmpeg) Then
        MsgBox(16, "Error", "ffmpeg.exe not found in lib folder!")
        Return
    EndIf

    ; ffmpeg command with dynamic codec selection
    Local $sCmd = '"' & $sFFmpeg & '" -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_delay_max 2 -ss ' & $fStart & ' -to ' & $fEnd & ' -i "' & $sUrl & '" -vn ' & $sAudioCodec & ' -y "' & $sFilePath & '"'
    Local $iPid = Run($sCmd, @ScriptDir, @SW_HIDE)

    Local $iBeginWait = TimerInit()
    While ProcessExists($iPid)
        Sleep(10)
        ; Safety timeout 10 mins
        If TimerDiff($iBeginWait) > 600000 Then
            ProcessClose($iPid)
            ExitLoop
        EndIf
    WEnd

    If FileExists($sFilePath) And FileGetSize($sFilePath) > 1000 Then
        _ReportStatus("Selection saved successfully.")
        MsgBox(64, "Success", "Selection saved successfully as:" & @CRLF & $sFilePath)
    Else
        _ReportStatus("Failed to save selection.")
        MsgBox(16, "Error", "Failed to save selection. This can happen if the YouTube stream link expired or ffmpeg was blocked.")
    EndIf
EndFunc

Func _FormatTime($fSeconds)
    Local $iSec = Int($fSeconds)
    Local $iMin = Int($iSec / 60)
    Local $iHour = Int($iMin / 60)
    $iMin = Mod($iMin, 60)
    $iSec = Mod($iSec, 60)
    If $iHour > 0 Then
        Return StringFormat("%02d:%02d:%02d", $iHour, $iMin, $iSec)
    Else
        Return StringFormat("%02d:%02d", $iMin, $iSec)
    EndIf
EndFunc

Func online_play($url)
    ShellExecute($url)
EndFunc

Func _ReportStatus($sText)
    If $sText == "" Or Not $g_bSpeakStatus Then Return

    ; Suppress duplicates within 1s to be safe
    If StringLower($sText) = StringLower($g_sLastReportedText) And TimerDiff($g_iLastReportedTime) < 1000 Then Return
    $g_sLastReportedText = $sText
    $g_iLastReportedTime = TimerInit()

    ; Update the visual status label on the GUI
    If IsHWnd($hPlayGui) And $g_hStatusLabel <> 0 Then
        GUICtrlSetData($g_hStatusLabel, $sText)
        AdlibRegister("_ClearToolTip", 2000)
    EndIf

    ; If enabled in settings, speak it explicitly
    _NVDA_Speak($sText)
EndFunc

Func _NVDA_Speak($sText)
    ; Final safety check
    If Not $g_bSpeakStatus Then Return False

    ; Thử khởi tạo DLL nếu chưa có hoặc đã bị đóng
    If $g_hNVDADll = -1 Then
        Local $sDllName = @AutoItX64 ? "nvdaControllerClient64.dll" : "nvdaControllerClient32.dll"
        Local $sDllPath = @ScriptDir & "\lib\" & $sDllName
        $g_hNVDADll = DllOpen($sDllPath)
    EndIf

    Local $bNVDASuccess = False

    If $g_hNVDADll <> -1 Then
        ; Gọi trực tiếp nvdaController_speakText để thông báo cho NVDA
        Local $aRet = DllCall($g_hNVDADll, "int", "nvdaController_speakText", "wstr", $sText)
        If Not @error And IsArray($aRet) And $aRet[0] = 0 Then
            $bNVDASuccess = True
        EndIf
    EndIf

    ; Nếu NVDA không khả dụng hoặc lỗi, dùng SAPI 5 làm phương án dự phòng
    If Not $bNVDASuccess Then
        If Not IsObj($oVoice) Then $oVoice = ObjCreate("SAPI.SpVoice")
        If IsObj($oVoice) Then $oVoice.Speak($sText, 1) ; 1 = Async
    EndIf

    Return $bNVDASuccess
EndFunc

Func _ClearToolTip()
    If IsHWnd($hPlayGui) And $g_hStatusLabel <> 0 Then
        GUICtrlSetData($g_hStatusLabel, "")
    EndIf
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
    Local $pid = Run(@ComSpec & ' /c ""' & $YT_DLP_PATH & '" --encoding utf-8 --get-title --no-playlist --no-check-certificate -4 -- "' & $url & '""', @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
    Local $bData = Binary("")
    While ProcessExists($pid)
        $bData &= StdoutRead($pid, False, True)
        Sleep(1)
    WEnd
    $bData &= StdoutRead($pid, False, True)
    Return StringStripWS(BinaryToString($bData, 4), 3)
EndFunc

Func _AddHistory($sID, $sTitle, $sType = "video")
    If $sID = "" Or $sTitle = "" Then Return
	If $sType = "" Then $sType = "video"

    ; Prevent duplicates (optional but good for history)
    Local $sContent = ""
	If FileExists($HISTORY_FILE) Then $sContent = FileRead(FileOpen($HISTORY_FILE, 0 + 256))
    If StringInStr($sContent, $sID & "|") Then
        _RemoveHistory($sID) ; Remove old entry to move it to the top
    EndIf

    Local $hFile = FileOpen($HISTORY_FILE, 1 + 8 + 256) ; 1=Append, 8=DirCreate, 256=UTF8
    If $hFile = -1 Then Return
    FileWriteLine($hFile, $sID & "|" & $sTitle & "|" & $sType)
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
    Local $hDummyAudioFav = GUICtrlCreateDummy()
    Local $hDummyCommentsFav = GUICtrlCreateDummy()
    Local $hDummyEnterFav = GUICtrlCreateDummy()
    Local $hDummyHomeFav = GUICtrlCreateDummy()
    Local $hDummyEndFav = GUICtrlCreateDummy()
    Local $hDummyEscFav = GUICtrlCreateDummy()
    Local $aAccel[9][2] = [ _
        ["^k", $dummy_copy], _
        ["!b", $dummy_browser], _
        ["!g", $dummy_channel], _
        ["^{ENTER}", $hDummyAudioFav], _
        ["^+c", $hDummyCommentsFav], _
        ["{ENTER}", $hDummyEnterFav], _
        ["{HOME}", $hDummyHomeFav], _
        ["{END}", $hDummyEndFav], _
        ["{ESC}", $hDummyEscFav] _
    ]
    GUISetAccelerators($aAccel, $hFavoritesGui)

    GUISetState(@SW_SHOW, $hFavoritesGui)

    _LoadFavorites()
    _GUICtrlListBox_SetCurSel($lst_results, 0)
    ControlFocus($hFavoritesGui, "", $lst_results)

    While 1
        Local $nMsg = GUIGetMsg()

        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $btn_go_back
                GUIDelete($hFavoritesGui)
                $hFavoritesGui = 0
                GUISetState(@SW_SHOW, $mainform)
                Return
            Case $hDummyEnterFav
                If ControlGetHandle($hFavoritesGui, "", ControlGetFocus($hFavoritesGui)) = GUICtrlGetHandle($lst_results) Then
                    _PlayLoop(_GUICtrlListBox_GetCurSel($lst_results), False) ; Enter = Play Video
                EndIf
            Case $hDummyAudioFav
                If ControlGetHandle($hFavoritesGui, "", ControlGetFocus($hFavoritesGui)) = GUICtrlGetHandle($lst_results) Then
                    _PlayLoop(_GUICtrlListBox_GetCurSel($lst_results), True) ; Ctrl+Enter = Play Audio
                EndIf
            Case $hDummyHomeFav
                _GUICtrlListBox_SetCurSel($lst_results, 0)
            Case $hDummyEndFav
                _GUICtrlListBox_SetCurSel($lst_results, _GUICtrlListBox_GetCount($lst_results) - 1)
            Case $hDummyEscFav
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
    $lst_results = GUICtrlCreateList("", 10, 10, 380, 350, BitOR($LBS_NOTIFY, $WS_VSCROLL, $WS_BORDER))

    Local $btn_clear_all = GUICtrlCreateButton("Clear all history", 10, 370, 380, 30)
    Local $btn_go_back = GUICtrlCreateButton("Go back (Alt+B)", 10, 410, 380, 30)

    Local $dummy_copy = GUICtrlCreateDummy()
    Local $dummy_browser = GUICtrlCreateDummy()
    Local $dummy_channel = GUICtrlCreateDummy()
    Local $hDummyAudioHist = GUICtrlCreateDummy()
    Local $hDummyCommentsFav = GUICtrlCreateDummy()
    Local $hDummyEnterHist = GUICtrlCreateDummy()
    Local $hDummyHomeHist = GUICtrlCreateDummy()
    Local $hDummyEndHist = GUICtrlCreateDummy()
    Local $hDummyEscHist = GUICtrlCreateDummy()
    Local $aAccel[10][2] = [ _
        ["^k", $dummy_copy], _
        ["!b", $btn_go_back], _ ; Alt+B linked directly to button
        ["!g", $dummy_channel], _
        ["^{ENTER}", $hDummyAudioHist], _
        ["^+c", $hDummyCommentsFav], _
        ["{ENTER}", $hDummyEnterHist], _
        ["{HOME}", $hDummyHomeHist], _
        ["{END}", $hDummyEndHist], _
        ["{ESC}", $hDummyEscHist], _
        ["!b", $btn_go_back] _
    ]
    GUISetAccelerators($aAccel, $hHistoryGui)

    GUISetState(@SW_SHOW, $hHistoryGui)

    _LoadHistory()
    _GUICtrlListBox_SetCurSel($lst_results, 0)
    ControlFocus($hHistoryGui, "", $lst_results)

    While 1
        Local $nMsg = GUIGetMsg()

        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $btn_go_back, $hDummyEscHist
                GUIDelete($hHistoryGui)
                $hHistoryGui = 0
                GUISetState(@SW_SHOW, $mainform)
                Return
            Case $hDummyEnterHist
                If ControlGetHandle($hHistoryGui, "", ControlGetFocus($hHistoryGui)) = GUICtrlGetHandle($lst_results) Then
                    Local $iSel = _GUICtrlListBox_GetCurSel($lst_results)
                    If $iSel <> -1 Then
                        Local $sItemType = $aSearchTypes[$iSel + 1]
                        If $sItemType = "playlist" Then
                            _ShowPlaylistVideos($aSearchIds[$iSel + 1], $aSearchTitles[$iSel + 1])
                        Else
                            _PlayLoop($iSel, False) ; Video
                        EndIf
                    EndIf
                EndIf
            Case $hDummyAudioHist
                If ControlGetHandle($hHistoryGui, "", ControlGetFocus($hHistoryGui)) = GUICtrlGetHandle($lst_results) Then
                    Local $iSel = _GUICtrlListBox_GetCurSel($lst_results)
                    If $iSel <> -1 Then
                        Local $sItemType = $aSearchTypes[$iSel + 1]
                        If $sItemType = "video" Then
                            _PlayLoop($iSel, True) ; Ctrl+Enter = Play Audio
                        Else
                            _ReportStatus("Cannot play a playlist in audio-only mode directly. Please open the playlist first.")
                        EndIf
                    EndIf
                EndIf
            Case $hDummyHomeHist
                _GUICtrlListBox_SetCurSel($lst_results, 0)
            Case $hDummyEndHist
                _GUICtrlListBox_SetCurSel($lst_results, _GUICtrlListBox_GetCount($lst_results) - 1)
            Case $hDummyEscHist
                GUIDelete($hHistoryGui)
                GUISetState(@SW_SHOW, $mainform)
                Return
            Case $btn_clear_all
                If MsgBox(36, "Confirm", "Are you sure you want to clear all history?") = 6 Then
                    _ClearHistory()
                    _LoadHistory()
                    _GUICtrlListBox_SetCurSel($lst_results, 0)
                    ControlFocus($hHistoryGui, "", $lst_results)
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
		Return
	EndIf

	Local $aHistoryLines = StringSplit(StringStripCR($sContent), @LF)
	Global $aSearchIds[1]
	Global $aSearchTitles[1]
	Global $aSearchTypes[1] ; <-- IMPORTANT
	$iTotalLoaded = 0
	$bEndReached = True

	; Show from newest to oldest
	For $i = $aHistoryLines[0] To 1 Step -1
		Local $sLine = $aHistoryLines[$i]
		If $sLine = "" Then ContinueLoop

		Local $aParts = StringSplit($sLine, "|")
		If $aParts[0] >= 2 Then
			Local $sID = $aParts[1]
			Local $sTitle = $aParts[2]
			Local $sType = ($aParts[0] >= 3) ? $aParts[3] : "video" ; Read type, default to video

			$iTotalLoaded += 1
			Local $sDisplayTitle = $iTotalLoaded & ". " & $sTitle
			If $sType = "playlist" Then
				$sDisplayTitle &= " [Playlist]" ; Add a visual indicator
			EndIf
			_GUICtrlListBox_AddString($lst_results, $sDisplayTitle)

			ReDim $aSearchIds[$iTotalLoaded + 1]
			ReDim $aSearchTitles[$iTotalLoaded + 1]
			ReDim $aSearchTypes[$iTotalLoaded + 1] ; <-- IMPORTANT
			$aSearchIds[$iTotalLoaded] = $sID
			$aSearchTitles[$iTotalLoaded] = $sTitle
			$aSearchTypes[$iTotalLoaded] = $sType ; <-- IMPORTANT
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

    Local $sCheckingText = "Checking for updates yt-dlp..."
    Local $hCheckGUI = GuiCreate("", 300, 80, -1, -1, BitOR($WS_CAPTION, $WS_POPUP), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
    GuiSetBkColor(0xFFFFFF, $hCheckGUI)
    Local $lblCheck = GuiCtrlCreateLabel($sCheckingText, 10, 25, 280, 30, $ES_CENTER)
    GuiCtrlSetFont($lblCheck, 10, 400, 0, "Arial")
    GuiSetState(@SW_SHOW, $hCheckGUI)

    If Ping("github.com", 2000) = 0 And Ping("google.com", 2000) = 0 Then
         GuiDelete($hCheckGUI)
         MsgBox(48, "Check Update", "No internet connection.")
         Return
    EndIf

    Local $sRepoOwner = "yt-dlp"
    Local $sRepoName = "yt-dlp"
    Local $sApiUrl = "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest"

    Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")
    If Not IsObj($oHTTP) Then
        GuiDelete($hCheckGUI)
        MsgBox(16, "Error", "Cannot create HTTP Object.")
        Return
    EndIf

    $oHTTP.Open("GET", $sApiUrl, False)
    $oHTTP.SetRequestHeader("User-Agent", "Mozilla/5.0")
    $oHTTP.Send()

    If @error Then
        GuiDelete($hCheckGUI)
        MsgBox(48, "Check Update", "Connection failed. Please check your internet.")
        Return
    EndIf

    If $oHTTP.Status <> 200 Then
        GuiDelete($hCheckGUI)
        MsgBox(48, "Check Update", "Cannot connect to update server or no release found." & @CRLF & "Status Code: " & $oHTTP.Status)
        Return
    EndIf

    Local $sResponse = $oHTTP.ResponseText
    GuiDelete($hCheckGUI)

    Local $aMatch = StringRegExp($sResponse, '"tag_name":\s*"([^"]+)"', 3)

    If IsArray($aMatch) Then
        Local $sLatestVersion = $aMatch[0]
        $sLatestVersion = StringRegExpReplace($sLatestVersion, "[^0-9.]", "")
        Local $sLocalVersion = _Get_YTDLP_LocalVersion()

        If $sLatestVersion <> $sLocalVersion Then
            Local $sVerInfo = "A new version (" & $sLatestVersion & ") is available!" & @CRLF
            If $sLocalVersion <> "0" Then
                $sVerInfo &= "Your version: " & $sLocalVersion
            Else
                $sVerInfo &= "Your version: Not installed or unknown"
            EndIf

            Local $iMsg = MsgBox(36, "Update Available", $sVerInfo & @CRLF & @CRLF & _
                                     "Do you want to download it now?")
            If $iMsg = 6 Then
                $downloadtext = "please wait..."
                $downloadGui = GuiCreate("downloading update...", 400, 100, -1, -1)
                GuiSetBkColor($COLOR_WHITE)
                GuiCtrlCreateLabel($downloadtext, 40, 40)
                GuiSetState(@SW_SHOW, $downloadGui)
                Local $sDownloadURL = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
                DirCreate(@ScriptDir & "\lib")
                Local $sSavePathTemp = @ScriptDir & "\lib\yt-dlp.exe.new"
                Local $sSavePathFinal = @ScriptDir & "\lib\yt-dlp.exe"

                ProgressOn("Downloading Update", "Please wait while downloading...", "0%")

                Local $hDownload = InetGet($sDownloadURL, $sSavePathTemp, 1, 1)

                Do
                    Sleep(10)
                    Local $iBytesRead = InetGetInfo($hDownload, 0)
                    Local $iFileSize = InetGetInfo($hDownload, 1)

                    If $iFileSize > 0 Then
                        Local $iPct = Round(($iBytesRead / $iFileSize) * 100)
                        ProgressSet($iPct, $iPct & "% complete")
                    Else
                        ProgressSet(0, "Connecting...")
                    EndIf

                Until InetGetInfo($hDownload, 2)

                Local $bSuccess = InetGetInfo($hDownload, 3)
                Local $iError = InetGetInfo($hDownload, 4)
                InetClose($hDownload)
                ProgressOff()
                GuiDelete($downloadGui)

                If Not $bSuccess Then
                    MsgBox(16, "Error", "Download failed. Error code: " & $iError)
                    FileDelete($sSavePathTemp)
                    Return
                EndIf

                If FileExists($sSavePathTemp) And FileGetSize($sSavePathTemp) > 0 Then
                    ; Close any running yt-dlp.exe processes
                    While ProcessExists("yt-dlp.exe")
                        ProcessClose("yt-dlp.exe")
                        Sleep(50)
                    WEnd

                    ; Wait a bit to ensure file is not locked
                    Sleep(100)

                    FileDelete($sSavePathFinal)
                    If FileMove($sSavePathTemp, $sSavePathFinal, 1) Then
                        MsgBox(64, "Success", "yt-dlp has been updated successfully!")
                        If MsgBox(36, "Restart Required", "The software needs to restart to apply the update. Restart now?") = 6 Then
                            ShellExecute(@ScriptFullPath)
                            Exit
                        EndIf
                    Else
                        MsgBox(16, "Error", "Failed to replace yt-dlp.exe. Please close any programs using it and try again.")
                        FileDelete($sSavePathTemp)
                    EndIf
                EndIf
            EndIf
        Else
            MsgBox(64, "no update available", "You are using the latest version from yt-dlp.")
        EndIf
    Else
        MsgBox(16, "Error", "Could not parse version information.")
    EndIf
EndFunc

Func _CheckGithubUpdate()

    Local $sCheckingText = "Checking for updates..."
    Local $hCheckGUI = GuiCreate("", 300, 80, -1, -1, BitOR($WS_CAPTION, $WS_POPUP), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
    GuiSetBkColor(0xFFFFFF, $hCheckGUI)
    Local $lblCheck = GuiCtrlCreateLabel($sCheckingText, 10, 25, 280, 30, $ES_CENTER)
    GuiCtrlSetFont($lblCheck, 10, 400, 0, "Arial")
    GuiSetState(@SW_SHOW, $hCheckGUI)

    If Ping("github.com", 2000) = 0 And Ping("google.com", 2000) = 0 Then
         GuiDelete($hCheckGUI)
         MsgBox(48, "Check Update", "No internet connection.")
         Return
    EndIf

    Local $sRepoOwner = "vo-dinh-hung"
    Local $sRepoName = "vdh_youtube_downloader"
    Local $sApiUrl = "https://api.github.com/repos/vo-dinh-hung/vdh_youtube_downloader/releases/latest"

    Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")
    If Not IsObj($oHTTP) Then
        GuiDelete($hCheckGUI)
        MsgBox(16, "Error", "Cannot create HTTP Object.")
        Return
    EndIf

    $oHTTP.Open("GET", $sApiUrl, False)
    $oHTTP.SetRequestHeader("User-Agent", "Mozilla/5.0")
    $oHTTP.Send()

    If @error Then
        GuiDelete($hCheckGUI)
        MsgBox(48, "Check Update", "Connection failed. Please check your internet.")
        Return
    EndIf

    If $oHTTP.Status <> 200 Then
        GuiDelete($hCheckGUI)
        MsgBox(48, "Check Update", "Cannot connect to update server or no release found." & @CRLF & "Status Code: " & $oHTTP.Status)
        Return
    EndIf

    Local $sResponse = $oHTTP.ResponseText
    GuiDelete($hCheckGUI)

    Local $aMatch = StringRegExp($sResponse, '"tag_name":\s*"([^"]+)"', 3)

    If IsArray($aMatch) Then
        Local $sLatestVersion = $aMatch[0]
        $sLatestVersion = StringRegExpReplace($sLatestVersion, "[^0-9.]", "")
        Local $sLocalAppVersion = StringRegExpReplace($version, "[^0-9.]", "")

        If $sLatestVersion <> $sLocalAppVersion Then
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

                Local $bSuccess = InetGetInfo($hDownload, 3)
                Local $iError = InetGetInfo($hDownload, 4)
                InetClose($hDownload)

                DllCall("winmm.dll", "int", "PlaySoundW", "ptr", 0, "ptr", 0, "dword", 0)

                ProgressOff()
                GuiDelete($downloadGui)

                If Not $bSuccess Then
                    MsgBox(16, "Error", "Download failed. Error code: " & $iError)
                    FileDelete($sSavePath)
                    Return
                EndIf

                If FileExists($sSavePath) And FileGetSize($sSavePath) > 0 Then
                MsgBox(64, "Success", "Downloaded successfully!" & @CRLF & "File saved as: " & $sSavePath)
Run("unzip.bat")
                ; ShellExecute($sSavePath)
Exit
                EndIf
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

Func _Get_YTDLP_LocalVersion()
    If Not FileExists($YT_DLP_PATH) Then Return "0"
    Local $pid = Run('"' & $YT_DLP_PATH & '" --version', @ScriptDir, @SW_HIDE, $STDOUT_CHILD)
    If @error Then Return "0"
    ProcessWaitClose($pid)
    Local $sVer = StdoutRead($pid)
    Return StringRegExpReplace(StringStripWS($sVer, 3), "[^0-9.]", "")
EndFunc

Func _ShowSettings()
    $g_hSettingsGui = GUICreate("Settings", 450, 450, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU, $WS_POPUP))
    GUISetBkColor($COLOR_BLUE)
    GUISetFont(9, 400, 0, "Segoe UI")

    $g_hSettingsTab = GUICtrlCreateTab(10, 10, 430, 350)

    $g_hSettingsDummyNext = GUICtrlCreateDummy()
    $g_hSettingsDummyPrev = GUICtrlCreateDummy()
    ; Accelerators are often blocked by child controls, so we also use HotKeySet below.
    Local $aAccelSettings[2][2] = [["^{TAB}", $g_hSettingsDummyNext], ["^+{TAB}", $g_hSettingsDummyPrev]]
    GUISetAccelerators($aAccelSettings, $g_hSettingsGui)

    Local $aTabItems[3]
    ; --- Tab General ---
    $aTabItems[0] = GUICtrlCreateTabItem("General property page")
    GUICtrlCreateLabel("General Settings", 20, 50, 410, 20)
    GUICtrlSetFont(-1, 10, 800)
    GUICtrlSetColor(-1, 0xFFFFFF)

    Local $chk_AutoUpdate = GUICtrlCreateCheckbox("Automatically check for updates on startup", 30, 80, 380, 20)
    If $g_bAutoUpdate Then GUICtrlSetState(-1, $GUI_CHECKED)
    GUICtrlSetColor(-1, 0xFFFFFF)

    Local $chk_AutoStart = GUICtrlCreateCheckbox("Start program automatically after login", 30, 110, 380, 20)
    If $g_bAutoStart Then GUICtrlSetState(-1, $GUI_CHECKED)
    GUICtrlSetColor(-1, 0xFFFFFF)

    Local $chk_AutoDetect = GUICtrlCreateCheckbox("Automatically detect YouTube links in clipboard on launch", 30, 140, 380, 20)
    If $g_bAutoDetectLink Then GUICtrlSetState(-1, $GUI_CHECKED)
    GUICtrlSetColor(-1, 0xFFFFFF)

    ; --- Tab Player ---
    $aTabItems[1] = GUICtrlCreateTabItem("Player property page")
    GUICtrlCreateLabel("Player Settings", 20, 50, 410, 20)
    GUICtrlSetFont(-1, 10, 800)
    GUICtrlSetColor(-1, 0xFFFFFF)

    Local $chk_SkipSilence = GUICtrlCreateCheckbox("Skip silence (Recommended only for music)", 30, 80, 380, 20)
    If $g_bSkipSilence Then GUICtrlSetState(-1, $GUI_CHECKED)
    GUICtrlSetColor(-1, 0xFFFFFF)

    Local $chk_SpeakStatus = GUICtrlCreateCheckbox("Speak player status notifications", 30, 110, 380, 20)
    If $g_bSpeakStatus Then GUICtrlSetState(-1, $GUI_CHECKED)
    GUICtrlSetColor(-1, 0xFFFFFF)

    GUICtrlCreateLabel("After Video Finishes:", 30, 150, 150, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    Local $cbo_AfterAction = GUICtrlCreateCombo("", 180, 145, 230, 20, $CBS_DROPDOWNLIST)
    GUICtrlSetData(-1, "Close the player|Replay video|Do nothing", "Do nothing")
    ; Set current selection
    If $g_iAfterVideoAction = 0 Then
        _GUICtrlComboBox_SetCurSel($cbo_AfterAction, 0)
    ElseIf $g_iAfterVideoAction = 1 Then
        _GUICtrlComboBox_SetCurSel($cbo_AfterAction, 1)
    ElseIf $g_iAfterVideoAction = 2 Then
        _GUICtrlComboBox_SetCurSel($cbo_AfterAction, 2)
    EndIf

    GUICtrlCreateLabel("Fast Forward Interval (Seconds):", 30, 190, 200, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    Local $inp_FFStep = GUICtrlCreateInput(String($g_iFFStep), 230, 185, 50, 20, 0x2000) ; 0x2000 = $ES_NUMBER

    GUICtrlCreateLabel("Rewind Interval (Seconds):", 30, 220, 200, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    Local $inp_RWStep = GUICtrlCreateInput(String($g_iRWStep), 230, 215, 50, 20, 0x2000) ; 0x2000 = $ES_NUMBER

    ; --- Tab Data ---
    $aTabItems[2] = GUICtrlCreateTabItem("Data property page")
    GUICtrlCreateLabel("Configuration Backup & Restore", 20, 50, 410, 20)
    GUICtrlSetFont(-1, 10, 800)
    GUICtrlSetColor(-1, 0xFFFFFF)

    Local $btn_Backup = GUICtrlCreateButton("Backup Configuration...", 30, 90, 200, 35)
    Local $btn_Restore = GUICtrlCreateButton("Restore Configuration...", 30, 140, 200, 35)

    GUICtrlCreateTabItem("") ; End Tab Control

    Local $btn_Save = GUICtrlCreateButton("Ok", 120, 380, 100, 35)
    Local $btn_Cancel = GUICtrlCreateButton("Cancel", 230, 380, 100, 35)

    GUISetState(@SW_SHOW, $g_hSettingsGui)

    ; Register WM_ACTIVATE to handle hotkeys only when window is active
    GUIRegisterMsg($WM_ACTIVATE, "_Settings_WM_ACTIVATE")

    ; Initial activation
    _Settings_ToggleHotKeys(True)

    While 1
        Local $nMsg = GUIGetMsg()
        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $btn_Cancel
                _Settings_ToggleHotKeys(False)
                GUIRegisterMsg($WM_ACTIVATE, "")
                GUIDelete($g_hSettingsGui)
                Return

            Case $g_hSettingsDummyNext
                Local $iTabCount = _GUICtrlTab_GetItemCount(GUICtrlGetHandle($g_hSettingsTab))
                Local $iCurr = _GUICtrlTab_GetCurSel(GUICtrlGetHandle($g_hSettingsTab))
                Local $iNext = ($iCurr + 1 >= $iTabCount) ? 0 : $iCurr + 1
                GUICtrlSetState($aTabItems[$iNext], $GUI_SHOW)
                ControlFocus($g_hSettingsGui, "", $g_hSettingsTab)

            Case $g_hSettingsDummyPrev
                Local $iTabCount = _GUICtrlTab_GetItemCount(GUICtrlGetHandle($g_hSettingsTab))
                Local $iCurr = _GUICtrlTab_GetCurSel(GUICtrlGetHandle($g_hSettingsTab))
                Local $iPrev = ($iCurr - 1 < 0) ? $iTabCount - 1 : $iCurr - 1
                GUICtrlSetState($aTabItems[$iPrev], $GUI_SHOW)
                ControlFocus($g_hSettingsGui, "", $g_hSettingsTab)

            Case $btn_Backup
                Local $sSavePath = FileSaveDialog("Select backup location", @DesktopDir, "Zip Archive (*.zip)", 2, "VDH_Config_Backup.zip")
                If Not @error Then
                    If StringRight($sSavePath, 4) <> ".zip" Then $sSavePath &= ".zip"

                    ; Use PowerShell to zip the entire SETTINGS_DIR
                    Local $sPSCmd = 'powershell -Command "Compress-Archive -Path ''' & $SETTINGS_DIR & '\*''' & ' -DestinationPath ''' & $sSavePath & ''' -Force"'
                    GUISetCursor(15, 1, $g_hSettingsGui)
                    RunWait($sPSCmd, "", @SW_HIDE)
                    GUISetCursor(2, 0, $g_hSettingsGui)

                    If FileExists($sSavePath) Then
                        MsgBox(64, "Backup Completed", "The configuration backup has been created successfully at:" & @CRLF & $sSavePath)
                    Else
                        MsgBox(16, "Error", "Failed to create backup. Please check if you have write permissions.")
                    EndIf
                EndIf

            Case $btn_Restore
                Local $sOpenPath = FileOpenDialog("Select Backup File", @DesktopDir, "Zip Archive (*.zip)", 1)
                If Not @error Then
                    Local $iConfirm = MsgBox(36, "Confirm Restore", "Restoring data will overwrite your current configuration and restart the program. Are you sure you want to proceed?")
                    If $iConfirm = 6 Then ; Yes
                        ; Use PowerShell to unzip to SETTINGS_DIR
                        Local $sPSCmd = 'powershell -Command "Expand-Archive -Path ''' & $sOpenPath & ''' -DestinationPath ''' & $SETTINGS_DIR & ''' -Force"'
                        GUISetCursor(15, 1, $g_hSettingsGui)
                        RunWait($sPSCmd, "", @SW_HIDE)
                        GUISetCursor(2, 0, $g_hSettingsGui)

                        MsgBox(64, "Success", "Restore successful! Program will now restart.")
                        ShellExecute(@ScriptFullPath)
                        Exit
                    EndIf
                EndIf

            Case $btn_Save
                ; Read checkbox states
                $g_bAutoUpdate = (GUICtrlRead($chk_AutoUpdate) = $GUI_CHECKED)
                $g_bAutoStart = (GUICtrlRead($chk_AutoStart) = $GUI_CHECKED)
                $g_bAutoDetectLink = (GUICtrlRead($chk_AutoDetect) = $GUI_CHECKED)
                $g_bSkipSilence = (GUICtrlRead($chk_SkipSilence) = $GUI_CHECKED)
                $g_bSpeakStatus = (GUICtrlRead($chk_SpeakStatus) = $GUI_CHECKED)
                $g_iAfterVideoAction = _GUICtrlComboBox_GetCurSel($cbo_AfterAction)

                $g_iFFStep = Int(GUICtrlRead($inp_FFStep))
                $g_iRWStep = Int(GUICtrlRead($inp_RWStep))
                If $g_iFFStep < 1 Then $g_iFFStep = 1
                If $g_iRWStep < 1 Then $g_iRWStep = 1
                $g_iSeekStep = $g_iFFStep

                ; Save to INI
                IniWrite($CONFIG_FILE, "Settings", "AutoUpdate", $g_bAutoUpdate ? "1" : "0")
                IniWrite($CONFIG_FILE, "Settings", "AutoStart", $g_bAutoStart ? "1" : "0")
                IniWrite($CONFIG_FILE, "Settings", "AutoDetectLink", $g_bAutoDetectLink ? "1" : "0")
                IniWrite($CONFIG_FILE, "Settings", "SkipSilence", $g_bSkipSilence ? "1" : "0")
                IniWrite($CONFIG_FILE, "Settings", "SpeakStatus", $g_bSpeakStatus ? "1" : "0")
                IniWrite($CONFIG_FILE, "Settings", "AfterVideoAction", String($g_iAfterVideoAction))
                IniWrite($CONFIG_FILE, "Settings", "FFStep", String($g_iFFStep))
                IniWrite($CONFIG_FILE, "Settings", "RWStep", String($g_iRWStep))

                ; Handle Auto-start in Registry
                Local $sRegKey = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
                If $g_bAutoStart Then
                    ; Use @ScriptFullPath and ensure working directory by using a cmd trick or just trust FileChangeDir
                    RegWrite($sRegKey, "VDHYouTubeDownloader", "REG_SZ", '"' & @ScriptFullPath & '"')
                Else
                    RegDelete($sRegKey, "VDHYouTubeDownloader")
                EndIf

                HotKeySet("^{TAB}")
                HotKeySet("^+{TAB}")
                GUIDelete($g_hSettingsGui)
                Return
        EndSwitch
    WEnd
EndFunc

; Helper for ComboBox
Func _GUICtrlComboBox_SetCurSel($hWnd, $iIndex)
    Local $hCombo = IsHWnd($hWnd) ? $hWnd : GUICtrlGetHandle($hWnd)
    Return _SendMessage($hCombo, $CB_SETCURSEL, $iIndex, 0)
EndFunc

Func _GUICtrlComboBox_GetCurSel($hWnd)
    Local $hCombo = IsHWnd($hWnd) ? $hWnd : GUICtrlGetHandle($hWnd)
    Return _SendMessage($hCombo, $CB_GETCURSEL, 0, 0)
EndFunc

Func _ShowGoToTime()
    If Not IsObj($oWMP) Then Return
    Local $fDuration = $oWMP.currentMedia.duration
    If $fDuration <= 0 Then Return

    Local $hGoToTimeGui = GUICreate("Go to Time", 250, 150, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU), $WS_EX_TOPMOST, $hPlayGui)
    GUISetBkColor($COLOR_BLUE)

    GUICtrlCreateLabel("Minutes:", 10, 20, 80, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetFont(-1, 10, 800)
    Local $inpMin = GUICtrlCreateInput("", 100, 17, 100, 20, $ES_NUMBER)

    GUICtrlCreateLabel("Seconds:", 10, 50, 80, 20)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetFont(-1, 10, 800)
    Local $inpSec = GUICtrlCreateInput("", 100, 47, 100, 20, $ES_NUMBER)

    Local $btnOK = GUICtrlCreateButton("OK", 40, 100, 80, 30)
    GUICtrlSetState(-1, $GUI_DEFBUTTON)
    Local $btnCancel = GUICtrlCreateButton("Cancel", 140, 100, 80, 30)

    Local $hDummyEscGoTo = GUICtrlCreateDummy()
    Local $aAccelGoTo[1][2] = [["{ESC}", $hDummyEscGoTo]]
    GUISetAccelerators($aAccelGoTo, $hGoToTimeGui)

    GUISetState(@SW_SHOW, $hGoToTimeGui)
    _AllowUIPI($hGoToTimeGui)
    _AllowUIPI($inpMin)
    _AllowUIPI($inpSec)

    ; Set initial values once
    Local $iCurPos = Int($oWMP.controls.currentPosition)
    GUICtrlSetData($inpMin, Int($iCurPos / 60))
    GUICtrlSetData($inpSec, Mod($iCurPos, 60))

    ControlFocus($hGoToTimeGui, "", $inpMin)
    GUICtrlSendMsg($inpMin, 0x00B1, 0, -1) ; EM_SETSEL

    While 1
        Local $nMsg = GUIGetMsg()
        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $btnCancel, $hDummyEscGoTo
                GUIDelete($hGoToTimeGui)
                Return
            Case $btnOK
                Local $iMin = Int(GUICtrlRead($inpMin))
                Local $iSec = Int(GUICtrlRead($inpSec))
                Local $iTarget = ($iMin * 60) + $iSec
                If $iTarget > $fDuration Then $iTarget = $fDuration
                $oWMP.controls.currentPosition = $iTarget
                _ReportStatus("Jumped to " & $iMin & " minutes " & $iSec & " seconds")
                GUIDelete($hGoToTimeGui)
                Return
        EndSwitch
        Sleep(1)
    WEnd
EndFunc

Func _ShowPlayerContextMenu()
    Local $hMenu = _GUICtrlMenu_CreatePopup()
    _GUICtrlMenu_AddMenuItem($hMenu, "Go to &Time... (Ctrl+G)", 1001)

    Local $iCmd = _GUICtrlMenu_TrackPopupMenu($hMenu, $hPlayGui, MouseGetPos(0), MouseGetPos(1), 1, 1, 2)
    _GUICtrlMenu_DestroyMenu($hMenu)

    If $iCmd = 1001 Then _ShowGoToTime()
EndFunc

Func _Settings_WM_ACTIVATE($hWnd, $iMsg, $iwParam, $ilParam)
    If $hWnd = $g_hSettingsGui Then
        Local $iActive = BitAND($iwParam, 0xFFFF) ; WA_ACTIVE or WA_CLICKACTIVE
        _Settings_ToggleHotKeys($iActive <> 0)
    EndIf
    Return $GUI_RUNDEFMSG
EndFunc

Func _Settings_ToggleHotKeys($bEnable)
    If $bEnable Then
        HotKeySet("^{TAB}", "_Settings_HotKey_Next")
        HotKeySet("^+{TAB}", "_Settings_HotKey_Prev")
    Else
        HotKeySet("^{TAB}")
        HotKeySet("^+{TAB}")
    EndIf
EndFunc

Func _Settings_HotKey_Next()
    If WinActive($g_hSettingsGui) Then
        GUICtrlSendToDummy($g_hSettingsDummyNext)
    EndIf
EndFunc

Func _Settings_HotKey_Prev()
    If WinActive($g_hSettingsGui) Then
        GUICtrlSendToDummy($g_hSettingsDummyPrev)
    EndIf
EndFunc

Func _Player_HotKey_Options()
    If WinActive($hPlayGui) Then
        GUICtrlSendToDummy($hDummyAltO)
    Else
        HotKeySet("!o")
        Send("!o")
        HotKeySet("!o", "_Player_HotKey_Options")
    EndIf
EndFunc

Func _ShowPlaylistVideos($sPlaylistID, $sPlaylistTitle)
    ; 1. Hiển thị hộp thoại Loading
    Local $hLoad = GUICreate("Loading", 300, 80, -1, -1, $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
    GUISetBkColor(0xFFFFFF)
    GUICtrlCreateLabel("Loading playlist: " & $sPlaylistTitle & "...", 10, 25, 280, 40, $SS_CENTER)
    GUISetState(@SW_SHOW, $hLoad)

    ; 2. Tải danh sách video bằng yt-dlp - Đưa I: xuống cuối để đảm bảo T và D đã có trước khi Add
    Local $sParams = '--flat-playlist --print "T:%(title)s" --print "D:%(duration_string)s" --print "I:%(id)s" --no-warnings --encoding utf-8 -- "' & $sPlaylistID & '"'
    Local $sFullCmd = @ComSpec & ' /c ""' & $YT_DLP_PATH & '" ' & $sParams & '"'
    Local $iPID = Run($sFullCmd, @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)

    Local $bData = Binary("")
    Local $sErr = ""
    While ProcessExists($iPID)
        $bData &= StdoutRead($iPID, False, True)
        $sErr &= StderrRead($iPID)
        Sleep(1)
    WEnd
    $bData &= StdoutRead($iPID, False, True)
    $sErr &= StderrRead($iPID)

    Local $sOutput = BinaryToString($bData, 4)
    GUIDelete($hLoad)

    Local $aLines = StringSplit(StringStripCR($sOutput), @LF)
    If $aLines[0] <= 1 And $sOutput == "" Then
        Local $sShowErr = "Could not load videos from this playlist."
        If $sErr <> "" Then $sShowErr &= " Details: " & StringLeft(StringStripWS($sErr, 3), 100)
        MsgBox(16, "Error", $sShowErr)
        Return
    EndIf

    ; 3. Tạo GUI danh sách video
    Local $hPlGui = GUICreate("Playlist Videos: " & $sPlaylistTitle, 400, 450)
    GUISetBkColor($COLOR_BLUE)
    Local $lst_pl = GUICtrlCreateList("", 10, 10, 380, 380, BitOR($LBS_NOTIFY, $WS_VSCROLL, $WS_BORDER))
    Local $btn_back = GUICtrlCreateButton("Close Playlist", 10, 400, 380, 30)

    Local $aPlIds[1], $aPlTitles[1], $aPlTypes[1]
    Local $sCurrentT = "", $sCurrentI = "", $sCurrentD = ""
    Local $iPlCount = 0

    For $i = 1 To $aLines[0]
        Local $sLine = StringStripWS($aLines[$i], 3)
        If $sLine == "" Then ContinueLoop

        If StringLeft($sLine, 2) = "T:" Then
            $sCurrentT = StringTrimLeft($sLine, 2)
        ElseIf StringLeft($sLine, 2) = "I:" Then
            $sCurrentI = StringTrimLeft($sLine, 2)
        ElseIf StringLeft($sLine, 2) = "D:" Then
            $sCurrentD = StringTrimLeft($sLine, 2)
        EndIf

        ; Trigger khi có ID (vì ID in cuối cùng)
        If $sCurrentI <> "" Then
            $iPlCount += 1
            Local $sDisp = $iPlCount & ". " & ($sCurrentT <> "" And $sCurrentT <> "NA" ? $sCurrentT : "Unknown Title")
            If $sCurrentD <> "" And $sCurrentD <> "NA" Then $sDisp &= " [" & $sCurrentD & "]"
            _GUICtrlListBox_AddString($lst_pl, $sDisp)

            ReDim $aPlIds[$iPlCount + 1]
            ReDim $aPlTitles[$iPlCount + 1]
            ReDim $aPlTypes[$iPlCount + 1]

            $aPlIds[$iPlCount] = $sCurrentI
            $aPlTitles[$iPlCount] = $sCurrentT
            $aPlTypes[$iPlCount] = "video"

        EndIf
    Next

    If $iPlCount == 0 Then
        MsgBox(16, "Error", "No videos found in this playlist.")
        GUIDelete($hPlGui)
        Return
    EndIf

    _GUICtrlListBox_SetCurSel($lst_pl, 0)
    GUISetState(@SW_SHOW, $hPlGui)
    ControlFocus($hPlGui, "", $lst_pl)

    Local $hDummyEnterPl = GUICtrlCreateDummy()
    Local $hDummyAudioPl = GUICtrlCreateDummy()
    Local $aAccelPl[2][2] = [["{ENTER}", $hDummyEnterPl], ["^{ENTER}", $hDummyAudioPl]]
    GUISetAccelerators($aAccelPl, $hPlGui)

    While 1
        Local $nMsg = GUIGetMsg()
        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $btn_back
                GUIDelete($hPlGui)
                Return
            Case $hDummyEnterPl, $hDummyAudioPl
                Local $iIndex = _GUICtrlListBox_GetCurSel($lst_pl)
                If $iIndex <> -1 Then
                    Local $bAudio = ($nMsg = $hDummyAudioPl)

                    ; Tạm thời copy các mảng kết quả tìm kiếm để _PlayLoop hoạt động
                    Local $aSavedIds = $aSearchIds
                    Local $aSavedTitles = $aSearchTitles
                    Local $aSavedTypes = $aSearchTypes
                    Local $iSavedTotal = $iTotalLoaded

                    $aSearchIds = $aPlIds
                    $aSearchTitles = $aPlTitles
                    $aSearchTypes = $aPlTypes
                    $iTotalLoaded = $iPlCount

                    _PlayLoop($iIndex, $bAudio)

                    ; Khôi phục lại mảng tìm kiếm gốc
                    $aSearchIds = $aSavedIds
                    $aSearchTitles = $aSavedTitles
                    $aSearchTypes = $aSavedTypes
                    $iTotalLoaded = $iSavedTotal
                EndIf
        EndSwitch
    WEnd
EndFunc

Func _UnescapeJSON($sText)
    $sText = StringReplace($sText, '\"', '"')
    $sText = StringReplace($sText, '\/', '/')
    $sText = StringReplace($sText, '\u0026', '&')

    Local $aMatch = StringRegExp($sText, "\\u([0-9a-fA-F]{4})", 3)
    If IsArray($aMatch) Then
        For $i = 0 To UBound($aMatch) - 1
            Local $sUnicode = "\u" & $aMatch[$i]
            $sText = StringReplace($sText, $sUnicode, ChrW(Dec($aMatch[$i])))
        Next
    EndIf
    Return $sText
EndFunc


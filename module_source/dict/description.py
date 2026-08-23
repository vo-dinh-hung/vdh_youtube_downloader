import wx
import re
import webbrowser
import pyperclip
import sys
import os
from accessible_output3.outputs.auto import Auto
speak = Auto().speak

def _(s): return s

# Regex cải tiến để bắt URL bao gồm cả www và các giao thức khác
url = re.compile(r"(https?://|www\.)[^\s<>\"']+|[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(/[^\s<>\"']*)?")

class DescriptionDialog(wx.Dialog):
    def __init__(self, parent, content):
        wx.Dialog.__init__(self, parent, title=_("Video Description"), size=(600, 500))
        self.Centre()
        self.content = content
        panel = wx.Panel(self)
        
        font = wx.Font(10, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_NORMAL, False, "Segoe UI")
        
        lbl = wx.StaticText(panel, -1, _("Content: "))
        lbl.SetFont(font)
        
        self.contentBox = wx.TextCtrl(panel, -1, value=self.process(), style=wx.TE_PROCESS_ENTER|wx.TE_READONLY|wx.TE_MULTILINE|wx.HSCROLL)
        self.contentBox.SetFont(font)

        copyButton = wx.Button(panel, -1, _("Copy"), name="export")
        txtExport = wx.Button(panel, -1, _("Export to .txt..."), name="export")
        htmlExport = wx.Button(panel, -1, _("Export to .html..."), name="export")
        closeButton = wx.Button(panel, wx.ID_CANCEL, _("Close"))
        
        sizer = wx.BoxSizer(wx.VERTICAL)
        sizer1 = wx.BoxSizer(wx.HORIZONTAL)
        sizer2 = wx.BoxSizer(wx.HORIZONTAL)
        
        sizer1.Add(lbl, 0, wx.ALL, 5)
        sizer1.Add(self.contentBox, 1, wx.EXPAND|wx.ALL, 5)
        
        sizer2.Add(copyButton, 0, wx.ALL, 5)
        sizer2.Add(txtExport, 0, wx.ALL, 5)
        sizer2.Add(htmlExport, 0, wx.ALL, 5)
        sizer2.Add(closeButton, 0, wx.ALL, 5)
        
        sizer.Add(sizer1, 1, wx.EXPAND)
        sizer.Add(sizer2, 0, wx.ALIGN_CENTER)
        
        panel.SetSizer(sizer)
        self.contentBox.Bind(wx.EVT_KEY_DOWN, self.onKeyDown)
        copyButton.Bind(wx.EVT_BUTTON, self.onCopy)
        txtExport.Bind(wx.EVT_BUTTON, self.onTxt)
        htmlExport.Bind(wx.EVT_BUTTON, self.onHtml)
        
        closeButton.Bind(wx.EVT_BUTTON, lambda event: self.Destroy())
        self.Bind(wx.EVT_CLOSE, lambda event: self.Destroy())
        self.ShowModal()

    def process(self):
        if not self.content or self.content.strip() == "":
            return _("No description available.")
        
        # Thêm newline trước và sau mỗi link để tách biệt với chữ
        processed_content = url.sub(r"\n\g<0>\n", self.content)
        # Loại bỏ các dòng trống thừa
        return "\n".join([line.strip() for line in processed_content.splitlines() if line.strip()])

    def onKeyDown(self, event):
        if event.GetKeyCode() == wx.WXK_RETURN:
            self.onOpen(event)
        else:
            event.Skip()

    def onOpen(self, event):
        # Lấy vị trí con trỏ hiện tại
        pos = self.contentBox.GetInsertionPoint()
        # Tìm các link trong toàn bộ văn bản nhưng lọc dựa trên vị trí gần con trỏ
        all_text = self.contentBox.GetValue()
        matches = list(url.finditer(all_text))
        
        found_link = False
        for match in matches:
            start, end = match.span()
            # Kiểm tra nếu con trỏ nằm trong vùng link (cho phép sai số nhỏ 1 ký tự)
            if start <= pos <= end:
                link = match.group(0)
                actual_link = link
                if not actual_link.startswith(("http://", "https://")):
                    actual_link = "https://" + link
                speak(f"opening {actual_link}", interrupt=True)
                webbrowser.open(actual_link.strip())
                found_link = True
                break
        
        if not found_link:
            speak("No link found at cursor position", interrupt=True)


    def onTxt(self, event):
        if not self.content or not self.content.strip():
            msg = "There is no description to export"
            speak(msg, interrupt=True)
            return
        path = wx.SaveFileSelector("", ".txt", parent=self)
        if path:
            with open(path, "w", encoding="utf-8") as file:
                file.write(self.content if self.content else "")
        self.contentBox.SetFocus()

    def onHtml(self, event):
        if not self.content or not self.content.strip():
            msg = "There is no description to export"
            speak(msg, interrupt=True)
            return
        try: parent_title = self.Parent.Title
        except: parent_title = "Video Description"

        content = f"""<html>
<head><meta charset='utf-8'><title>{parent_title}</title></head>
<body>"""
        description = self.contentBox.Value.split("\n")
        for line_idx in range(len(description)):
            description[line_idx] = url.sub(lambda m: f'<a href="{m.group(0)}">{m.group(0)}</a>', description[line_idx])
        description = "<br />\n".join(description)
        content += f"""<h1>{parent_title}</h1><p>{description}</p></body></html>"""
        
        path = wx.SaveFileSelector(" ", ".html", parent=self)
        if path:
            with open(path, "w", encoding="utf-8") as file:
                file.write(content)
        self.contentBox.SetFocus()

    def onCopy(self, event):
        if not self.content or not self.content.strip():
            msg = "There is no description to export"
            speak(msg, interrupt=True)
            return
        pyperclip.copy(self.content if self.content else "")
        speak("copy to clipboard", interrupt=True)
        self.contentBox.SetFocus()

if __name__ == "__main__":
    app = wx.App(False)
    video_description = ""
    
    if len(sys.argv) > 1:
        input_arg = " ".join(sys.argv[1:])
        if os.path.exists(input_arg):
            try:
                with open(input_arg, "r", encoding="utf-8-sig") as f:
                    video_description = f.read()
                if os.path.isfile(input_arg):
                    os.remove(input_arg) 
            except Exception as e:
                video_description = f"file reading error: {str(e)}"
        else:
            video_description = input_arg
    else:
        video_description = "" 

    main_frame = wx.Frame(None, title="VDH Description Viewer")
    dlg = DescriptionDialog(main_frame, video_description)
    main_frame.Destroy()

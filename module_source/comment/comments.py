import wx
import wx.lib.mixins.listctrl as listmix
import html
import sys
import json
import os
import threading
import subprocess
import re
import pyperclip
import win32com.client
from accessible_output3.outputs.auto import Auto

# Regex to find URLs
url = re.compile(r"http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\(\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+")
# Localization helper
_ = lambda x: x

_speaker = Auto()

def speak(text, interrupt=False):
    """
    Speaks the text using accessible_output3 (NVDA, Jaws, SAPI, etc.).
    """
    try:
        _speaker.speak(text, interrupt=interrupt)
    except Exception as e:
        try:
            speaker = win32com.client.Dispatch("SAPI.SpVoice")
            flags = 1 # SVSFlagsAsync
            if interrupt:
                flags |= 2 # SVSFPurgeBeforeSpeak
            speaker.Speak(text, flags)
        except Exception:
            print(f"Speech: {text}")

def run_yt_dlp_json(url, extra_args=None):
    """
    Runs yt-dlp and returns (json_data, error_message), hiding the cmd window on Windows.
    """
    try:
        if getattr(sys, "frozen", False):
            base_dir = os.path.dirname(sys.executable)
        else:
            base_dir = os.path.dirname(os.path.abspath(__file__))
        
        ytdlp_path = os.path.join(base_dir, "yt-dlp.exe")
        if not os.path.exists(ytdlp_path):
            ytdlp_path = "yt-dlp"

        cmd = [ytdlp_path, "--dump-json", "--skip-download", "--no-playlist"]
        if extra_args:
            cmd.extend(extra_args)
        cmd.append(url)
        
        kwargs = {
            "capture_output": True,
            "text": True,
            "check": False, # We'll handle return code manually
            "encoding": "utf-8"
        }
        
        if os.name == "nt":
            kwargs["creationflags"] = 0x08000000
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startupinfo.wShowWindow = 0
            kwargs["startupinfo"] = startupinfo

        result = subprocess.run(cmd, **kwargs)
        
        if result.returncode != 0:
            error_msg = result.stderr.strip() or f"Process exited with code {result.returncode}"
            return None, error_msg

        output = result.stdout.strip()
        if not output:
            return None, "No output from yt-dlp."

        # Handle multiple JSON objects (one per line)
        lines = output.splitlines()
        for line in lines:
            try:
                data = json.loads(line)
                # Return the first one that looks like a video info (has 'id')
                if isinstance(data, dict) and "id" in data:
                    return data, None
            except json.JSONDecodeError:
                continue
        
        # If no valid JSON found in lines
        try:
            return json.loads(output), None
        except json.JSONDecodeError:
            return None, "Failed to parse yt-dlp output as JSON."

    except Exception as e:
        return None, str(e)

class CommentsDialog(wx.Dialog, listmix.ColumnSorterMixin):
    def __init__(self, parent, comments=None, url=None):
        super().__init__(parent, title="Comments", size=(800, 600))
        self.url = url
        self.all_comments = comments if comments is not None else []
        self.comments = []
        self.content = "" # Text content for export

        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)

        self.list_ctrl = wx.ListCtrl(panel, style=wx.LC_REPORT | wx.BORDER_SUNKEN)
        self.list_ctrl.InsertColumn(0, _("Comment"), width=580)
        self.list_ctrl.InsertColumn(1, _("Author"), width=180)
        vbox.Add(self.list_ctrl, 1, wx.ALL | wx.EXPAND, 5)

        # Set up ColumnSorterMixin and images
        self.il = wx.ImageList(16, 16)
        self.sm_up = self.il.Add(wx.ArtProvider.GetBitmap(wx.ART_GO_UP, wx.ART_TOOLBAR, (16, 16)))
        self.sm_dn = self.il.Add(wx.ArtProvider.GetBitmap(wx.ART_GO_DOWN, wx.ART_TOOLBAR, (16, 16)))
        self.list_ctrl.SetImageList(self.il, wx.IMAGE_LIST_SMALL)
        self.itemDataMap = {}
        listmix.ColumnSorterMixin.__init__(self, 2)

        # Main Actions
        sizer_actions = wx.BoxSizer(wx.HORIZONTAL)
        lbl_show = wx.StaticText(panel, -1, _("Show:"))
        self.choice_show = wx.Choice(panel, -1, choices=[_("latest comments"), _("full comments")])
        self.btn_refresh = wx.Button(panel, -1, _("Refresh"))
        sizer_actions.Add(lbl_show, 0, wx.ALL | wx.ALIGN_CENTER_VERTICAL, 5)
        sizer_actions.Add(self.choice_show, 0, wx.ALL | wx.ALIGN_CENTER_VERTICAL, 5)
        sizer_actions.Add(self.btn_refresh, 0, wx.ALL, 5)
        vbox.Add(sizer_actions, 0, wx.ALIGN_CENTER)
        
        self.choice_show.Bind(wx.EVT_CHOICE, self.on_choice_show)
        self.btn_refresh.Bind(wx.EVT_BUTTON, self.on_refresh)
        
        if not self.url:
            self.choice_show.Disable()
            self.btn_refresh.Disable()

        if self.all_comments:
            self.update_comments(self.all_comments)
        else:
            self.set_message(_("Initializing..."))

        # Export Section
        sizer2 = wx.BoxSizer(wx.HORIZONTAL)
        copyButton = wx.Button(panel, -1, _("Copy"), name="export")
        txtExport = wx.Button(panel, -1, _("Export to .txt..."), name="export")
        htmlExport = wx.Button(panel, -1, _("Export to .html..."), name="export")
        sizer2.Add(copyButton, 0, wx.ALL, 5)
        sizer2.Add(txtExport, 0, wx.ALL, 5)
        sizer2.Add(htmlExport, 0, wx.ALL, 5)
        vbox.Add(sizer2, 0, wx.ALIGN_CENTER)
        
        copyButton.Bind(wx.EVT_BUTTON, self.onCopy)
        txtExport.Bind(wx.EVT_BUTTON, self.onTxt)
        htmlExport.Bind(wx.EVT_BUTTON, self.onHtml)

        close_button = wx.Button(panel, label=_("Close"))
        close_button.Bind(wx.EVT_BUTTON, self.on_close)
        vbox.Add(close_button, 0, wx.ALL | wx.ALIGN_CENTER, 5)

        panel.SetSizer(vbox)
        self.Centre()

    def set_message(self, message):
        """Displays a single message line in the list control."""
        self.list_ctrl.DeleteAllItems()
        self.list_ctrl.InsertItem(0, message)
        self.list_ctrl.SetItem(0, 1, "")

    def sort_comments(self, comments):
        """Sorts comments by timestamp in descending order (newest first)."""
        return sorted(comments, key=lambda c: c.get('timestamp', 0), reverse=True)

    def update_comments(self, comments):
        """Populates the list control with comments, organizing replies under parents."""
        self.list_ctrl.DeleteAllItems()
        self.itemDataMap = {}
        self.comments = []
        self.content = ""
        
        if not comments:
            self.set_message(_("No comments found."))
            return

        # Sort comments by timestamp before building the hierarchy
        sorted_comments = self.sort_comments(comments)

        # Build hierarchy
        comment_dict = {c.get('id'): c for c in sorted_comments if c.get('id')}
        roots = []
        children = {} # parent_id -> list of child comments
        
        for c in sorted_comments:
            parent_id = c.get('parent')
            if parent_id == 'root' or parent_id is None or parent_id not in comment_dict:
                roots.append(c)
            else:
                if parent_id not in children:
                    children[parent_id] = []
                children[parent_id].append(c)
        
        self.comments = []
        def build_tree(comment, level=0):
            comment['_level'] = level
            self.comments.append(comment)
            cid = comment.get('id')
            
            # Add nested replies if present (some extractors use this)
            if 'replies' in comment and comment['replies']:
                replies = self.sort_comments(comment['replies'])
                for r in replies:
                    build_tree(r, level + 1)
            
            # Add child comments from flat list mapping (common for YouTube)
            if cid in children:
                for child in children[cid]:
                    build_tree(child, level + 1)

        for root in roots:
            if root.get('id') not in [c.get('id') for c in self.comments]: # Avoid duplicates
                build_tree(root)
        
        content_lines = []
        for index, comment in enumerate(self.comments):
            level = comment.get('_level', 0)
            indent = "    " * level
            text = html.unescape(comment.get('text', ''))
            author = html.unescape(comment.get('author', 'Unknown'))
            
            # Replace newlines with spaces for the list control display
            display_text = indent + text.replace("\r\n", " ").replace("\n", " ")
            
            item = self.list_ctrl.InsertItem(index, display_text)
            self.list_ctrl.SetItem(item, 1, author)
            self.list_ctrl.SetItemData(item, index)
            self.itemDataMap[index] = (display_text, author)
            content_lines.append(f"{indent}{author}: {text}")
        
        self.content = "\n\n".join(content_lines)
        
        if self.comments:
            self.list_ctrl.Select(0)
            self.list_ctrl.Focus(0)
        self.list_ctrl.SetFocus()

    def fetch_comments(self, sort=None):
        """Fetches comments asynchronously and updates the list."""
        if not self.url:
            return
            
        label = _("fetching comments...")
        if sort == "newest":
            label = _("fetching latest comments...")
        elif sort == "top":
            label = _("fetching all comments (top)...")
            
        self.set_message(label)
        
        extra_args = ["--write-comments", "--no-check-formats"]
        if sort == "newest":
            extra_args.extend(["--extractor-args", "youtube:comment_sort=new"])
        elif sort == "top":
            extra_args.extend(["--extractor-args", "youtube:comment_sort=top"])
            
        downloader = CommentDownloader(self, self.url)
        
        def on_fetched(comments_list, error_message):
            if not self: return
            if error_message:
                self.set_message(_("Error: ") + str(error_message))
            elif not comments_list:
                self.set_message(_("No comments found."))
            else:
                self.all_comments = comments_list
                self.update_comments(comments_list)
        
        downloader.fetch_comments_async(on_fetched, extra_args)

    def on_choice_show(self, event):
        selection = self.choice_show.GetSelection()
        if selection == 0: # latest comments
            self.fetch_comments(sort="newest")
        elif selection == 1: # full comments
            self.fetch_comments(sort="top")

    def on_refresh(self, event):
        self.fetch_comments()

    def onTxt(self, event):
        if not self.comments:
            speak(_("no data to export"), interrupt=True)
            return
        path = wx.SaveFileSelector("", ".txt", default_name="comments.txt", parent=self)
        if path:
            with open(path, "w", encoding="utf-8") as file:
                file.write(self.content)
        self.list_ctrl.SetFocus()

    def onHtml(self, event):
        if not self.comments:
            speak(_("no data to export"), interrupt=True)
            return
        try: parent_title = self.Title
        except: parent_title = "Video Comments"

        content = f"""<html>
<head><meta charset='utf-8'><title>{parent_title}</title></head>
<body>"""
        description = self.content.split("\n")
        for line_idx in range(len(description)):
            line = description[line_idx]
            match = url.search(line)
            if match is not None:
                description[line_idx] = f'<a href="{match.group()}">{match.group()}</a>'
        description_html = "<br \>\n".join(description)
        content += f"""<h1>{parent_title}</h1><p>{description_html}</p></body></html>"""
        
        path = wx.SaveFileSelector(" ", ".html", default_name="comments.html", parent=self)
        if path:
            with open(path, "w", encoding="utf-8") as file:
                file.write(content)
        self.list_ctrl.SetFocus()

    def onCopy(self, event):
        if not self.comments:
            speak(_("no data to export"), interrupt=True)
            return
        item = self.list_ctrl.GetFirstSelected()
        if item != -1:
            index = self.list_ctrl.GetItemData(item)
            try:
                comment = self.comments[index]
                text = html.unescape(comment.get('text', ''))
                author = html.unescape(comment.get('author', 'Unknown'))
                pyperclip.copy(f"{author}: {text}")
                speak(_("copy comments to clipboard"), interrupt=True)
            except IndexError:
                pass
        self.list_ctrl.SetFocus()

    def on_close(self, event):
        self.EndModal(wx.ID_OK)

    def GetListCtrl(self):
        return self.list_ctrl

    def GetSortImages(self):
        return (self.sm_dn, self.sm_up)

class CommentDownloader:
    def __init__(self, parent_window, youtube_url):
        self.parent_window = parent_window
        self.youtube_url = youtube_url

    def fetch_comments_async(self, callback, extra_args=None):
        """
        Starts a thread to fetch comments and calls the callback when done.
        """
        def worker_thread():
            comments = []
            error_message = None
            try:
                info_dict, error_message = run_yt_dlp_json(self.youtube_url, extra_args=extra_args)
                if info_dict:
                    comments = info_dict.get('comments', [])
                elif not error_message:
                    error_message = "Failed to retrieve information."
            except Exception as e:
                error_message = str(e)
                comments = []
            wx.CallAfter(callback, comments, error_message)

        threading.Thread(target=worker_thread, daemon=True).start()

def main():
    app = wx.App(False)
    
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        
        # Check if the argument is a YouTube URL
        if "youtube.com" in arg or "youtu.be" in arg:
            # Show the dialog immediately
            dlg = CommentsDialog(None, url=arg)
            dlg.fetch_comments()
            dlg.ShowModal()
            dlg.Destroy()
            
        elif os.path.exists(arg):
            try:
                with open(arg, 'r', encoding='utf-8') as f:
                    comments_text = f.read()
                
                try:
                    comments_list = json.loads(comments_text)
                except json.JSONDecodeError:
                    comments_list = [{'text': line.strip(), 'author': 'Unknown'} for line in comments_text.split('\n') if line.strip()]

                dlg = CommentsDialog(None, comments_list)
                dlg.ShowModal()
                dlg.Destroy()
            except Exception as e:
                wx.MessageBox(f"Error loading comments: {e}", "Error", wx.OK | wx.ICON_ERROR)
        else:
            wx.MessageBox(f"Input not recognized (not a valid file or URL): {arg}", "Error", wx.OK | wx.ICON_ERROR)
    else:
        wx.MessageBox("No URL or file provided.", "Usage", wx.OK | wx.ICON_INFORMATION)

if __name__ == "__main__":
    main()

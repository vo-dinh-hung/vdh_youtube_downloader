@echo off
title "Updating is in progress, please do not close this window"
powershell -command "Expand-Archive -Path 'vdh_youtube_downloader.zip' -DestinationPath '.' -Force"
del vdh_youtube_downloader.zip
start "" VDHYouTubeDownloader.exe
exit

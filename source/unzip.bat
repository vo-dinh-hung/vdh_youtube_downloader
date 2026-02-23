@echo off
title "Updating is in progress, please do not close this window"
powershell -command "Expand-Archive -Path 'vdhYoutubeDownloader-.zip' -DestinationPath '.' -Force"
del vdhYoutubeDownloader-.zip
start "" VDH_YouTube_Downloader.exe
exit

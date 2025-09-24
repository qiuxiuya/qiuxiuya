@echo off
chcp 65001 >nul
set /p URL=m3u8地址: 
set /p NAME=文件名: 
ffmpeg.exe -i "%URL%" -c copy -multiple_requests 1 "%NAME%.mp4" -user_agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 Edg/140.0.0.0"
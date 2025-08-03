@echo off
setlocal enabledelayedexpansion

set /p video_dir=请输入视频文件所在目录（例如 D:\videos）:
set /p subs_dir=请输入字幕文件所在目录（例如 D:\subs）:
set /p subs_ext=请输入字幕文件后缀（例如 ass）:
set /p out_dir=请输入输出目录（例如 D:\output）:

if not exist "%out_dir%" (
    mkdir "%out_dir%"
)

for %%F in ("%video_dir%\*") do (
    if exist "%%F" (
        set "filename=%%~nxF"
        setlocal enabledelayedexpansion
        set "base_name=!filename:~0,-4!"

        set "subtitle_file=%subs_dir%\!base_name!.%subs_ext%"

        if exist "!subtitle_file!" (
            call :NormalizePath "%%F" video
            call :NormalizeSubtitlePath "!subtitle_file!" subtitle
            call :NormalizePath "%out_dir%\!base_name!.mp4" output

            ffmpeg.exe -i "!video!" -vf subtitles="!subtitle!" -c:v h264_nvenc -crf 18 -c:a copy "!output!"
        ) else (
            echo 字幕 !subtitle_file! 不存在
        )
        endlocal
    )
)
goto :eof

:NormalizePath
setlocal enabledelayedexpansion
set "p=%~1"
set "p=!p:\=\/!"
endlocal & set "%2=%p%"
goto :eof

:NormalizeSubtitlePath
setlocal enabledelayedexpansion
set "p=%~1"
set "p=!p:\=\/!"

if "!p:~1,1!"==":" (
    set "p=!p:~0,1!\\:!p:~2!"
)

set "p=!p:[=\[!"
set "p=!p:]=\]!"
endlocal & set "%2=%p%"
goto :eof

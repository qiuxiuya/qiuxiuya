#!/bin/bash

video_dir="/disk/mkv"
subs_dir="/disk/subs"
out_dir="/disk/done"

use_fonts=false

if [ "$1" = "-f" ]; then
    use_fonts=true
fi

subtitle_exts=("ass" "srt" "vtt" "ssa")

mkdir -p "$out_dir"

for video_file in "$video_dir"/*; do
    [ -f "$video_file" ] || continue

    filename=$(basename "$video_file")
    base_name="${filename%.*}"

    subtitle_file=""

    for ext in "${subtitle_exts[@]}"; do
        if [ -f "$subs_dir/$base_name.$ext" ]; then
            subtitle_file="$subs_dir/$base_name.$ext"
            break
        fi
    done

    if [ -n "$subtitle_file" ]; then
        output_file="$out_dir/$base_name.mkv"

        font_args=()

        if $use_fonts && [[ "$subtitle_file" =~ \.(ass|ssa)$ ]]; then
            while IFS= read -r font; do
                found_font=$(fc-match "$font" -f "%{file}\n" 2>/dev/null | head -n1)

                if [ -f "$found_font" ]; then
                    font_name=$(basename "$found_font")

                    font_args+=(
                        -attach "$found_font"
                        -metadata:s:t mimetype=application/x-truetype-font
                        -metadata:s:t filename="$font_name"
                    )
                else
                    echo "缺少字体: $font"
                fi
            done < <(
                grep "^Style:" "$subtitle_file" \
                | cut -d',' -f2 \
                | sort -u
            )
        fi

        ffmpeg \
          -i "$video_file" \
          -i "$subtitle_file" \
          "${font_args[@]}" \
          -map 0:v \
          -map 0:a? \
          -map 1:0 \
          -c copy \
          -metadata:s:s:0 language=chi \
          -disposition:s:0 default \
          "$output_file"
    else
        echo "未找到字幕: $base_name"
    fi
done
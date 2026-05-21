### subs.bat windows_ffmpeg批量封装字幕

请先到[ffmpeg官网](https://ffmpeg.org/download.html)下载windows版的ffmpeg，与本cmd放在同目录

若是出现乱码，请在第二行添加上`chcp 65001 >nul`

##### 使用前请确保字幕与视频文件名相同

若有其他需求，请自行自定义ffmpeg参数

使用方法 : 运行后按照输出填入路径即可

### subs.sh linux_ffmpeg批量封装字幕

```shell
apt install ffmpeg fontconfig fonts-noto-cjk -y
```

`bash subs.sh -f` 会自动在系统字体目录中查找字体文件并烧录进mkv
`bash subs.sh` 仅添加字幕轨道

#### 添加字体

把ttf等字体文件放入`/usr/share/fonts/`后，运行`fc-cache -fv`刷新字体


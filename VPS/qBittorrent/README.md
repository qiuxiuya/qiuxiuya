## 一个qBittorrent下载后自动上传和通知的脚本

仅在qBittorrent v4.3.8  非docker版本  ，debian11的环境测试

在qBittorrent设置中，勾选Torrent 完成时运行外部程序，填入`bash 此shell的绝对路径 -n "%N" -p "%D"` 即可

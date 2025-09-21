下载 [MSYS2]([https://](https://www.msys2.org/))
安装完成后打开MSYS2 终端，运行

```
pacman -S --needed base-devel mingw-w64-ucrt-x86_64-toolchain
```

将 ``C:\msys64\ucrt64\bin``添加到您的系统环境变量中
打开CMD输入以下验证是否安装

```
gcc --version
g++ --version
gdb --version
```

即可完成


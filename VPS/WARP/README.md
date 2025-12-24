安装gnupg并导入Cloudflare软件仓库的GPG公钥

```
apt install gnupg -y  
curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
```

添加 Cloudflare 的软件仓库到系统软件源列表中

```
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
```

更新软件源

```
apt update
```

安装WARP-cil

```
apt install cloudflare-warp -y
```

创建WARP免费账户

```
warp-cli registration new
```

然后输入y回车
把WARP切换为Proxy模式，即运行一个SOCKS在本地

```
warp-cli mode proxy
```

指定端口

```
#eg:warp-cli proxy port 30000
warp-cli proxy port 端口号
```

[可选]把WARP切换为MASQUE协议

```
warp-cli tunnel protocol set MASQUE
```

连接WARP

```
warp-cli connect
```


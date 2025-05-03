## **Nginx自动证书&续签**

#### 安装Nignx&acme.sh

```shell
apt install nginx -y
```

```shell
curl  https://get.acme.sh | sh
```

编辑 `/etc/nginx/nginx.conf` 需要一个server监听80端口，server_name为你所要申请证书的域名

[基本配置](https://raw.githubusercontent.com/qiuxiuya/qiuxiuya/refs/heads/main/VPS/nginx/nginx.conf)

acme.sh在你运行get.acme.sh的目录的./acme 下

cd进去

注册Zerossl账号

```shell
bash acme.sh --register-account -m 114514@114514.com #随便一个邮箱
```

获取证书**[*.example.com不可用]**

```shell
acme.sh --issue -d a.example.com -d b.example.com --nginx
```

导出证书

```shell
bash acme.sh --install-cert -d a.example.com -d b.example.com --key-file /etc/nginx/acme/key.pem --fullchain-file/etc/nginx/acme/fullchain.pem --reloadcmd "systemctl restart nginx"
```

删除证书

```shell
acme.sh --remove -d example.com
```

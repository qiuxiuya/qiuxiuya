## **Nginx自动证书&续签**

#### 安装Certbot&Nignx

```
apt install nginx certbot python3-certbot-nginx -y
```

编辑 `/etc/nginx/nginx.conf`

[基本配置](https://raw.githubusercontent.com/qiuxiuya/qiuxiuya/refs/heads/main/VPS/nginx/nginx.conf)

运行certbot

```
certbot --nginx
```

第一次使用会要求填入邮箱（~~随便写都行~~），同意协议等.

拉完证书certbot会自动修改nginx配置文件并重启

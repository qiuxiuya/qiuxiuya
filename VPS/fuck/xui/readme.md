```
apt install screen masscan libpcap-dev python3 python3-pip -y && pip3 install requests tqdm
```

asn.py 用于获取asn的ipcird

amazon.py运行即可获取az的HK/SG/KR/JP的ipcird(如需别的地区，在[这里](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html)查找地区Code然后修改regions={""}即可)

config.py用于替换扫描到的x-ui面板的xRay config

fuckxui.sh用于masscan以及推送

总之就是把config.py，fuckxui.sh放同一目录，把要扫描的ipcird放同目录下的ipcird.txt，然后

```
bash fuckxui.sh
```

即可

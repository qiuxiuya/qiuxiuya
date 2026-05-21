apt install cloud-init -y >/dev/null 2>&1
rm -f /etc/cloud/cloud-init.disabled >/dev/null 2>&1
cloud-init clean >/dev/null 2>&1
cloud-init clean --logs >/dev/null 2>&1
cloud-init init >/dev/null 2>&1
cloud-init modules --mode=config >/dev/null 2>&1
cloud-init modules --mode=final >/dev/null 2>&1
cloud-init status
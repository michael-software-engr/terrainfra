#!/usr/bin/env bash

sed -i 's/^[ ]*#[ ]*DNS[ ]*=[ ]*$/DNS=208.67.222.222 208.67.220.220/' /etc/systemd/resolved.conf
systemctl restart systemd-resolved.service || systemctl restart systemd-resolved.service

echo "Meowdy $(date)" > index.html
nohup busybox httpd -f -p "${http_port}" &

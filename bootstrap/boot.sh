#!/usr/bin/env bash

apt-get upgrade -y
apt-get install dnsmasq nginx pxelinux syslinux-common -y
#echo 'DNSMASQ_OPTS="-p0"' >> /etc/default/dnsmasq
rm /etc/nginx/sites-enabled/default

tee -a /etc/nginx/sites-enabled/default > /dev/null <<-EOD
server {
    listen 80 default_server;
    server_name _;
    root /opt/netboot;
    location / {
        autoindex on;
    }
}
EOD

nginx -t
systemctl restart nginx

mkdir -p /opt/netboot
tftp_root=/opt/netboot
wget https://releases.ubuntu.com/focal/ubuntu-20.04.5-live-server-amd64.iso -P $tftp_root

tee -a /etc/dnsmasq.conf > /dev/null <<-EOD
no-resolv
server=147.75.207.207
server=147.75.207.208
EOD


tee -a /etc/dnsmasq.d/dhcp.conf > /dev/null <<-EOD

# DHCP
interface=bond0,lo
bind-interfaces
dhcp-range=bond0,192.168.100.100,192.168.100.200
dhcp-option=6,147.75.207.207,147.75.207.208

# PXE config
dhcp-boot=pxelinux.0
enable-tftp
tftp-root=/opt/netboot

# UEFI booting
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-match=set:efi-x86_64,option:client-arch,9
dhcp-match=set:efi-x86,option:client-arch,6
dhcp-boot=tag:efi-x86_64,bootx64.efi
dhcp-boot=tag:efi-x86,bootx64.efi
EOD

systemctl stop systemd-resolved
systemctl disable systemd-resolved

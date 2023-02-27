
## Table of Contents
- [Pre-requirement](#pre-requirements)
- [Usage](#usage)

## Pre-requirements

↥ [back to top](#table-of-contents)

- [Terraform](https://www.terraform.io/downloads.html)
- [Equinix Metal account](https://console.equinix.com/)

## Usage

↥ [back to top](#table-of-contents)

The full examples are in the `examples` folder. The basic usage would be

```bash
terraform init
terraform apply
```

destroy the infrastructure 

```
terraform destroy
```

# Overview
Sometimes there is a need to setup an iPXE server that available over network.

This terraform code would setup a server with all needed software.

- dhcp
- tftp
- https

One you have the current infrastructure you will be able to to use `customer ipxe` os OS

```bash
#!ipxe

set dhcp_server 192.168.100.1

:retry_dhcp
dhcp
ping --count 1 ${dhcp_server} || goto retry_dhcp
```

## dhcp server

```bash
apt-get install dnsmasq -y
```

stop `systemd-resolved`

```bash
systemctl stop systemd-resolved
systemctl disable systemd-resolved
```

Edit dnsmasq.conf and add/update the with the following configuration:

```bash
tee -a /etc/dnsmasq.conf > /dev/null <<-EOD
no-resolv
server=147.75.207.207
server=147.75.207.208
EOD
```

configure dhcp

```bash
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
```
- We make DHCP server available on bond0 using the options interface and bind-interfaces.
- The dhcp-range provides .100 to .200 IP range available to clients.
- dhcp-option=6,147.75.207.207,147.75.207.208 announce which DNS to use (Metal DNS)
- enable-tftp: Instruct dnsmasq to enable its builtin TFTP service
- tftp-root: TFTP root directory. This will contain our ISOs, boot file, initrd, vmlinuz, etc
- dhcp-boot: initial boot file to serve to pxe clients
- dhcp-match=set:* and dhcp-boot=tag:* options allows us to tag client matching certain architecture (codes 6, 7, 8), and then use a specific boot filename (bootx64.efi) for them

```
systemctl restart dnsmasq
```

## setup nginx

```
apt install nginx -y
```

```
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
```

# Netboot the server installer

Follow the full instruction steps to boot ex [Ubuntu](https://ubuntu.com/server/docs/install/netboot-amd64) 

This is an example how this can be done with the Ubuntu OS. This infrastructure can be used to any other OS which needs to boot from the network.
#!/bin/bash

echo #########################
echo #install require packages
echo #########################


echo #install process 1
yum groupinstall -y "Development Tools"
yum -y --tolerant install perl tar xz unzip curl bind-utils net-tools ipset libtool-ltdl rsync nfs-utils kernel-devel pciutils


echo #check docker install
docker --version > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo #remove docker-ce
  yum remove docker-ce
fi


echo #install docker lastest version
yum install -y yum-utils
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce-19.03.3 docker-ce-cli-19.03.3 containerd.io

echo #########################
echo #setup env
echo #########################


echo #disabling selinux
sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
setenforce permissive


echo #change setting sshd
sed -i '/^\s*UseDNS /d' /etc/ssh/sshd_config
echo -e "\nUseDNS no" >> /etc/ssh/sshd_config


echo #set journald limits
mkdir -p /etc/systemd/journald.conf.d/
echo -e "[Journal]\nSystemMaxUse=15G" > /etc/systemd/journald.conf.d/dcos-el7-ami.conf


echo #Removing tty requirement for sudo
sed -i'' -E 's/^(Defaults.*requiretty)/#\1/' /etc/sudoers


echo #setup docker
systemctl enable docker
/usr/sbin/groupadd -f docker
/usr/sbin/groupadd -f nogroup


echo #Customizing Docker storage driver to use Overlay
docker_service_d=/etc/systemd/system/docker.service.d
mkdir -p "$docker_service_d"
cat << 'EOF' > "${docker_service_d}/execstart.conf"
[Service]
Restart=always
StartLimitInterval=0
RestartSec=15
ExecStartPre=-/sbin/ip link del docker0
ExecStart=
ExecStart=/usr/bin/dockerd --graph=/var/lib/docker --storage-driver=overlay
EOF

systemctl daemon-reload
systemctl restart docker


#disable firewalld
sudo systemctl stop firewalld
sudo systemctl disable firewalld

#setting ntp
sudo yum install -y ntp
timedatectl set-ntp yes
systemctl start ntpd && systemctl enable ntpd


#disable dnsmasq
systemctl stop dnsmasq
systemctl disable dnsmasq.service


#locale set
localectl set-locale LANG=en_US.utf8


echo #clean up
yum clean all
rm -rf /tmp/* /var/tmp/*



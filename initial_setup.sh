#!/bin/bash

# logging setup
LOGFILE=/var/log/initial_setup.log

function logsetup {
    touch $LOGFILE
    exec > >(tee -a $LOGFILE)
    exec 2>&1
}

function log {
    echo "[$(date --rfc-3339=seconds)]: $*"
}

logsetup

# update and install apps
log app install
apt update && apt dist-upgrade -y
apt install sysstat htop tmux ufw fail2ban unattended-upgrades chrony -y

# reconfigure sshd
log reconfiguring sshd
sed -i \
    -e "s/#Port 22/Port 22022/" \
    -e "s/#AddressFamily any/AddressFamily inet/" \
    -e "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" \
    -e "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" \
    -e "s/#UseDNS no/UseDNS no/" \
    /etc/ssh/sshd_config

systemctl restart ssh

# configure fail2ban
log configuring fail2ban
cat >/etc/fail2ban/jail.local <<EOF
[sshd]

enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
EOF

systemctl start fail2ban
systemctl enable fail2ban

# lockdown shared memory
log locking down shared memory
cat >>/etc/fstab <<EOF
none /dev/shm tmpfs defaults,ro 0 0
EOF

# adding kyle user
log adding user kyle
useradd -m -g admin -s /bin/bash kyle
su - kyle -c "ssh-keygen -t rsa -f /home/kyle/.ssh/id_rsa -t rsa -b 4096 -q -P \"\""
curl https://github.com/kyletravis.keys -o /home/kyle/.ssh/authorized_keys
chown kyle:admin /home/kyle/.ssh/authorized_keys
chmod 600 /home/kyle/.ssh/authorized_keys

# lock down su
log locking down su
dpkg-statoverride --update --add root admin 4750 /bin/su

# setup umasks
#TODO change this to global
log setting umasks
echo "umask 0077" >> /root/.bash_profile
chmod 600 /root/.bash_profile
echo "umask 0077" >> /home/kyle/.bash_profile
chown kyle:admin /home/kyle/.bash_profile
chmod 600 /home/kyle/.bash_profile

# update sysctl variables
cat >/etc/sysctl.conf <<EOF
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0 
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0 
net.ipv6.conf.default.accept_redirects = 0

# Ignore Directed pings
net.ipv4.icmp_echo_ignore_all = 1
EOF

# update editor
log updating default editor to vi
update-alternatives --set editor /usr/bin/vim.basic

# update sudoers
log updating sudoers
echo "kyle ALL=(ALL) ALL" > /etc/sudoers.d/90-cloud-init-users

# remove ubuntu user
log removing ubuntu user
userdel -r ubuntu

# configure unattended upgrades
log configuring unattended upgrades
#TODO this isn't working
sed -i \
    -e 's%//      "\${distro_id}:\${distro_codename}-updates";%        "\${distro_id}:\${distro_codename}-updates";%' \
    /etc/apt/apt.conf.d/50unattended-upgrades

# set history format
log setting history format
echo 'export HISTTIMEFORMAT="%Y/%m/%d %T "' >> /etc/profile.d/set_hist.sh

# reconfigure sar
log reconfiguring sar
sed -i -e "s/false/true/g" /etc/default/sysstat
sed -i -e 's/^5-55\/10/\*/' /etc/cron.d/sysstat
systemctl enable sysstat
systemctl restart sysstat

# configure chrony
#TODO

# edit limits
log configuring ulimits
cat >/etc/security/limits.conf <<EOF
*       -       nofile  131072
*       -       nproc   131072
EOF
cat >/etc/security/limits.d/20-nproc.conf <<EOF
soft    nproc     131072
EOF

# setup ddns
#TODO

# enable firewall
log enabling firewall
ufw allow 22022/tcp
ufw enable

# restart
log restarting
init 6

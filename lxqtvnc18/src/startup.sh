#!/bin/bash

if [ -n "$VNC_PW" ]; then
    x11vnc -storepasswd $VNC_PW /.vncpasswd
    chmod 400 /.vncpasswd*
    sed -i 's/^command=x11vnc.*/& -rfbauth \/.vncpasswd/' /etc/supervisor/conf.d/supervisord.conf
    export VNC_PW=
fi

if [ -n "$VNC_RESOLUTION" ]; then
    sed -i "s/1024x768/$VNC_RESOLUTION/" /usr/local/bin/xvfb.sh
fi

USER=${USER:-root}
HOME=/root
if [ "$USER" != "root" ]; then
    echo "* enable custom user: $USER"
    useradd --create-home --shell /bin/bash --user-group --groups adm,sudo $USER
    HOME=/home/$USER
    echo "$USER:$PASSWORD" | chpasswd
    cp -r /root/{.config,Desktop,.gtkrc-2.0,.qpsrc} ${HOME}
    chown -R $USER:$USER ${HOME}
fi
sed -i -e "s|%USER%|$USER|" -e "s|%HOME%|$HOME|" /etc/supervisor/conf.d/supervisord.conf
sed -i -e "s|%VNC_PORT%|$VNC_PORT|" /etc/supervisor/conf.d/supervisord.conf

### setup chromium
set -e
VNC_RES_W=${VNC_RESOLUTION%x*}
VNC_RES_H=${VNC_RESOLUTION#*x}
echo -e "\n------------------ update chromium-browser.init ------------------"
echo -e "\n... set window size $VNC_RES_W x $VNC_RES_H as chrome window size!\n"
echo "CHROMIUM_FLAGS='--disable-gpu --user-data-dir --window-size=$VNC_RES_W,$VNC_RES_H --window-position=0,0'" > $HOME/.chromium-browser.init

### setup NEW
echo "set nu" > $HOME/.vimrc
echo "set nu" > /root/.vimrc
echo "export PATH=$HOME/mybin:\$PATH" >> $HOME/.bashrc
echo "export LC_ALL=zh_CN.UTF-8" >> $HOME/.bashrc
echo "export LANG=zh_CN.UTF-8" >> $HOME/.bashrc

#setup locale
locale-gen en_US.UTF-8
locale-gen en_GB.UTF-8
locale-gen zh_CN.UTF-8
locale-gen zh_CN
locale-gen zh_CN.GBK
locale-gen zh_CN.GB18030
echo 'LANG="zh_CN.UTF-8"' >> /etc/default/locale
echo 'LANGUAGE="zh_CN:zh"' >> /etc/default/locale
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
locale-gen --purge

#install software
echo "install chromium"
apt -qq update && apt install chromium-browser -y -qq \
&& apt autoclean -y \
&& apt autoremove -y \
&& rm -rf /var/lib/apt/lists/*

### setup SSH
if [ "${SSH_KEY}" != "**None**" ]; then
	echo "===================="
	echo "===================="
    echo "=> use key login ssh"
	echo "===================="
	echo "===================="
    mkdir -p $HOME/.ssh/
    chmod 700 $HOME/.ssh/
    chown -R $USER:$USER ${HOME}/.ssh
    echo -e "$SSH_KEY" > "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
    chown -R $USER:$USER ${HOME}/.ssh/authorized_keys
	echo "PermitRootLogin no" >> /etc/ssh/sshd_config
	echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
	echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
else
	echo "===================="
	echo "===================="
	echo "=> use password login ssh"
	echo "===================="
	echo "===================="
	echo "PermitRootLogin no" >> /etc/ssh/sshd_config
	echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
fi

mkdir -p /var/run/sshd
sed -i "s/UsePAM.*/UsePAM no/g" /etc/ssh/sshd_config
echo "fix ${USER} chown"
chown -R $USER:$USER $HOME

#remove logout,reboot etc...
rm -rf /usr/share/applications/{lxqt-lockscreen.desktop,lxqt-logout.desktop,lxqt-reboot.desktop,lxqt-shutdown.desktop,lxqt-suspend.desktop,lxqt-about.desktop,lxqt-hibernate.desktop,lxqt-leave.desktop}

# clearup
PASSWORD=
SSH_KEY=
USER=
HOME=
VNC_PORT=
VNC_RESOLUTION=

exec /bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf

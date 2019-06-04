#bundle
git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
#nfs install 
apt-get install nfs-common nfs-kernel-server
*(rw,sync,no_root_squash,no_subtree_check)
sudo /etc/init.d/rpcbind restart
sudo /etc/init.d/nfs-kernel-server restart
mount -t nfs -o nolock,vers=2 192.168.1.19:/.......
#vim install
apt-get install vim
apt-get install vim-gnome
#git install
apt-get install git
#cscope and ctags install
apt-get install cscope
apt-get install ctags
#install flash
apt-get update
apt-get install flashplugin-installer
#install arm-linux-gcc 4.3.2 32lib
apt-get install lib32bz2-1.0
apt-get install lib32ncurses5
apt-get install lib32z1
#install ssh
sudo apt-get install openssh-server

#cscope 生成
cscope -Rbkq

#greenvpn 网址
https://www.getgreenjsq.info
#dnw and oflash
cp $pwd/oflash /usr/bin && chmod +x /usr/bin/oflash
#dnw secbulk 
make -C /lib/modules/`uname -r`/build M=`pwd` modules
#install minicom
apt-get install minicom

#freetype arm-linux 交叉编译 install

./configure CC=arm-none-linux-gnueabi-gcc --host=arm-linux --enable-static
make && make DESTDIR=$PWD/tmp install

#编译出来的头文件和库文件分别放到想下列文件夹中

/usr/local/arm/4.3.2/arm-none-linux-gnueabi/libc/usr/include
/usr/local/arm/4.3.2/arm-none-linux-gnueabi/libc/armv4t/lib 
sudo cp * /usr/local/arm/4.3.2/arm-none-linux-gnueabi/libc/armv4t/lib -d -rf

#set bootargs noinitrd root=/dev/mtdblock3 init=/linuxrc console=ttySAC0
set bootargs console=ttySAC0,115200 root=/dev/nfs nfsroot=192.168.1.103:/home/hotdog/armwork/kernel/fs/fs_mini_mdev ip=192.168.1.121

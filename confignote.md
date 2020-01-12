# manjaro的配置与问题
## 更新国内源和签名
```	
sudo pacman-mirrors -g   # 排列源，可不执行```
sudo pacman-mirrors -c China -m rank # 更改源，在跳出的对话框里选择想要的源
 ```
## 窗口管理器
### i3
 安装方法：pacman    
after install i3 should to creat file named .xresource and set   
``
 安装完成后要对配置文件进行配置，当前的配置文件如果要直接用的话要注意里面开机启动的程序有没有安装完成。  
 目前在i3里面的启动程序主要有：
 - compton   
 - variety  
 - xmodmap
#### 快捷键
## 字体
source-code-pro  
安装方法：pacman安装
## 网络配置
## 键位修改
- 把Alt和win调换位置
- 把lock改成ESC
## terminal
### alacritty
可以配置终端的主题，和快捷键
#### 快捷键
## shell
### zsh
在.zshrc里面有对一些对环境变量的设置和一些命令的别名。  
### oh-my-zsh
set zsh scheme
## 中文输入法
fcitx 是 Free Chinese Input Toy for X 的缩写，国内也常称作小企鹅输入法，是一款 Linux 下的中文输入法:
```
sudo pacman -S fcitx-googlepinyin
sudo pacman -S fcitx-im # 选择全部安装
sudo pacman -S fcitx-configtool # 安装图形化配置工具
sudo pacman -S fcitx-skin-material
```	
解决中文输入法无法切换问题: 添加文件 ~/.profile：
```
export GTK_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"
```
输入法需要重启生效
#### 关于在pacman在使用过程中  无法连接到官方源数据库的问题
### 问题描述
error: failed to update core (no servers configured for repository)error: failed to update extra (no ser
		vers configured for repository)error: failed to update community (no s
			ervers configured for repository)error: failed to update multilib (no 
				servers configured for repository)
### 解决
在源服务器列表文件/etc/mirrorlist中加入服务器地址
Server =https://mirrors.kernel.org/archlinux/$repo/os/$arch




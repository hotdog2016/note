# gdb and opencd study note
copy files /usr/share/openocd/target/stm32f4x.cfg /usr/share/open/target/stlink-v2.cfg to project directory  
creat a cfg file in project directory and write it like stm32.cfg

## openocd
```
openocd -f ./yourcfgfile.cfg
```
## gdb
```
arm-none-eabi-gdb target.elf
monitor reset halt
```

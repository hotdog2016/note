# 前言
写这个学习笔记主要是用来总结一下链接器的使用，从刚开始学习linux到现在，发现只要是研究底层的东西就不可能绕开链接脚本这个东西。链接脚本比较复杂与汇编器有很密切的关系，这篇笔记主要也是结合这两个手册来写。
# 链接脚本的用处
在编译裸机程序时，如果程序比较复杂，则需要对程序在内存中的分布有一个划分，链接脚本就是用来做这个事情的。
## 链接脚的的格式
在GCC链接程序的时候一般用的是ld命令当链接要求比较复杂的时候，光靠命令的参数就会有点力不从心，并且不利于对项目在内存中分布的清晰了解。
链接脚本一般是*name.ld or .lds*。注释用/*,*/。 <br>
**一个简单链接脚本的例子：**
```
SECTIONS
{
. = 0x10000;
.text : { *(.text) }
. = 0x8000000;
.data : { *(.data) }
.bss : { *(.bss) }
}
```
*.text .data .bss* 这是段的名称 `.text : { *(.text) }`以这一句为例，第一个.text指的是输出文件的段，第二个在括号里面的.text指的是输入文件里面的.text段。
' * '号是一个通配符。
## 链接脚本的命令
### 入口点命令
`ENTRY(symbol)`这个命令制定了入口位置，一般是一个函数，这样在程序运行时会先从这个函数开始运行。
- the '-e' entry command-line option;
- the ENTRY(symbol) command in a linker script;
- the value of the symbol start, if defined;
- the address of the first byte of the `.text' section, if present;
- The address 0.
### 文件命令
- INPUT(file, file, ...)<br>
- INPUT(file file ...)<br>
    指定输入文件。ld  命令选项是-L
- GROUP(file, file, ...)<br>
- GROUP(file file ...)<br>
    输入文件组。
- OUTPUT(filename)<br>
    指定输出文件名。
- SEARCH_DIR(path)<br>
    将这个路径添加到链接器的搜寻路径中去。
- STARTUP(filename)<br>
    指定在最前的文件。
### 格式命令
- OUTPUT_FORMAT(bfdname)<br>
- OUTPUT_FORMAT(default, big, little)<br>
- TARGET(bfdname)<br>
### 其他命令
- ASSERT(exp, message) <br>
如果exp是0则报错并输出后面的message.
- EXTERN(symbol symbol ...)<br>
- FORCE_COMMON_ALLOCATION<br>
- NOCROSSREFS(section section ...)<br>
- OUTPUT_ARCH(bfdarch)<br>
指定机器的架构。参数可以看BFD库的详细信息。
可以用***objdump***这个应用程序加上-f参数来查看一个文件所指定的架构信息。
## 节命令
**节命令的格式:**
```
SECTIONS
{
sections-command
sections-command
...
}
```

### 对输出节的描述 
输出段的格式
```
section [address] [(type)] : [AT(lma)]
{
output-section-command
output-section-command
...
} [>region] [:phdr :phdr ...] [=fillexp]
```
### 输出节的名字 
输出段的名字必须符合汇编器的分段格式。比如汇编器只会把程序分成 **'.test','.bss','.data'** 那么这个链接脚本的输出段的名字就只能是这三个。
还有一种名字是 **'/DISCARD/'**。这个详情请看手册。
### 输出节地址 

### 输入节 
#### 输入节的基本样式 
输入段长成这样`*(.test)` or `*(.text .rdata)` or `*(.text) *(.rdata)`
#### 输入节通配符 
- '*' :matches any number of characters<br>
- '?' :matches any single character<br>
- '[chars]':matches a single instance of any of the chars; the '-' character may be used to specify
a range of characters, as in '[a-z]' to match any lower case letter<br>
- '\' :quotes the following character<br>
#### 输入节通用符号（COMMON） 

#### 通用节KEEP（）
### 输出节关于处理数据的命令 
**输出节数据：**<br>
BYTE()one<br>
SHORT()two<br>
LONG()four<br>
QUAD()eight<br>
### 输出节关键字
- CREATE_OBJECT_SYMBOLS<br>
创建目标文件的符号表
- CONSTRUCTORS
### 输出节丢弃命令
### 输出节属性
```
section [address] [(type)] : [AT(lma)]
{
output-section-command
output-section-command
...
} [>region] [:phdr :phdr ...] [=fillexp]
``` 
#### 输出节的类型 
- NOLOAD<br>
The section should be marked as not loadable, so that it will not be loaded into
memory when the program is run.<br>
- DSECT<br>
- COPY<br>
- INFO<br>
- OVERLAY<br>
These type names are supported for backward compatibility, and are rarely used. They
all have the same effect: the section should be marked as not allocatable, so that no
memory is allocated for the section when the program is runscript sample below, the 
'ROM' section is addressed at memory location '0' and does not
need to be loaded when the program is run. The contents of the 'ROM' section will appear in
the linker output file as usual..
#### 输出节的装载地址
AT(lma):指定装载的地址
#### 输出节对应的区域
**输出段的区域  >...**
#### 输出节的程序头部
using the objdump program with the '-p' option.
```
PHDRS
{
name type [ FILEHDR ] [ PHDRS ] [ AT ( address ) ]
[ FLAGS ( flags ) ] ;
}


ELF system.
PHDRS
{
    headers PT_PHDR PHDRS ;
    interp PT_INTERP ;
    text PT_LOAD FILEHDR PHDRS ;
    data PT_LOAD ;
    dynamic PT_DYNAMIC ;
}
SECTIONS
{
    . = SIZEOF_HEADERS;
    .interp : { *(.interp) } :text :interp
    .text : { *(.text) } :text
    .rodata : { *(.rodata) } /* defaults to :text */
    ...
    . = . + 0x1000; /* move to a new page in memory */
    .data : { *(.data) } :data
    .dynamic : { *(.dynamic) } :data :dynamic
}
```
PT_NULL (0)<br>
Indicates an unused program header.<br>
PT_LOAD (1)<br>
Indicates that this program header describes a segment to be loaded from the file.<br>
PT_DYNAMIC (2)<br>
Indicates a segment where dynamic linking information can be found.<br>
PT_INTERP (3)<br>
Indicates a segment where the name of the program interpreter may be found.<br>
PT_NOTE (4)<br>
Indicates a segment holding note information.<br>
PT_SHLIB (5)<br>
A reserved program header type, defined but not specified by the ELF ABI.<br>
PT_PHDR (6)<br>
Indicates a segment where the program headers may be found.
#### 输出节的填充名利 

FILL()
### Overlay Description


# 关于目标项目符号表的查看
You can see the symbols in an object file by using the nm program, or by using the objdump
program with the `-t' option.

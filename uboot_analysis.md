# Uboot分析
## start.S
1.set the cpu to SVC32 mode
```c
    mrs r0, cpsr
    bic r0, r0, #0x1f
    orr r0, r0, #0xd3
    msr cpsr, r0
```
2.关闭看门狗和中断
```c
看门狗
	ldr	r0, =pWTCON
	mov	r1, #0x0
	str	r1, [r0]
中断
	mov	r1, #0xffffffff
	ldr	r0, =INTMSK
	str	r1, [r0]
```
3.设置时钟
```c
	ldr r0, =0x4c000014
	//	mov r1, #0x03;			  // FCLK:HCLK:PCLK=1:2:4, HDIVN=1,PDIVN=1
	mov r1, #0x05;			  // FCLK:HCLK:PCLK=1:4:8
	str r1, [r0]
?????????
	/* 如果HDIVN非0，CPU的总线模式应该从“fast bus mode”变为“asynchronous bus mode” */
	mrc	p15, 0, r1, c1, c0, 0		/* 读出控制寄存器 */ 
	orr	r1, r1, #0xc0000000			/* 设置为“asynchronous bus mode” */
	mcr	p15, 0, r1, c1, c0, 0		/* 写入控制寄存器 */
```
4.配置MPLL
```c
	ldr r0, =0x4c000004
	ldr r1, =S3C2440_MPLL_400MHZ
	str r1, [r0]
??????????
	/* 启动ICACHE */
	mrc p15, 0, r0, c1, c0, 0	@ read control reg
	orr r0, r0, #(1<<12)
	mcr	p15, 0, r0, c1, c0, 0   @ write it back
```
5.对sdram进行初始化  (文件位置是board/samsung/smdk2440/lowlevel_init.S)
```c
	/*
	 * before relocating, we have to setup RAM timing
	 * because memory timing is board-dependend, you will
	 * find a lowlevel_init.S in your board directory.
	 */
	mov	ip, lr //??????????????????
	bl	lowlevel_init 
	mov	lr, ip
	mov	pc, lr
```
6.设置sp
```c
	ldr sp, =(CONFIG_SYS_INIT_SP_ADDR)	/* sp = 30000f80 */
	bic sp, sp, #7 /* 8-byte alignment for ABI compliance */
```
7.初始化nandflash
```c
	bl nand_init_ll
```
8.代码重定位
> r0,r1,r2 分别是C语言函数copy_code_to_sdram运行的形参
```c
	mov r0, #0
	ldr r1, _TEXT_BASE
	ldr r2, _bss_start_ofs
	bl copy_code_to_sdram
```
9.清bss段
`bl clear_bss`
10.第一阶段初始化
```c
call_board_init_f:
	ldr	r0,=0x00000000
	bl	board_init_f
```
11.第二阶段初始化
> 此时r0为0 r1为代码段地址
```c
	ldr r1, _TEXT_BASE
	ldr sp, base_sp 			/* 重新设置栈 */
	/* 调用第2阶段的代码 */
	bl board_init_r
```
## 第一阶段初始化函数 board_init_f分析(/arch/arm/lib/board.c)
**下面是整理后的board_init_f函数代码 将其中没有定义到的宏删除这个函数主要用于：**
- 对一些基本外设进行初始化
- 对gd_t这个结构体进行配置其中配置的内容主要是将内存的划分信息存到gd_t 这个结构体中去
    - gd->mon_len = _bss_end_ofs;
    - gd->fdt_blob
    - gd->tlb_addr
    - gd->bd
    - gd->irq_sp
    - gd->bd->bi_baudrate
	- gd->relocaddr = addr;
	- gd->start_addr_sp = addr_sp;
	- gd->reloc_off = addr - _TEXT_BASE;
```c
unsigned int board_init_f(ulong bootflag)
{
	bd_t *bd;
	init_fnc_t **init_fnc_ptr;
	gd_t *id;
	ulong addr, addr_sp;
	extern ulong base_sp;


	bootstage_mark_name(BOOTSTAGE_ID_START_UBOOT_F, "board_init_f");

	/* Pointer is writable since we allocated a register for it */
	gd = (gd_t *) ((CONFIG_SYS_INIT_SP_ADDR) & ~0x07);
	/* compiler optimization barrier needed for GCC >= 3.4 */
	__asm__ __volatile__("": : :"memory");

	memset((void *)gd, 0, sizeof(gd_t));

	gd->mon_len = _bss_end_ofs;


	/* Allow the early environment to override the fdt address */
	gd->fdt_blob = (void *)getenv_ulong("fdtcontroladdr", 16,
						(uintptr_t)gd->fdt_blob);

	for (init_fnc_ptr = init_sequence; *init_fnc_ptr; ++init_fnc_ptr) {
		if ((*init_fnc_ptr)() != 0) {
			hang ();
		}
	}

	debug("monitor len: %08lX\n", gd->mon_len);
	/*
	 * Ram is setup, size stored in gd !!
	 */
	debug("ramsize: %08lX\n", gd->ram_size);

	addr = CONFIG_SYS_SDRAM_BASE + gd->ram_size;



	/* reserve TLB table */
	addr -= (4096 * 4);

	/* round down to next 64 kB limit */
	addr &= ~(0x10000 - 1);

	gd->tlb_addr = addr;
	debug("TLB table at: %08lx\n", addr);

	/* round down to next 4 kB limit */
	addr &= ~(4096 - 1);
	debug("Top of RAM usable for U-Boot at: %08lx\n", addr);


	/*
	 * reserve memory for U-Boot code, data & bss
	 * round down to next 4 kB limit
	 */
	//addr -= gd->mon_len;
	//addr &= ~(4096 - 1);
	addr = CONFIG_SYS_TEXT_BASE;   /* addr = _TEXT_BASE */

	debug("Reserving %ldk for U-Boot at: %08lx\n", gd->mon_len >> 10, addr);

	/*
	 * reserve memory for malloc() arena
	 */
	addr_sp = addr - TOTAL_MALLOC_LEN;
	debug("Reserving %dk for malloc() at: %08lx\n",
			TOTAL_MALLOC_LEN >> 10, addr_sp);
	/*
	 * (permanently) allocate a Board Info struct
	 * and a permanent copy of the "global" data
	 */
	addr_sp -= sizeof (bd_t);
	bd = (bd_t *) addr_sp;
	gd->bd = bd;
	debug("Reserving %zu Bytes for Board Info at: %08lx\n",
			sizeof (bd_t), addr_sp);


	addr_sp -= sizeof (gd_t);
	id = (gd_t *) addr_sp;
	debug("Reserving %zu Bytes for Global Data at: %08lx\n",
			sizeof (gd_t), addr_sp);

	/* setup stackpointer for exeptions */
	gd->irq_sp = addr_sp;
	/* leave 3 words for abort-stack    */
	addr_sp -= 12;

	/* 8-byte alignment for ABI compliance */
	addr_sp &= ~0x07;

	debug("New Stack Pointer is: %08lx\n", addr_sp);


	gd->bd->bi_baudrate = gd->baudrate;
	/* Ram ist board specific, so move it to board code ... */
	dram_init_banksize();
	display_dram_config();	/* and display it */

	gd->relocaddr = addr;
	gd->start_addr_sp = addr_sp;
	gd->reloc_off = addr - _TEXT_BASE;
	debug("relocation Offset is: %08lx\n", gd->reloc_off);
	memcpy(id, (void *)gd, sizeof(gd_t));

	base_sp = addr_sp;

	//relocate_code(addr_sp, id, addr);
	return (unsigned int)id;

	/* NOTREACHED - relocate_code() does not return */
}
```

- ***初始化队列init_sequence[] 这个队列里面包含了一系列的外设初始化函数其中有:***
    - 定时器
    - 交互环境初始化
    - 波特率设置
    - 串口初始化
    - 终端初始化
    - RAM配置
```c
init_fnc_t *init_sequence[] = {
    timer_init,     /* initialize timer */
    env_init,       /* initialize environment */
    init_baudrate,      /* initialze baudrate settings */
    serial_init,        /* serial communications setup */
    console_init_f,     /* stage 1 init of console */
    display_banner,     /* say that we are here */
    dram_init,      /* configure available RAM banks */
    NULL,
}
```
## 第二阶段初始化函数 board_init_r(/arch/arm/lib/board.c)
对板子进行第二阶段初始化，在第一阶段时已经吧内存环境分配好，这时已经可以有一个清晰稳定的c语言运行环境这是主要进行下面的一些工作：
- flash初始化
- 板子运行环境初始化
- ip地址设置
- IO设备初始化
- 控制台第二阶段初始化
- 中断初始化并使能中断
```c
void board_init_r(gd_t *id, ulong dest_addr)
{
	ulong malloc_start;
	ulong flash_size;

	gd = id;

	gd->flags |= GD_FLG_RELOC;	/* tell others: relocation done */
	bootstage_mark_name(BOOTSTAGE_ID_START_UBOOT_R, "board_init_r");

	monitor_flash_len = _end_ofs;

	/* Enable caches */
	enable_caches();

	debug("monitor flash len: %08lX\n", monitor_flash_len);
	board_init();	/* Setup chipselects */
	/*
	 * TODO: printing of the clock inforamtion of the board is now
	 * implemented as part of bdinfo command. Currently only support for
	 * davinci SOC's is added. Remove this check once all the board
	 * implement this.
	 */

	debug("Now running in RAM - U-Boot at: %08lx\n", dest_addr);


	/* The Malloc area is immediately below the monitor copy in DRAM */
	malloc_start = dest_addr - TOTAL_MALLOC_LEN;
	mem_malloc_init (malloc_start, TOTAL_MALLOC_LEN);

	puts("Flash: ");

	flash_size = flash_init();
	if (flash_size > 0) {
		print_size(flash_size, "\n");
	} else {
		puts("0 KB\n\r");
		//puts(failed);
		//hang();
	}

	puts("NAND:  ");
	nand_init();		/* go init the NAND */




	/* initialize environment */
	env_relocate();


	/* IP Address */
	gd->bd->bi_ip_addr = getenv_IPaddr("ipaddr");

	stdio_init();	/* get the devices list going. */

	jumptable_init();


	console_init_r();	/* fully init console as a device */


	 /* set up exceptions */
	interrupt_init();
	/* enable exceptions */
	enable_interrupts();


	/* Initialize from environment */
	load_addr = getenv_ulong("loadaddr", 16, load_addr);


	run_command("mtdparts default", 0);
	//mtdparts_init();	

	/* main_loop() can return to retry autoboot, if so just run it again. */
	for (;;) {
		main_loop();
	}

	/* NOTREACHED - no way out of command loop except booting */
}
```
## main_loop 函数分析
```c

void main_loop (void)
{
	char *s;
	int bootdelay;

	u_boot_hush_start ();

	s = getenv ("bootdelay");
	bootdelay = s ? (int)simple_strtol(s, NULL, 10) : CONFIG_BOOTDELAY;

	debug ("### main_loop entered: bootdelay=%d\n\n", bootdelay);

	init_cmd_timeout ();

	s = getenv ("bootcmd");

	debug ("### main_loop: bootcmd=\"%s\"\n", s ? s : "<UNDEFINED>");

	if (bootdelay >= 0 && s && !abortboot (bootdelay)) {
		run_command(s, 0);
	}

	/*
	 * Main Loop for Monitor Command Processing
	 */
	parse_file_outer();
	/* This point is never reached */
	for (;;);
}
```
##uboot 运行命令过程分析

**下面要分析的函数里面包含了大量的宏定义代码，这是为了程序一直更方便所做的准备，经过整理之后下面都是通过宏定义过滤之后的代码，这样看起来会更简洁方便一些。**

###先调用run_command函数
```c
int run_command(const char *cmd, int flag)
{
	return parse_string_outer(cmd,
			FLAG_PARSE_SEMICOLON | FLAG_EXIT_FROM_LOOP);
}
```
下面是对于flag参数的定义
```c
#define FLAG_EXIT_FROM_LOOP 1
#define FLAG_PARSE_SEMICOLON (1 << 1)	  /* symbol ';' is special for parser */
#define FLAG_REPARSING       (1 << 2)	  /* >=2nd pass */
```



###调用parse_string_outer(const char *s, int flag)
**在这里有一个对p的判定，若是在p这个字符串内没有'\n'并且为空指针时，就将s字符串拷贝到p里面，然后在最后加上'\n'.**
**现在先看一下in_str这个结构体:**
```c
struct in_str {
	const char *p;
	int __promptme;
	int promptmode;
	int (*get) (struct in_str *);
	int (*peek) (struct in_str *);
};
```
关于这个结构体的初始化  在后面的setup_string_in_str()这个函数里面
```c
static void setup_string_in_str(struct in_str *i, const char *s)
{
	i->peek = static_peek;
	i->get = static_get;
	i->__promptme=1;
	i->promptmode=1;
	i->p = s;
}
```
这些赋值的作用和意义？？？？？？？？？？？？？
```c
int parse_string_outer(const char *s, int flag)
{
	struct in_str input;
	char *p = NULL;
	int rcode;
	if ( !s || !*s)
		return 1;
	if (!(p = strchr(s, '\n')) || *++p) {
		p = xmalloc(strlen(s) + 2);
		strcpy(p, s);
		strcat(p, "\n");
		setup_string_in_str(&input, p);
		rcode = parse_stream_outer(&input, flag);
		free(p);
		return rcode;
	} else {
	setup_string_in_str(&input, s);
	return parse_stream_outer(&input, flag);
	}
}
```
### 函数parse_stream_outer分析
```c

int parse_stream_outer(struct in_str *inp, int flag)
{

	struct p_context ctx;
	o_string temp=NULL_O_STRING;
	int rcode;
	int code = 0;
	do {
		ctx.type = flag;
		initialize_context(&ctx);
		update_ifs_map();
		if (!(flag & FLAG_PARSE_SEMICOLON) || (flag & FLAG_REPARSING)) 
            mapset((uchar *)";$&|", 0);
		inp->promptmode=1;
		rcode = parse_stream(&temp, &ctx, inp, '\n');
		if (rcode == 1) flag_repeat = 0;
		if (rcode != 1 && ctx.old_flag != 0) {
			syntax();
			flag_repeat = 0;
		}
		if (rcode != 1 && ctx.old_flag == 0) {
			done_word(&temp, &ctx);
			done_pipe(&ctx,PIPE_SEQ);
			code = run_list(ctx.list_head);
			if (code == -2) {	/* exit */
				b_free(&temp);
				code = 0;
				/* XXX hackish way to not allow exit from main loop */
				if (inp->peek == file_peek) {
					printf("exit not allowed from main input shell.\n");
					continue;
				}
				break;
			}
			if (code == -1)
			    flag_repeat = 0;
		} else {
			if (ctx.old_flag != 0) {
				free(ctx.stack);
				b_reset(&temp);
			}
			if (inp->__promptme == 0) printf("<INTERRUPT>\n");
			inp->__promptme = 1;
			temp.nonnull = 0;
			temp.quote = 0;
			inp->p = NULL;
			free_pipe_list(ctx.list_head,0);
		}
		b_free(&temp);
	} while (rcode != -1 && !(flag & FLAG_EXIT_FROM_LOOP));   /* loop on syntax errors, return on EOF */
	return (code != 0) ? 1 : 0;
}
```
先分析p_contest结构体这个结构体里面是为了保存命令的上下文信息,这些信息对于后面命令的运行很重要。
这里面有struct child_prog , struct pipe

```c
struct p_context {
	struct child_prog *child;
	struct pipe *list_head;
	struct pipe *pipe;
	reserved_style w;
	int old_flag;				/* for figuring out valid reserved words */
	struct p_context *stack;
	int type;			/* define type of parser : ";$" common or special symbol */
	/* How about quoting status? */
};


typedef enum {
	PIPE_SEQ = 1,
	PIPE_AND = 2,
	PIPE_OR  = 3,
	PIPE_BG  = 4,
} pipe_style;

struct pipe {
	int num_progs;				/* total number of programs in job */
	struct child_prog *progs;	/* array of commands in pipe */
	struct pipe *next;			/* to track background commands */
	pipe_style followup;		/* PIPE_BG, PIPE_SEQ, PIPE_OR, PIPE_AND */
	reserved_style r_mode;		/* supports if, for, while, until */
};



struct child_prog {
	char **argv;				/* program name and arguments */
	int    argc;                            /* number of program arguments */
	struct pipe *group;			/* if non-NULL, first in group or subshell */
	int sp;				/* number of SPECIAL_VAR_SYMBOL */
	int type;
};
```
这些结构体是对命令的详细信息的抽象，还有uboot里面执行命令的方式，是将命令放到一个pipe中执行。

结构体o_string主要是用来描述一个字符串
```c
typedef struct {
	char *data;
	int length;
	int maxlen;
	int quote;
	int nonnull;
} o_string;
```
- 首先对结构体ctx进行初始化initialize_context(&ctx),先对当前这个命令的上下文进行初始化然后将当前这个命令通过函数done_command加到命令pipe中去，uboot会运行pipe中的命令

    ```c
    static void initialize_context(struct p_context *ctx)
    {
        ctx->pipe=NULL;
        ctx->child=NULL;
        ctx->list_head=new_pipe();
        ctx->pipe=ctx->list_head;
        ctx->w=RES_NONE;
        ctx->stack=NULL;
        ctx->old_flag=0;
        done_command(ctx);   /* creates the memory for working child */
    }
    ```
- 更新ifs映射update_ifs_map() 这个函数对于一些特殊符号进行映射，后面需要对这些特殊符号做判断，用这个映射可是更加方便和简洁。？？？？？？？？
```c
void update_ifs_map(void)
{
	/* char *ifs and char map[256] are both globals. */
	ifs = (uchar *)getenv("IFS");
	if (ifs == NULL) ifs=(uchar *)" \t\n";
	/* Precompute a list of 'flow through' behavior so it can be treated
	 * quickly up front.  Computation is necessary because of IFS.
	 * Special case handling of IFS == " \t\n" is not implemented.
	 * The map[] array only really needs two bits each, and on most machines
	 * that would be faster because of the reduced L1 cache footprint.
	 */
	memset(map,0,sizeof(map)); /* most characters flow through always */
	mapset((uchar *)"\\$'\"", 3);       /* never flow through */
	mapset((uchar *)";&|#", 1);         /* flow through if quoted */
	mapset(ifs, 2);            /* also flow through if quoted */
}
```
- done_word()这个函数对命令字符串进行解析，确定命令的参数个数*argc*和参数内容*argv[]*,这两个变量里面的内容就是后面要执行的具体的命令，这里面有个很重要的结构体.
- done_pipe 将当前命令的pipe信息添加到pipe链表中并新建一个pipe等待下一个命令。

```c
static int done_pipe(struct p_context *ctx, pipe_style type)
{
	struct pipe *new_p;
	done_command(ctx);  /* implicit closure of previous command */
	debug_printf("done_pipe, type %d\n", type);
	ctx->pipe->followup = type;
	ctx->pipe->r_mode = ctx->w;
	new_p=new_pipe();
	ctx->pipe->next = new_p;
	ctx->pipe = new_p;
	ctx->child = NULL;
	done_command(ctx);  /* set up new pipe to accept commands */
	return 0;
}
```
- run_list(ctx.list_head)到这一步，上面对于此命令的信息都已经设置好了，开始准备运行环境.
### run_list_real(struct pipe *pi)分析。
```c
static int run_list_real(struct pipe *pi)
{
	char *save_name = NULL;
	char **list = NULL;
	char **save_list = NULL;
	struct pipe *rpipe;
	int flag_rep = 0;
	int rcode=0, flag_skip=1;
	int flag_restore = 0;
	int if_code=0, next_if_code=0;  /* need double-buffer to handle elif */
	reserved_style rmode, skip_more_in_this_rmode=RES_XXXX;
	/* check syntax for "for" */
	for (rpipe = pi; rpipe; rpipe = rpipe->next) {
		if ((rpipe->r_mode == RES_IN ||
		    rpipe->r_mode == RES_FOR) &&
		    (rpipe->next == NULL)) {
				syntax();
				return 1;
		}
		if ((rpipe->r_mode == RES_IN &&
			(rpipe->next->r_mode == RES_IN &&
			rpipe->next->progs->argv != NULL))||
			(rpipe->r_mode == RES_FOR &&
			rpipe->next->r_mode != RES_IN)) {
				syntax();
				flag_repeat = 0;
				return 1;
		}
	}
	for (; pi; pi = (flag_restore != 0) ? rpipe : pi->next) {
		if (pi->r_mode == RES_WHILE || pi->r_mode == RES_UNTIL ||
			pi->r_mode == RES_FOR) {
				/* check Ctrl-C */
				ctrlc();
				if ((had_ctrlc())) {
					return 1;
				}
				flag_restore = 0;
				if (!rpipe) {
					flag_rep = 0;
					rpipe = pi;
				}
		}
		rmode = pi->r_mode;
		debug_printf("rmode=%d  if_code=%d  next_if_code=%d skip_more=%d\n", rmode, if_code, next_if_code, skip_more_in_this_rmode);
		if (rmode == skip_more_in_this_rmode && flag_skip) {
			if (pi->followup == PIPE_SEQ) flag_skip=0;
			continue;
		}
		flag_skip = 1;
		skip_more_in_this_rmode = RES_XXXX;
		if (rmode == RES_THEN || rmode == RES_ELSE) if_code = next_if_code;
		if (rmode == RES_THEN &&  if_code) continue;
		if (rmode == RES_ELSE && !if_code) continue;
		if (rmode == RES_ELIF && !if_code) break;
		if (rmode == RES_FOR && pi->num_progs) {
			if (!list) {
				/* if no variable values after "in" we skip "for" */
				if (!pi->next->progs->argv) continue;
				/* create list of variable values */
				list = make_list_in(pi->next->progs->argv,
					pi->progs->argv[0]);
				save_list = list;
				save_name = pi->progs->argv[0];
				pi->progs->argv[0] = NULL;
				flag_rep = 1;
			}
			if (!(*list)) {
				free(pi->progs->argv[0]);
				free(save_list);
				list = NULL;
				flag_rep = 0;
				pi->progs->argv[0] = save_name;
				continue;
			} else {
				/* insert new value from list for variable */
				if (pi->progs->argv[0])
					free(pi->progs->argv[0]);
				pi->progs->argv[0] = *list++;
			}
		}
		if (rmode == RES_IN) continue;
		if (rmode == RES_DO) {
			if (!flag_rep) continue;
		}
		if ((rmode == RES_DONE)) {
			if (flag_rep) {
				flag_restore = 1;
			} else {
				rpipe = NULL;
			}
		}
		if (pi->num_progs == 0) continue;
		rcode = run_pipe_real(pi);
		debug_printf("run_pipe_real returned %d\n",rcode);
		if (rcode < -1) {
			last_return_code = -rcode - 2;
			return -2;	/* exit */
		}
		last_return_code=(rcode == 0) ? 0 : 1;
		if ( rmode == RES_IF || rmode == RES_ELIF )
			next_if_code=rcode;  /* can be overwritten a number of times */
		if (rmode == RES_WHILE)
			flag_rep = !last_return_code;
		if (rmode == RES_UNTIL)
			flag_rep = last_return_code;
		if ( (rcode==EXIT_SUCCESS && pi->followup==PIPE_OR) ||
		     (rcode!=EXIT_SUCCESS && pi->followup==PIPE_AND) )
			skip_more_in_this_rmode=rmode;
	}
	return rcode;
}
```

```c

typedef enum {
	RES_NONE  = 0,
	RES_IF    = 1,
	RES_THEN  = 2,
	RES_ELIF  = 3,
	RES_ELSE  = 4,
	RES_FI    = 5,
	RES_FOR   = 6,
	RES_WHILE = 7,
	RES_UNTIL = 8,
	RES_DO    = 9,
	RES_DONE  = 10,
	RES_XXXX  = 11,
	RES_IN    = 12,
	RES_SNTX  = 13
} reserved_style;
```

### run_pipe_real分析
```c

static int run_pipe_real(struct pipe *pi)
{
	int i;
	int nextin;
	int flag = do_repeat ? CMD_FLAG_REPEAT : 0;
	struct child_prog *child;
	char *p;
	nextin = 0;

	/* Check if this is a simple builtin (not part of a pipe).
	 * Builtins within pipes have to fork anyway, and are handled in
	 * pseudo_exec.  "echo foo | read bar" doesn't work on bash, either.
	 */
	if (pi->num_progs == 1) child = & (pi->progs[0]);
		if (pi->num_progs == 1 && child->group) {
		int rcode;
		debug_printf("non-subshell grouping\n");
		rcode = run_list_real(child->group);
		return rcode;
	} else if (pi->num_progs == 1 && pi->progs[0].argv != NULL) {
		for (i=0; is_assignment(child->argv[i]); i++) { /* nothing */ }
		if (i!=0 && child->argv[i]==NULL) {
			/* assignments, but no command: set the local environment */
			for (i=0; child->argv[i]!=NULL; i++) {

				/* Ok, this case is tricky.  We have to decide if this is a
				 * local variable, or an already exported variable.  If it is
				 * already exported, we have to export the new value.  If it is
				 * not exported, we need only set this as a local variable.
				 * This junk is all to decide whether or not to export this
				 * variable. */
				int export_me=0;
				char *name, *value;
				name = xstrdup(child->argv[i]);
				debug_printf("Local environment set: %s\n", name);
				value = strchr(name, '=');
				if (value)
					*value=0;
				free(name);
				p = insert_var_value(child->argv[i]);
				set_local_var(p, export_me);
				if (p != child->argv[i]) free(p);
			}
			return EXIT_SUCCESS;   /* don't worry about errors in set_local_var() yet */
		}
		for (i = 0; is_assignment(child->argv[i]); i++) {
			p = insert_var_value(child->argv[i]);
			set_local_var(p, 0);
			if (p != child->argv[i]) {
				child->sp--;
				free(p);
			}
		}
		if (child->sp) {
			char * str = NULL;

			str = make_string((child->argv + i));
			parse_string_outer(str, FLAG_EXIT_FROM_LOOP | FLAG_REPARSING);
			free(str);
			return last_return_code;
		}
		/* check ";", because ,example , argv consist from
		 * "help;flinfo" must not execute
		 */
		if (strchr(child->argv[i], ';')) {
			printf("Unknown command '%s' - try 'help' or use "
					"'run' command\n", child->argv[i]);
			return -1;
		}
		/* Process the command */
		return cmd_process(flag, child->argc, child->argv,
				   &flag_repeat);
	}
	return -1;
}
```

### cmd_process分析

```c
enum command_ret_t {
	CMD_RET_SUCCESS,	/* 0 = Success */
	CMD_RET_FAILURE,	/* 1 = Failure */
	CMD_RET_USAGE = -1,	/* Failure, please report 'usage' error */
};

struct cmd_tbl_s {
	char		*name;		/* Command Name			*/
	int		maxargs;	/* maximum number of arguments	*/
	int		repeatable;	/* autorepeat allowed?		*/
					/* Implementation function	*/
	int		(*cmd)(struct cmd_tbl_s *, int, int, char * const []);
	char		*usage;		/* Usage message	(short)	*/
#ifdef	CONFIG_SYS_LONGHELP
	char		*help;		/* Help  message	(long)	*/
#endif
#ifdef CONFIG_AUTO_COMPLETE
	/* do auto completion on the arguments */
	int		(*complete)(int argc, char * const argv[], char last_char, int maxv, char *cmdv[]);
#endif
};

```
```c
enum command_ret_t cmd_process(int flag, int argc, char * const argv[],
			       int *repeatable)
{
	enum command_ret_t rc = CMD_RET_SUCCESS;
	cmd_tbl_t *cmdtp;

	/* Look up command in command table */
	cmdtp = find_cmd(argv[0]);
	if (cmdtp == NULL) {
		printf("Unknown command '%s' - try 'help'\n", argv[0]);
		return 1;
	}

	/* found - check max args */
	if (argc > cmdtp->maxargs)
		rc = CMD_RET_USAGE;


	/* If OK so far, then do the command */
	if (!rc) {
		rc = cmd_call(cmdtp, flag, argc, argv);
		*repeatable &= cmdtp->repeatable;
	}
	if (rc == CMD_RET_USAGE)
		rc = cmd_usage(cmdtp);
	return rc;
}




cmd_tbl_t *find_cmd (const char *cmd)
{
	int len = &__u_boot_cmd_end - &__u_boot_cmd_start;
	return find_cmd_tbl(cmd, &__u_boot_cmd_start, len);
}


cmd_tbl_t *find_cmd_tbl (const char *cmd, cmd_tbl_t *table, int table_len)
{
	cmd_tbl_t *cmdtp;
	cmd_tbl_t *cmdtp_temp = table;	/*Init value */
	const char *p;
	int len;
	int n_found = 0;

	if (!cmd)
		return NULL;
	/*
	 * Some commands allow length modifiers (like "cp.b");
	 * compare command name only until first dot.
	 */
	len = ((p = strchr(cmd, '.')) == NULL) ? strlen (cmd) : (p - cmd);

	for (cmdtp = table;
	     cmdtp != table + table_len;
	     cmdtp++) {
		if (strncmp (cmd, cmdtp->name, len) == 0) {
			if (len == strlen (cmdtp->name))
				return cmdtp;	/* full match */

			cmdtp_temp = cmdtp;	/* abbreviated command ? */
			n_found++;
		}
	}
	if (n_found == 1) {			/* exactly one match */
		return cmdtp_temp;
	}

	return NULL;	/* not found or ambiguous command */
}
```

### 对于uboot中的命令储存和解析方式。

```c
rc = cmd_call(cmdtp, flag, argc, argv);

```
在上面从cmd_table里面找到命令之后，用cmd_call来调用这个命令。
`result = (cmdtp->cmd)(cmdtp, flag, argc, argv);`
这一句话，是对命令中具体的动作函数进行调用，下面来分析一下在uboot中命令的储存形式，和命令的组成部分。


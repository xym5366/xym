;第一弹，保护模式的进出，已经在虚拟机中调试成功，还需要再研究一下，先发出来，
;大家一起研究一下。
;功能:演示实方式和保护方式切换
;16位偏移的段间直接转移指令的宏定义
JUMP MACRO SELECTOR,OFFSETV
db 0eah ;操作码
dw OFFSETV ;16位偏移
dw SELECTOR ;段值或者选择子
ENDM
;字符显示宏指令的定义
ECHOCH MACRO ASCII
mov ah,2 ;调用21号中断的2号例程
mov dl,ASCII ;要显示的字符地址存入dl寄存器
int 21h
ENDM
;存储段描述符结构的定义
DESCRIPTOR STRUC
LIMITL dw 0 ;段界限(0~15)
BASEL dw 0 ;段基地址(0~15)
BASEM db 0 ;段基地址(16~23)
ATTRIBUTES dw 0 ;段属性
BASEH db 0 ;段基地址(24~31)
DESCRIPTOR ENDS
;伪描述符结构定义
PDESC STRUC
LIMIT DW 0 ;GDT16位界限
BASE DD 0 ;GDT基地址
PDESC ENDS
;常量定义
ATDW=92H ;存在的可读写数据段属性值
ATCE=98H ;存在的只执行代码段属性值
.386P
;--------------------------------------------------------
;数据段
DSEG SEGMENT USE16 ;16位段
GDT LABEL BYTE ;全局描述符表GDT 1
DUMMY DESCRIPTOR<> ;空描述符
CODE DESCRIPTOR<0FFFFH,,,ATCE,> ;代码段描述符 2
CODE_SEL =CODE-GDT ;代码段描述的选择子
DATAS DESCRIPTOR<0FFFFH,0H,11H,ATDW,0> ;源数据段描述符 3
DATAS_SEL =DATAS-GDT ;源数据段描述符的选择子
DATAD DESCRIPTOR<0FFFFH,,,ATDW,> ;目标数据段描述符 4
DATAD_SEL =DATAD-GDT ;目标数据段描述符的选择子
GDTLEN =$-GDT ;GDT表长度
VGDTR PDESC<GDTLEN-1,> ;初始化GDTR寄存器(GDT表的描述符)的伪描述符
BUFFERLEN =256 ;缓冲区字节长度
BUFFER DB BUFFERLEN DUP (0);缓冲区
DSEG ENDS
;---------------------------------------------------------
;代码段
CSEG SEGMENT USE16 ;16位段
ASSUME CS:CSEG, DS:DSEG
START:
MOV AX,DSEG
MOV DS,AX
;准备要加载到GDTR的伪描述符
MOV BX,16
MUL BX ;无符号乘法,16*AX->AX (计算并设置GDT基地址)
ADD AX,OFFSET GDT ;界限已在定义时设置妥当
ADC DX,0 ;带进位加法,DX+0+进位CF->DX
MOV WORD PTR VGDTR.BASE, AX
MOV WORD PTR VGDTR.BASE+2, DX
;设置代码段描述符
MOV AX,CS ;把CS段值存到AX中,得到这个程序的代码段地址
MUL BX ;无符号乘法,AX乘BX->DX和AX
MOV CODE.BASEL,AX ;代码段开始偏移为0
MOV CODE.BASEM,DL ;代码段界限已在定义时设置妥当
MOV CODE.BASEH,DH ;
;设置目标数据段描述符
MOV AX,DS ;把DS段值存到AX中,得到这个程序的数据段地址
MUL BX ;计算并设置目标数据段基地址
ADD AX,OFFSET BUFFER ;DS数据段地址再加上堆栈偏移量,得到目标数据段基址
ADC DX,0 ;带进位加法
MOV DATAD.BASEL,AX
MOV DATAD.BASEM,DL
MOV DATAD.BASEH,DH
;加载GDTR
;LGDT QWORD PTR VGDTR
LGDT VGDTR
;
CLI ;关中断
CALL EA20 ;打开地址线A20 (是否可以放在设置CR0的后面)
;切换到保护方式
MOV EAX,CR0
OR EAX,1
MOV CR0,EAX
;清指令预取队列,并真正进入保护方式
JUMP <CODE_SEL>,<OFFSET VIRTUAL> ;这是一个宏,CODE_SEL是段选择子
VIRTUAL: ;现在开始在保护方式下
MOV AX,DATAS_SEL ;源数据段选择子
MOV DS,AX
MOV AX,DATAD_SEL ;目标数据段选择子
MOV ES,AX
CLD ;设置数据串操作方向
XOR SI,SI
XOR DI,DI
MOV CX,BUFFERLEN/4 ;缓冲区长度,以4字节为单位
REPZ MOVSD ;传送
;回实模式
MOV EAX,CR0
AND EAX,0FFFFFFFEH
MOV CR0,EAX
;清指令预取队列,进入实方式
JUMP <SEG REAL>,<OFFSET REAL> ;SEG REAL是段值,这里没用段选择子
;我奇怪,这里为什么还要用跳,直接执行下面的不就行了,运行时,这里需要做个实验
;可能是为了给CS赋新段值,好象要是不这样,再取指令,CS不是段值,而是选择子,
;JUMP还能执行,只是因为执行完MOV CR0,EAX已经被预取了,下面再取就是错的了段值了
REAL: ;现在又回到实方式
CALL DA20 ;关闭地址线A20
STI ;开中断
MOV AX,DSEG ;重置数据段寄存器
MOV DS,AX
MOV SI,OFFSET BUFFER
CLD ;显示缓冲区内容
MOV BP,BUFFERLEN/16
NEXTLINE:
MOV CX,16
NEXTCH:
LODSB
PUSH AX
SHR AL,4
CALL TOASCII
ECHOCH AL
POP AX
CALL TOASCII
ECHOCH AL
ECHOCH ' '
LOOP NEXTCH
ECHOCH 0DH
ECHOCH 0AH
DEC BP
JNZ NEXTLINE
;
MOV AX,4C00H ;结束
INT 21H
;把AL低4位的十六进制数转换成对应的ASCII,保存在AL
TOASCII PROC
;AL低4位是0到F的数,ASCII是16位数,存入AL
RET
TOASCII ENDP
;打开地址线A20
EA20 PROC
PUSH AX
IN AL,92H
OR AL,2
OUT 92H,AL
POP AX
RET
EA20 ENDP
;关闭地址线A20
DA20 PROC
PUSH AX
IN AL,92H
AND AL,0FDH ;0FDH=NOT 20H 这里是0FDH=NOT 02H吧
OUT 92H,AL
POP AX
RET
DA20 ENDP CSEG ENDS
END START

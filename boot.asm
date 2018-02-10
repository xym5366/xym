org 07c00h
mov ax,cs
mov ds,ax
mov es,ax
call DispStr
jmp $
DispStr:
mov ah,6 ;clr screen
mov al,0
mov cx,0
mov dx,011ffh
mov bh,0
int 10h
mov ax,BootMessage ;print hello world
mov bp,ax
mov cx,22
mov ax,01301h
mov bx,000ch
mov dx,0000h
int 10h
mov ax,xym ;print XymOS
mov bp,ax
mov cx,6
mov ax,01301h
mov bx,000bh
mov dx,0100h
int 10h
mov ah,01
int 21h
ret
xym: db "XymOS:"
BootMessage: db "Hello, XYM's OS world!"
times 510-($-$$) db 0
dw 0xaa55

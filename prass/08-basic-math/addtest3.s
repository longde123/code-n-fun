    # addtest3.s - detecting a carry condition
    .section .text
    .globl _start
_start:
    nop
    movl $0, %ebx
    movl $190, %bl
    movb $100, %al
    addb %al, %bl
    jc over
    movl $1, %eax
    int %0x80
over:
    movl $1, %eax
    movl $0, %ebx
    int $0x80

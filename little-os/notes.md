# Notes on Little-OS development

## 1. First Configuration

We are going to load a little program (```loader.asm```) that moves
```0xCAFEBABE``` to ```eax``` register.
We are targeting a 32 bit platform. In NASM you can target 32 bits using:

```
nasm -f elf32 loader.nasm
```

Since we are loading the "kernel" via GRUB, and GRUB itself takes 1MB
(```0x00100000```) the kernel needs to be loaded at a memory address larger or
equal to that. So we need to tell the linker about this (see ```link.ld```), and
link the program using:

```
ld -T link.ld -melf_i386 loader.o kernel.elf
```

To load the program by a machine we need a bootable image, we are using an ISO.
The ISO is created using El-Torito standard (see
[OS Dev wiki](http://wiki.osdev.org/El-Torito)), we need the following structure
to generate the ISO:

```
iso/
└── boot
    ├── grub
    │   ├── menu.lst
    │   └── stage2_eltorito
    └── kernel.elf
```

where ```menu.lst``` is a GRUB configuration file. To generate the ISO image
run:

```
genisoimage -R -b boot/grub/stage2_eltorito -no-emul-boot -boot-load-size 4 \
-A os -input-charset utf8 -quiet -boot-info-table -o os.iso iso
```

And launch Boschs:

```
bochs -f boochsrc.txt -q
```

## 2. Setup C support

C needs a stack, to setup a stack point the ```esp``` register to a free memory
area (aligned on 4 bytes due to performance [TODO check why]). We are going to
reserve 4 MB of memory on the ```bss``` section, and then point the ```esp```
register to the end of this section (see ```kernel_stack``` on ```loader.asm```).

Remember that to call a C function from assembly we need to declare it as
```extern function_name```, push the arguments onto the stack starting with the
rightmost argument and finally call the function.

To compile C code tell the compiler that no extra libraries should be used,
stack protections should be removed and overall, that the presence of external
libs should not be assumed
(see [gcc link options](https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html)).

```
-m32 -nostdlib -nostdinc -fno-builtin -fno-stack-protector -nostartfiles
    -nodefaultlibs
```

## 3. Output

To interact with the hardware we can use (i) *memory-mapped I/0* or (ii) *I/0
ports*. On the one hand, when the hardware uses a (i) memory mapped model we
write at a specific memory address, the hardware reads and the screen is
updated; on the other hand, if the hardware uses I/O ports we use the assembly
```in``` and ```out``` instructions to communicate.

#### Framebuffer

The framebuffer displays the contents of a memory buffer to the screen, it uses
memory-mapped I/0 with the starting address: ```0x000B8000```. It has 80 columns
and 25 rows, first cell is row zero, column zero, second cell is row zero,
column one etc.

To write a letter onto the screen we need 16 bits where:

* Bits 0-3 define the background colour.
* Bits 4-7 define the foreground colour.
* Bits 8-15 define the ASCII value of the character.

The available colours are defined in ```colours.h```.

To move the cursor of the framebuffer we are using I/O ports. The position of
the cursor is determined by 16 bits, where 0 means row zero position 0, 80 means
row one position zero etc. We need to use the ```out``` instruction two times
since it takes 8 bits and we need 16. The instruction has the following syntax:

```
out port, value
```

Where:
 * Port ```0x3D4``` with value ```14``` it is used to tell the framebuffer to
 expect the higher bits, whereas port ```0x3D4``` with value ```15``` tells that
 we are sending the lower bits.
 * Port ```0x3D5``` along with a value sends the corresponding bits' value.

#### Serial Ports

Serial ports are controlled via I/O ports, and they need to be configured first.
Baud rate (speed used to send data), parity bit, stop bits and the number of
bits that represent a unit of data are the things to configure.

See [*Serial Programming*](https://en.wikibooks.org/wiki/Serial_Programming/8250_UART_Programming#UART_Registers)
and [*Serial Ports*](http://wiki.osdev.org/Serial_ports) for more info.

###### Line configuration

It determines how data is being set over the line, it uses the *line command
port* of the serial port. Speed and how the data should be sent must be
configured.

See ```serial_configure_baud_rate``` and ```serial_configure_line```
on ```serial.h```.

###### Buffer configuration

When data needs to be transmitted it is placed on a FIFO queue that acts like
a buffer. We need to configure how many bytes are going to be stored on the
buffer, how large are they going to be, etc.

See ```serial_configure_buffers``` on ```serial.h```.

###### Modem configuration

The modem is used to enable flow control.

See ```serial_configure_modem``` on ```serial.h``.


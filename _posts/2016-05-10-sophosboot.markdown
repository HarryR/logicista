---
layout: post
title:  Boot Analysis of SophOS SafeGuard Enterprise 7.0
date:   2016-05-09 00:00:00
categories: [qemu, bochs, freebsd, binvis, boot, ida, nasm, sophos, safeguard, utimaco, research]
coverimage: /img/posts/star_trails_over_the_vlt_in_paranal.jpg
covertitle: Star trails over the VLT in Paranal
---

In this article we're tracing the bootup sequence of the Sophos SafeGuard Enteprise disk encryption product, the perspective taken is that if I were to use this product would it be prevent evil-maid attacks and be resiliant to key extraction and reverse engineering.

Aside from doing something silly like keeping your username and password on a post-it note on your laptop, using BitLocker encryption on Windows is usually enough to prevent cold-boot attacks as long as there is a hardware assisted security module, like the TPM, which can store keys and serve as the root and enforcer for the chain of trust. Because of the wide proliferation of BitLocker there has been a lot of good independent research leading, sometimes leading to novel discoveries to extract encryption keys can be extracted from an otherwise inpenetrable powered-on computer via direct memory access (rogue firewire or PCI bus device, liquid nitrogen etc.).

However, SafeGuard and Windows 7 doesn't use BitLocker when you use the default settings:

> Under Windows 7 (BIOS) ADDLOCAL=ALL installs the SafeGuard
> volume-based encryption and all other available features. Under Windows
> 8 ADDLOCAL=ALL installs BitLocker support and all other available features.

After securely encrypting a laptop with their product I find that it might not be using BitLocker and there aren't any publicly available studies of SafeGuard disk encryption to give me that warm fuzzy feeling knowing my data is probably safe. It can even be configured to boot up until the Windows login screen without any interaction - which is commonly used to make the encryption and security seamless.

Personally I think the notion of an encrypted laptop which powers-on and boots the OS without needing an extra token or password to decrypt data is very dangerous if the attacker has enough resources and/or uber geek skills, but a large number of companies and individuals feel the level of security it provides is adequate protection against leaking data at rest.

Anyway, what does the laptop do when you turn it on?

 1. Bios
 2. Sophos Boot Loader
 3. 640x480 white screen
 4. then a few shades of grey
 5. 1024x768 black screen
 6. then a cursor + sophos safeguard logo
 7. dialog box saying 'Auto-Login', looks like Qt
 8. white screen + cursor
 9. Windows boot loader
 10. Login screen
 ...

If the disk image is booted under both qemu-system-x86_64 and VirtualBox windows blue-screens early in the boot-up process - but by reaching that important step it means that it's able to load the Windows bootloader from what was an otherwise encrypted disk, and from that I initially guessed the Sophos software is doing some kinda decryption with keys stored on-disk albeit in an obfuscated fashion.


## Qemu + pmemsave + binwalk

There are two techniques I could use to find out what's going on in the Sophos boot loader, stepping through the boot process is very time consuming with current tools (but Panda may speed that up soon) and isn't very good getting an overview of the system in a running state, the other is dumping physical memory while it runs inside Qemu and analysing it with various tools.

When using qemu-system-i386 the system conveniently hangs when it tries to switch to x86_64 mode, acting as a natural breakpoint - by ths time the 'auto-login' screen has already disappeared and I thought the hang may even be caused by the Windows boot loader.

To discover of what going on in each of the stages a full physical memory dump was saved whenever the stage of the VM appeared to change, providing a series of convenient snapshots that can be diffed and analyzed.

```
$ qemu-system-i386 -enable-kvm -m 512 -monitor telnet:127.0.0.1:1234,server,nowait disk-sda.raw &
$ telnet 127.0.0.1 1234
(qemu) stop
(qemu) pmemsave 0 536870912 stage-1.pmemdump
(qemu) cont
...
(qemu) stop
(qemu) pmemsave 0 536870912 stage-2.pmemdump
...
etc.
```

A few very interesting things were found from the inital memory dumps:

[Utimaco](https://www.utimaco.com/en/products/) is referenced very early on in the boot sequence, they are a provider of encryption software and HSMs whos software arm was acquired by [Sophos in 2009](https://www.sophos.com/en-us/press-office/press-releases/2009/07/utimaco-integration.aspx).

The Sophos boot stage appears to be a FreeBSD 6.1 kernel from 2006, there's also a local root privilege escalation [on exploit-db.com](https://www.exploit-db.com/exploits/16951/).

```
(May  5 22:16:40 utimaco syslogd: kernel boot file is /boot/kernel/kernel.ko
May  5 22:16:40 utimaco kernel: Copyright (c) 1992-2006 The FreeBSD Project.
May  5 22:16:40 utimaco kernel: Copyright (c) 1979, 1980, 1983, 1986, 1988, 1989, 1991, 1992, 1993, 1994
May  5 22:16:40 utimaco kernel: The Regents of the University of California. All rights reserved.
May  5 22:16:40 utimaco kernel: FreeBSD 6.1-RELEASE #1: Tue Jun  9 00:38:58 CEST 2015
May  5 22:16:40 utimaco kernel: root@at097vm020b081.green.sophos:/root/ps/BCM/SGN7SR/freebsd/sgm_kernel_61/sw/kernel/obj/PHOENIX
May  5 22:16:40 utimaco kernel: Timecounter "i8254" frequency 1193182 Hz quality 0
May  5 22:16:40 utimaco kernel: CPU: QEMU Virtual CPU version 2.4.0 (2009.15-MHz 686-class CPU)
May  5 22:16:40 utimaco kernel: Origin = "GenuineIntel"  Id = 0x663  Stepping = 3
May  5 22:16:40 utimaco kernel: Features=0x781abfd<FPU,DE,PSE,TSC,MSR,PAE,MCE,CX8,APIC,SEP,PGE,CMOV,PAT,MMX,FXSR,SSE,SSE2>
```

Further investigation with `binwalk` found signatures of a YAFFS and Minix root filesystem, as well as software and library paths etc.:

```
171419        0x29D9B         Unix path: /freebsd/sgm_kernel_61/sw/boot/i386/loader/../../common/module.c
4221343       0x40699F        mcrypt 2.2 encrypted data, algorithm: blowfish-448, mode: CBC, keymode: 8bit
7908258       0x78ABA2        Minix filesystem, V1, big endian, 30 char names, 0 zones
11011580      0xA805FC        YAFFS filesystem
```

Also found after further analysis with hex workshop and `strings` were suspicious looking repeating strings and references to SecureString C++ symbols, could it be that these are deliberately zeroed out memory? To find out deeper digging will be needed, like trapping on memory read & write access.

```
FA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS3h73F3mFA0b1TEHS...
```

Because multiple snapshots were saved the output of binwalk can provide insight into what has been loaded into the filesystem cache or resides in memory as part of a running process, relying on signature detection alone allows the system to be mapped out without having to extract the filesystems or running code inside the OS.

One downside to using binwalk on raw memory dumps is we're looking at the physical layout rather than the virtual, and the kernel and user-land memory allocators don't necessarily order things in linear contiguous chunks, but the lack of FreeBSD support in tools like [Rekall](https://github.com/google/rekall) or [Volatility](https://github.com/volatilityfoundation/volatility) means there are no easy or automatic tools to analyse structures.

Tools used:

 * [qemu](http://wiki.qemu.org/Main_Page)
 * [strings](https://sourceware.org/binutils/docs/binutils/strings.html)
 * [binwalk](http://binwalk.org/)
 * [hex workshop](http://www.hexworkshop.com/)
 * [scruve/binvis](https://github.com/cortesi/scurve)


## Following the MBR sequence

So far I've been unable to extract the Minix or YAFFS filesystems from the memory dump of a live instance using binwalk, they're most likely wrongly identified signatures from high-entropy, so an alternate route is to trace the boot sequence to identify the locations of everything being loaded from disk and the location and order which data is loaded into memory.

The `SGBEMBR.BIN` file included in the version of Sophos SafeGuard downloaded matches the MBR of the laptop disk disk. The first stage of the MBR is loaded into 0x7C00 by the Bochs BIOS and then executed, it functions equivalently to the Windows7 MBR except it uses a trick to make it position independent.

### 1st Stage

```nasm
seg000:7C08                 mov     ax, 0F00h
seg000:7C0B                 mov     ss, ax          ; Stack segment
seg000:7C0D                 assume ss:nothing
seg000:7C0D                 mov     sp, 0FFEh       ; Base of stack
seg000:7C10                 sti                     ; enable interrupts
seg000:7C11                 cld                     ; clear direction
seg000:7C12                 call    $+3             ; Call to next instruction
seg000:7C15                 pop     dx              ; DX is now IP
seg000:7C16                 sub     dx, 15h         ; DX=7c00
seg000:7C1A                 mov     bx, cs          ; BX=0
seg000:7C1C                 shr     dx, 4           ; DX=07c0
seg000:7C1F                 add     dx, bx   
seg000:7C21                 mov     ds, dx          ; DS=07c0
seg000:7C23                 push    ax              ; AX=0f00 - Segment for jmp
seg000:7C24                 mov     es, ax          ; ES=0f00
seg000:7C26                 push    0E0h            ; Offset for jmp
seg000:7C29                 xor     si, si          ; SI=0
seg000:7C2B                 mov     di, si          ; DI=0
seg000:7C2D                 mov     cx, 100h        ; 512 bytes
; At this point ES=0f00, DI=0, DS=07c0, SI=0
; ... so move 512 bytes to f000 from 7c00
seg000:7C30                 rep movsw word ptr es:[di], word ptr ds:[si]
seg000:7C32                 retf  ; jmp to 0F00:00E0 (0xF0E0)
```

### 2nd Stage

The second stage of the MBR can be extracted and disassembled:

```
$ dd if=SafeGuard/SGBEMBR.BIN count=512 bs=1 skip=224 of=MBR2-stage2.bin
$ ndisasm -o 0xF000 MBR2-stage2.bin  | less
```

It performs 3 disk sector reads using INT 13 extended read extension `42h` which takes a disk packet from DS:SI (at `DS:00B8`) which is:

 * blocks to transfer WORD (0x10) - 5kb
 * transfer buffer DWORD (0x7C00)
 * starting absolute block number (0x3EBD320, about 31gb into the disk)

Address Reference:

 * ds:0B6h - previously discovered drive ID
 * ds:0B7h - sectors to read?
 * ds:0B8h - Packet address
 * ds:0BAh - sectors to read
 * ds:0BCh - segment:offset pointer to the memory buffer to which sectors will be transferred
 * ds:0BEh - ?? it's 0...
 * ds:0D0h - absolute number of the start of the sectors to be read (1st sector of drive has number 0)

```nasm
seg000:F108                 mov     ah, 42h
seg000:F10A                 mov     dl, ds:0B6h     ; Previously discovered drive (0)
seg000:F10E                 mov     si, 0B8h        ; What is SI??
seg000:F111                 jmp     short ReadSectors
...
seg000:F14C ReadSectors:                            ; CODE XREF: sub_F0E0+31
seg000:F14C                 mov     di, 3           ; Total number of sectors
seg000:F14F
seg000:F14F SectorReadLoop:                         ; CODE XREF: sub_F0E0+82
seg000:F14F                 mov     al, ds:0B7h     ; AL=01, sectors to read
seg000:F152                 mov     ds:0BAh, al     
seg000:F155                 pusha                   ; DH=8 (in Bochs anyway)
seg000:F156                 int     13h             ; DISK - READ SECTORS INTO MEMORY
seg000:F156                                         ; AL = number of sectors to read, CH = track, CL = sector
seg000:F156                                         ; DH = head, DL = drive, ES:BX -> buffer to fill
seg000:F156                                         ; Return: CF set on error, AH = status, AL = number of sectors read
seg000:F158                 popa
seg000:F159                 jnb     short OkFinished
seg000:F15B                 pusha
seg000:F15C                 xor     ah, ah
seg000:F15E                 int     13h             ; DISK - RESET DISK SYSTEM
seg000:F15E                                         ; DL = drive (if bit 7 is set both hard disks and floppy disks reset)
seg000:F160                 popa
seg000:F161                 dec     di              ; DI = Sector count 
seg000:F162                 jnz     short SectorReadLoop
seg000:F164
seg000:F164 OkFinished:                              ; CODE XREF: sub_F0E0+3B
seg000:F164                 mov     si, 3Fh
seg000:F167                 xor     al, al
seg000:F169                 jmp     near ptr 0F080h  ; Fail pathway
```

Afterwards the command jumps back to 0:07c00, putting a breakpoint at 0x07c00 shows it gets hit twice as control gets passed from the MBR to the code loaded from the disk. If 6 bytes at the end of the sector match hard-coded magic values it will jump to an alternate pathway which was left unexplored.

```nasm
seg000:F16C OkFinished:                             ; CODE XREF: sub_F0E0+79
seg000:F16C                 push    ax              ; save for later
seg000:F16D                 push    es
seg000:F16E                 push    di
seg000:F16F                 mov     ax, ds:0BEh     ; AX=0
seg000:F172                 mov     es, ax          ; ES=0
seg000:F174                 mov     ax, ds:0BCh     ; segment:offset pointer dword (0x7c00)
seg000:F177                 mov     di, ax          ; ES:DI = 0:7c00
                            ; What are these values (0C350h & 0AA55h) exactly?
seg000:F179                 cmp     dword ptr es:[di+1FAh], 0C350h
seg000:F183                 jnz     near ptr 0F097h ; Alternate path
seg000:F187                 cmp     word ptr es:[di+1FEh], 0AA55h
seg000:F18E                 jnz     near ptr 0F097h ; Fail pathway
seg000:F192                 pop     di
seg000:F193                 pop     es
seg000:F194                 pop     ax
seg000:F195                 jmp     dword ptr ds:0BCh ; (to 7c00)
```

References:
 
 * [Chapter 2, The x86 Microprocessor & its Architecture](http://www.byclb.com/TR/Tutorials/microprocessors/ch2_1.htm)
 * [X86 Assembly/Data Transfer](https://en.wikibooks.org/wiki/X86_Assembly/Data_Transfer)
 * [8.13. Using Bochs internal debugger](http://bochs.sourceforge.net/doc/docbook/user/internal-debugger.html)
 * [Pathways through the Windows 7 MBR](http://thestarman.pcministry.com/asm/bochs/W7MBRpaths.html)
 * [IBM/MS INT 13 Extensions - EXTENDED READ](http://www.ctyme.com/intr/rb-0708.htm)


## The Disk Boot Loader (3rd stage)

After finding out the location of the next bootloader on disk it can be extracted directly with `dd`, the result can be disassembled to verify you have the correct position by comparing it to the mnemonic window in the Bochs debugger. Breaking at 0x7c3e will only be triggered by this stage.

```
$ dd if=sda.raw bs=512 skip=65786656 count=48 of=third-stage.raw
$ ndisasm -o 0x7c00 third-stage.raw | less
```

The previous stage had loaded a number of sectors into memory, at the start is another short boot loader followed by 9728 bytes obfuscated code which is decrypted before jumping to it. At this point I was getting bored of the multiple boot loader stages, but finding the boot loader is relying on security through obscrutity has given me new hope of finding keys of some sort, the boot process is still in real-mode at this point.

```nasm
seg000:7C8B                 mov     cx, 1300h      ; 4864 words
seg000:7C91                 mov     si, B400h      ; Data copied from B400
seg000:7C97                 mov     di, 8E00h      ; Destination 0000:8E00
seg000:7C9D                 call    DecryptBytes   ; 0x7dc7
seg000:7CA0                 call    word 0x8f14    ; Fourth stage...
seg000:7CA3                 jmp     jmp word 0x9010
...
seg000:7DC7 DecryptBytes    proc near               ; CODE XREF: seg000:7C9D
seg000:7DC7                 push    si
seg000:7DC8                 xor     eax, eax
seg000:7DCB
seg000:7DCB DecryptByteLoop:                        ; CODE XREF: DecryptBytes+12
seg000:7DCB                 or      cl, cl
seg000:7DCD                 jnz     short loc_7DD1
seg000:7DCF                 pop     si
seg000:7DD0                 push    si
seg000:7DD1
seg000:7DD1 loc_7DD1:                               ; CODE XREF: DecryptBytes+6
seg000:7DD1                 lodsw                   ; Load word at address DS:SI into AX
seg000:7DD2                 rol     ax, 1           ; Payload is obfuscated using a simple XOR cipher.
seg000:7DD4                 xor     [di], ax
seg000:7DD6                 add     di, 2
seg000:7DD9                 loop    DecryptByteLoop ; CX was originally 1300h
seg000:7DDB                 pop     si
seg000:7DDC                 retn
seg000:7DDC DecryptBytes    endp
```

To decrypt the payload for easier analysis dumped the memory using qemu, the `third-stage.raw` file's origin is `7C00h`, so the two absolute offsets needed within it are `B400h - 7C00h` (14336 bytes) and `8E00h - 7C00h` (4608 bytes).

 * `B400h` - one-time key XOR'd against code (14336 byte offset from 7C00)
 * `8E00h` - code to be revealed after the XOR (4608 byte offset from 7C00)

Looking at a hex dump of the memory at `8E00h` I see a familiar string, Amnesiac is the default name for FreeBSD systems and the WEV indicates it's a FreeBSD disk label and/or MBR - but none of the standard magic strings match. Because it was hidden the disklabel didn't show up when `binwalk` was run against the laptop disk, is it possible that this data is the `SGBEKERNEL.BIN` file which is shipped along side `SGBEMBR.BIN`?

```
00000000  57 45 56 82 00 00 00 00  61 6d 6e 65 73 69 61 63  |WEV.....amnesiac|
00000010  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000020  00 00 00 00 00 00 00 00  00 02 00 00 3f 00 00 00  |............?...|
```

Writing tools to extract data from files can take more time than just attaching GDB to Qemu to gain better control over exactly when you do memory dumps. By putting a hardware breakpoint at `7DDCh` the intermediate states and decrypted code can be saved.

```
(gdb) target remote | exec qemu-system-i386 -gdb stdio -monitor telnet:127.0.0.1:1234,server,nowait sda.raw
(gdb) hbreak *0x7DDC
(qemu) pmemsave 0x8E00 9728 stage4-8E00.raw
(qemu) pmemsave 0xB400 9728 stage4-B400.raw
```

### A20 gate (Stage 4)

This stage is executed after being decrypted, then it 'decrypts' more stuff, but interestingly it also enables the A20 gate and jumps back for the next stage of the bootloader, the recurring pattern of decryption seems like the software developers either have an automated packing tool for these tiny bootloader segments, or it has been carefully engineered to be tedious to extract.

The previous stage of the bootloader makes more sense now:

```nasm
seg000:7CA0                 call    word 0x8f14    ; Fourth stage...
seg000:7CA3                 jmp     jmp word 0x9010
...
seg000:8F14 FourthStageMain proc near
seg000:8F14                 mov     cx, 0B00h     ; 2816 bytes 
seg000:8F1A                 add     di, 200h      ; SI=B400h, DI=B600h
seg000:8F21                 call    DecryptBytes  ; (8F5Fh)
seg000:8F24                 mov     bx, 9000h
seg000:8F27                 mov     si, [bx+0Ah]  ; SI=0C50h
seg000:8F2A                 add     si, bx        ; SI=9C50h
seg000:8F2C                 mov     di, 0A000h
seg000:8F2F                 mov     cx, 0B400h
...
seg000:8F5B                 call    EnableA20
seg000:8F5E                 retn
seg000:8F5E FourthStageMain endp
```

After decrypting 2816 bytes from `0:B400h` into `0:b600-0:C100h` the memory can be dumped for analysis, it then moves 12208 bytes from `0:CBFF` to` 0:CFAFh`, then 5632 bytes from `0:B9B0h` to `0:B7B0h`, then zeroes out 12880 bytes at `CDB0h`... at this point I'm not 100% sure why it's moving two blocks over each other then zeroing out some bytes before enabling the A20 line...

```
(gdb) hbreak *0x8F24
(qemu) pmemsave 0xB600 0xB00 stage4-B600.raw
$ ndisasm -o 0xB600 stage4-B600.raw | less
```

Anyway, it produced good findings - the Sophos kernel loader:

```
Copyright (c) 1996 - 2015 Sophos Limited. All rights reserved.
SafeGuard is a registered trademark of Sophos Limited and Sophos Group.
Sophos SafeGuard is starting.
Please wait ...
```

### Upgrade to 32bit Protected Mode (Stage 5 - BTX)

Because of the moving about, decryption and loading that takes place it's not trivial to trace exactly what was loaded from disk and where it went into memory, but the end of the fourth stage jumps to `0x9010`, this can be dumped with:

```
(gdb) hbreak *0x8F5E
(qemu) pmemsave 0x9000 0x1000 stage5-9000.raw
```

Mostly the code seems to be concerned with setting up the RTC, interrupts, IDT and GDT etc, as well as enabling protected mode (16bit), the jump to `8:90ECh` can be confusing, however because this happens immediately after the GDT has been setup what it's effectively done is change `CS` to `8h` while still being able to continue to the next instruction.

Using the `Edit > Segments > Create Segment` menu in IDA we're able to create a new 32bit segment starting at `90ECh`, without this IDA will not accurately decode the instructions as you see them in Bochs (or Qemu), with careful adjustment new segments can be created as you trace through the code.

```nasm
seg000:90CD                 mov     bx, 2820h
seg000:90D0                 call    setpic
seg000:90D3                 lidt    fword ptr ds:idt_data
seg000:90D8                 lgdt    fword ptr ds:gdt_data
seg000:90DD                 mov     eax, cr0        ; Setup protected mode
seg000:90E0                 or      eax, 1
seg000:90E4                 mov     cr0, eax
seg000:90E7                 jmp     far ptr 8:90ECh ; Jump to 90ec
...
seg008:000090EC                 xor     ecx, ecx
seg008:000090EE                 mov     cl, 10h
seg008:000090F0                 mov     ss, ecx
```

At this point, and after having skimmed the FreeBSD Architecture Handbook it seems like this stages code is very similar to FreeBSDs `btx.S`, having traced through the boot-up sequence this far I'm glad that I've reached familiar ground with well documented source code available, after comparing up the `btx.S` assembly from various versions of FreeBSD it's possible to see exactly what has been added by Sophos/Utimaco.

Notably one of the additional subroutes found in the Sophos bootloader at `952Ah` writes bytes to specific locations in memory:

 * at `0:9CFF0h` it writes 3 dwords: `12345678h` `1EA00000h` `12345678h`
 * then at `0:1EA00000h` it writes 8 words: `6C43A683h`, `4h`, `8h`, `0h`, `8FB80226h`, `600h`, 0h, 0h
 * then copies `600h` (1536) bytes from `0:0h` to `0:1EA00020h`
 * the appends to it the dword at `0:5000h` (`D0h` / 208)
 * then it appends the dword `0h`
 * then it appends the dword `5000h`
 * then it appends  `d0h` bytes from `0:0h`
 * then it appends the dword `0h`

The result is `700h` bytes beginning at `0:1EA00000h`, which can be saved for later reference, I'm still not 100% sure what the added code is doing, but afterwards the 5th stage returns to `0:A000h`. While I could see the memory in the Bochs debugger, when I when attached to Qemu with GDB all I got were zeroes.

```
(bochs) hbreak *0x95C7
(bochs) writemem "stage5-1EA00000.raw" 0x1EA00000 0x700
```

BTX is interesting because it's a tiny kernel which provides the bare minimum necessary for a 32bit protected mode ELF to be run. It consist of 5 small files: `btx.S`, btxcsu.s`, `btxsys.s`, `btxv86.s` and `btxldr.S`.

In this case BTX loads an executable into `A000h` (where `30000h` is the upper limit for how large it can be).

```
(bochs) writemem "stage5-A000.raw" 0xA000 0x26000
```

References:

 * [.gdbinit for RE](https://reverse.put.as/2012/04/13/gdbinit-v8-0-simultaneous-support-for-x86x86_64-and-arm-architectures/)
 * [A20 - a pain from the past](https://www.win.tue.nl/~aeb/linux/kbd/A20.html)
 * [Mixed 16/32-bit code reversing using IDA](http://reverseengineering.stackexchange.com/questions/2440/mixed-16-32-bit-code-reversing-using-ida)
 * [The BTX Server](https://www.freebsd.org/doc/en_US.ISO8859-1/books/arch-handbook/btx-server.html)
 * [LTR - Load Task Register](http://x86.renejeschke.de/html/file_module_x86_id_163.html)


## Disklabel Encryption Analysis in Boot2 (Stage 5)

In retrospect tracing through the boot sequence was an interesting pedagogical exercise, but the aim is to extract the boot filesystem and where disk data is read to etc. After more in-depth analysis of `stage5-A000.raw` it shares the majority if its code with FreeBSDs `boot2.c` which is easier to read than assembly, however there are some critical differences which required reverse engineering up until this point to discover.

By putting a breakpoint at `AF77h` in `load` we can get the inode number of the `/boot/loader` file, in this case it's `6EBh`, but what's the offset of the filesystem on the disk? The `drvread` function will be called twice to read the drive and FS superblocks, from which the LBA, the number of blocks being read and where they're stored in memory can be determined. Working from this point the function and variable names from the boot2 source code could be matched up with their equivalent names in IDA as well as defining structures and types, making the added proprietary code stand out more.

Disk blocks/sectors are encrypted and the disklabel is obfuscated, I was able to determine that the cipher operated on 64bit blocks and used a 128bit key, as well as some magic numbers used for shifts etc. but the easiest two functions to identify eventually lead me to finding source code on Google which had very similarly structured routines and were part of IDEA, a 128bit block cipher.

In `dskread`, where the disk metadata is loaded, it uses a simple XOR style cipher against the 20th sector to decode the BSD disklabel with the magic number `0x82564557`. Important sectors to remember:

 * 1 - disk label, 'obfuscated'
 * 20 - XOR block for disk label
 * 126 - contains decryption keys
 * 128+ - encrypted data

Using only symmetric encryption with no external key source or any way of verifying the authenticity of the data the boot loader is loading it should be possible to run arbitrary programs in the FreeBSD environment, leaving users open to persistent and mostly undetectable malware.

Something to note is that after the decryption keys have been retrieved the encryption subkeys are wiped from memory so as to leave no trace in memory dumps, whoever wrote this code was deliberately attempting to hide the keys used, what remains to be seen is if these keys are used to encrypt the rest of the drive or if it's just to hide the SafeGuard OS.

```c
    rdsts = drvread((char *)data, g_dsk.start + 1, 1u);// LABELSELECTOR
    if ( !rdsts )                               // If read was successful
    {                                           // Read 'special' sector 20 into secbuf
      drvread((char *)secbuf, g_dsk.start + 20, 1u);
      j = 0;
      do                                        // Then 'decrypt' disklabel (1) against sector 20
      {
        rotchr = 2 * secbuf[j] | ((unsigned int)(signed __int16)secbuf[j] >> 31);
        secbuf[j] = rotchr;
        data[j++] ^= rotchr;
      }
      while ( j <= 255 );
      if ( *(_DWORD *)data == 0x82564557 && *((_DWORD *)data + 0x21) == 0x82564557 )
      {                                         // Do magic and magic2 indicate it's a valid disk sector?
        // ...
        g_crypto_nblk = part_nblk - 128;        // Total number of encrypted sectors
        crypto_lba_start = g_dsk.start + 128;   // LBA of first encrypted sector
        g_dsk.start += *((_DWORD *)d_partition + 38);
        g_dsk.start -= *((_DWORD *)data + 46);
        g_crypto_start_lba = (unsigned int)crypto_lba_start;
        g_label_decrypted = 1;                  // Setup is only run once
        if ( !drvread((char *)data, g_dsk.start + 126, 1u) )
        {                                       // Then setup encryption using keys from disklabel
          setup_decryption(i, encrypt_subkey, g_decrypt_key, (char *)data);
          zerocnt = 0;                          // For some reason they don't want these keys in memory
          do                                    // Zero out the first 104 bytes...
            *((_BYTE *)encrypt_subkey + zerocnt++) = 0;
          while ( zerocnt <= 103 );
        }
      }
      // ...
```

The `decrypt_sectors` routine below uses the LBA as the IV to decrypt a sector in CBC mode as a series of 128bit blocks, I'm glad that, while they did leave the keys under the doormat they, are following best practice and *not* using ECB, as that would leave them open to all kinds of cryptanalysis attacks.

```c
        buf_2 = buf_1;
        idx_IV = 0;
        do
          lba_IV[idx_IV++] = lba_1;
        while ( idx_IV <= 3 );
        v12 = 0;
        do
        {
          IDEA_cipher((unsigned int)block_out, buf_2, (idea_block_t *)block_out, secretkey);
          idx_1 = 0;
          do
          {
            idx = idx_1;
            chr = block_out[idx_1] ^ lba_IV[idx_1];
            block_out[idx] = chr;
            lba_IV[idx] = (*buf_2)[idx_1];
            (*buf_2)[idx_1++] = chr;
            block_out[idx] = 0;
          }
          while ( idx_1 <= 3 );
          ++v12;
          ++buf_2;
        }
        while ( v12 <= 63 );
        ++lba_1;
        buf_1 += 64;
```

But where exactly does the decryption key come from, and how can it be replicated so tools can be built to decrypt this type of filesystem? The `setup_decryption` routine uses bytes from the decrypted disklabel as an additional parameter to the `IDEA_cipher` function, deviating from the source code of the IDEA algorithm used as a reference.

One interesting feature of IDEA is that it has the two derived keys - the encrypt key and the decrypt key, making it a somewhat asynchronous block cipher. Technically I think it's interesting that they've hard-coded the master key into the boot loader, then uses data from the disk to derive the decryption and encryption keys.

```c

    idx = 0x11; // Find offset of encryption key
    do
    {
      offset = ((inout_buf[idx + 4] & 1) << 8) | ((inout_buf[idx + 3] & 3) << 6) | 16 * (inout_buf[idx + 2] & 3) | 4 * (inout_buf[idx + 1] & 3) | inout_buf[idx] & 3;
      if ( (unsigned int)(offset - 1) <= 0x1EE )
        break;
      ++idx;
    }
    while ( idx <= 0x1FB );

    // Setup first master key    
    hardcoded_key = {0x6F4E, ..., 0x2173};
    IDEA_encrypt_subkeys(hardcoded_key, master_encrypt_subkeys);
    IDEA_decrypt_subkeys(master_encrypt_subkeys, master_decrypt_subkeys);

    // Decrypt offset within sector, to get the disk master key in `outkey1`
    bufptr = (idea_block_t *)&inout_buf[offset];
    IDEA_cipher(bufptr, tmp_keys, master_decrypt_subkeys);
    IDEA_cipher(bufptr + 1, (idea_block_t *)tmp_keys[1], master_decrypt_subkeys);

    // Derive encrypt and decrypt keys
    IDEA_encrypt_subkeys((idea_key_t *)tmp_keys, out_encryptkeys);
    IDEA_decrypt_subkeys(out_encryptkeys, out_decryptkeys);

    // Then it overwrites the intermediate keys with another one?...
    hardcoded_key = {0x34DF, ..., 0x2795}; // Second hard-coded key
    IDEA_encrypt_subkeys(hardcoded_key, master_encrypt_subkeys);
    IDEA_decrypt_subkeys(master_encrypt_subkeys, master_decrypt_subkeys);
    IDEA_cipher(bufptr, tmp_keys, master_decrypt_subkeys);
    IDEA_cipher(bufptr + 1, (idea_block_t *)tmp_keys[1], master_decrypt_subkeys);
```

While it's handy to have neatly decompiled source code ready to include in an application, it isn't as immediately compleable or as well tested as the IDEA reference code, it should be very easy to create proof of concept code after extracting the decryption key from memory using one of the techniques used above.

References:

 * [IDEA cipher source code](https://github.com/dgoulet/hackus/blob/master/hackus-2011/ctf/ctf02/ideaplus.c)
 * [FreeBSD 6.1 ufsread.c](https://github.com/freebsd/freebsd/blob/release/6.1.0/sys/boot/common/ufsread.c)
 * [FreeBSD /boot/loader](https://www.freebsd.org/cgi/man.cgi?query=loader&apropos=0&sektion=8&manpath=FreeBSD+6.1-RELEASE&arch=default&format=html)


## Further Reading

 * [Sophos Safeguard Encryption](https://www.sophos.com/en-us/products/safeguard-encryption.aspx)
 * [NIST Windows 7 BitLocker Drive Encryption
Security Policy](http://csrc.nist.gov/groups/STM/cmvp/documents/140-1/140sp/140sp1332.pdf)
 * [The Art of Bootkit Development](http://www.stoned-vienna.com/pdf/The-Art-of-Bootkit-Development.pdf)
 * [Can the NSA Break Microsoft's BitLocker?](https://www.schneier.com/blog/archives/2015/03/can_the_nsa_bre_1.html)

-------------------

[Header image](https://upload.wikimedia.org/wikipedia/commons/a/aa/Star_trails_over_the_VLT_in_Paranal.jpg) by [ESO/B. Tafreshi](http://twanight.org/)

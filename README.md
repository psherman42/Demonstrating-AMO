# Demonstrating-AMO
Simple examples showing how RISC-V atomic instructions work

Atomic instructions mean that there is *no* CPU interrupt between the memory read and the memory write of the trio of read, modify, and write operations. AMO instructions in the RISC-V ISA are somewhat similar to the "bit banding" of ARM ISA; and they are somewhat similar to *synchronized* blocks of critical code in high-level programming languages like Java.

### `LW`-`SW` toggling GPIO in a Finite Non-atomic Loop

```
  lui t6, 0x10012   # GPIO_BASE
  li t5, (1<<12)    # GPIO21
  li s0, 30         # i = 30
loop:
  lw t0, 0x0C(t6)   # x = gpio_output_val
  xor t0, t0, t5    # x ^= GPIO21
  sw t0, 0x0C(t6)   # gpio_output_val = x
  addi s0, so, -1   # i--
  bnez s0, loop     # {} while (i != 0);
```

![lw-xor-sw](https://github.com/psherman42/Demonstrating-AMO/assets/36460742/53631aca-6491-49d5-aa52-25a131213a66)


### `AMOXOR` toggling GPIO in a Finite Atomic Loop

```
  li t6, 0x1001200C        # GPIO_BASE + GPIO_OUTPUT_VAL
  li t5, (1<<21)           # GPIO21
  li s0, 12                # i = 12
loop:
  nop
  nop
  # change x0 to x1..x31 if evenly spaced pulses are desired, see note below
  amoxor.w x0, t5, (t6)    # t = gpio_output_val; gpio_output_val = t ^ GPIO21; x0 = t
  addi s0, s0, -1          # i--
  bnez s0, loop            # {} while (i != 0);
```

![amoxor w-loop-finite](https://github.com/psherman42/Demonstrating-AMO/assets/36460742/9fecde62-da47-4c41-8b44-bd50073172fa)

### `AMOAND` and `AMOOR` toggling GPIO in a Finite Atomic Loop

```
  li t6, 0x1001200C        # GPIO_BASE + GPIO_OUTPUT_VAL
  li t5, (1<<21)           # GPIO21
  li s0, 6                 # i = 6
loop:
  nop
  not t5, t5
  # change x0 to x1..x31 if evenly spaced pulses are desired, see note below
  amoand.w x0, t5, (t6)    # t = gpio_output_val; gpio_output_val = t & ~GPIO21; x0 = t
  not t5, t5
  # change x0 to x1..x31 if evenly spaced pulses are desired, see note below
  amoor.w x0, t5, (t6)     # t = gpio_output_val; gpio_output_val = t | GPIO21; x0 = t
  addi s0, s0, -1          # i--
  bnez s0, loop            # {} while (i != 0);
```

![amo-andor w](https://github.com/psherman42/Demonstrating-AMO/assets/36460742/b199885f-11d7-453c-be04-37060cf92c9c)

#### A Word About Periodicity and the RISC-V `AMO` Instructions

When an AMO instruction has `x0` for its x[*rd*] and is in a tight little loop it behaves in a periodic but strangely and unevenly spaced way. Results vary depending how many NOPs are in the loop. This is unlike the non-atomic equivalent LW-op-SW, which always shows a periodic and evenly spaced pattern.

A RISC-V processor supports some finite number of in-flight I/O operations (the exact number being implementation dependent), and attempting to initiate another I/O operation when the buffer is full results in a pipeline flush. So you'll quickly get a few loop iterations' worth of AMOs in flight, then a subsequent iteration will incur a pipeline flush, making that iteration take several cycles longer than the other ones.

This phenomenon doesn't occur for the non-atomic variant because there's a RAW (Read-After-Write) hazard on the, e.g., XOR instruction that will result in a stall, preventing the processor from ever hitting the in-flight I/O limit.

Presumably, you could force the AMO version to behave similarly by inserting a dummy hazard. If you have the AMO write `t0` instead of `x0`--even if you never read the value it writes to t0--then there will be a loop-carried WAW (Write-After-Write) hazard that will cause the next iteration's AMO to stall until the current iteration's AMO completes.

The picture below shows the result of `AMOXOR` toggling GPIO twelve times in a Finite Atomic Loop when x[rd] is one of the non-trivial, non-zero registers x1..x31.

`amoxor.w t0, t5, (t6)  # note here t0 instead of x0`

![amo-x rd -force-stall](https://github.com/psherman42/Demonstrating-AMO/assets/36460742/3335f426-fd45-4e98-b198-c908a6609abd)

Thus, register `x0` is special; it is always zero, and when used in place of x[*rd*] as the target of an instruction pipeline's write-back stage it never needs the CPU to “stall” the pipeline. When the timing position of an operation is critical, careful consideration should be made when using register `x0` with any of the RISC-V AMO instructions.

### First Things, First - edit `riscv.mk` file and ...

... un-comment one set of *32-BIT* or *64-BIT* application tools, as desired.

... un-comment one set of *WIN* or *LIN* operating system variants, as desired.

... un-comment one set of *UM-232*, *TC*, *OLIMEX*, etc. hardware adapters, as desired.

### Workflow

To *clear* all intermediate and binary output files

`   make -f riscv.mk clean`

To *assemble, compile, link, and load* program into target **RAM** memory

`   make -f riscv.mk ramload`

To start target *running* from **RAM** memory

`   make -f riscv.mk ramrun`

To *assemble, compile, link, and load* program into target **ROM/Flash** memory

`   make -f riscv.mk romload`

To start target *running* from **ROM/Flash** memory

`   make -f riscv.mk romrun`

To start target *debugging* from **RAM** or **ROM/Flash** memory, respectively,

`   make -f riscv.mk ramdebug`

`   make -f riscv.mk romdebug`

An excellent and inexpensive oscilloscope to observe the results of above in real time on real hardware is the "Smart Scope" from https://www.lab-nation.com/store
 
### Further Reading

Krste Asanovic. "Computer Architecture and Engineering." University of California at Berkeley: EECS CS152/CS252.
https://www-inst.eecs.berkeley.edu/~cs152/sp20/lectures/L22-Synch.pdf

Sean Farhat. "Great Ideas in Computer Architecture: RISC-V Pipeline Hazards!" Notice especially the mention of "Must ignore writes to x0!" in the discussion of detecting the need for forwarding on PDF page 31.
https://inst.eecs.berkeley.edu/~cs61c/su20/pdfs/lectures/lec14.pdf

"RISC-V Pipelining and Hazards." University of California at Berkeley: EECS CS61C Spring 2022.
https://inst.eecs.berkeley.edu/~cs61c/sp22/pdfs/discussions/disc08-sols.pdf

Mikko Lipasti. Pipeline Hazards." University of Wisconsin at Madison: CE/CS 552.
https://pages.cs.wisc.edu/~karu/courses/cs552/fall2020/handouts/lecnotes/10_pipelinehazards.pdf

จุฑาวุฒิจันทรมาลี (Juthawut Chantharamalee). Pipeline (ไปป์ไลน์) บทที่ 12. Suan Dusit University, Bangkok, Thailand: Computer Science Department.
ชุดคาสั่งของ pipe line จะยอมรับการ process โดยที่ตัวอื่นๆช้าลงเมื่อมี
การถ่วงเวลาจะท าให้ชุดค าสั่งช้าลงด้วย ปัญหาที่เกิดขึ้น จากโครงสร้าง (Structural Hazard)
เมื่อมีการทา Pipeline มีการทับซ้อนกันของชุดคา สั่ง ในการทางาน เมื่อ functional unit เกิด
การทาซ ้าเป็นไปได้ที่ชุดคาสั่งมีการรวมกันในการทา Pipeline ถ้าการรวมชุดคาสั่งไม่สามารถจะ
บรรลุเป้าหมายได้ เพราะเกิดการขัดข้องของเครื่องเรียกว่า (Structural hazard) ตัวอย่างการเกิด Structural hazard เมื่อ
http://dusithost.dusit.ac.th/~juthawut_cha/download/L12_Pipeline.pdf

David Whalley. "The Laundry Analogy for Pipelining." Florida State University: Computer Science Department.
https://www.cs.fsu.edu/~whalley/cda3101/pipeline.pdf

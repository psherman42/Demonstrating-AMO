# Demonstrating-AMO
Simple examples showing how RISC-V atomic instructions work

### LW-SW toggling GPIO in a Finite Non-atomic Loop

```
  lui t6, 0x10012
  li t5, (1<<12)
  li s0, 30
loop:
  lw t0, 0x0C(t6)
  xor t0, t0, t5
  sw t0, 0x0C(t6)
  addi s0, so, -1
  bnez s0, loop
```

### AMOXOR toggling GPIO in a Finite Atomic Loop

```
  li t6, 0x1001200C
  li t5, (1<<21)
  li s0, 12
loop:
  nop
  nop
  amoxor.w x0, t5, (t6)
  addi s0, s0, -1
  bnez s0, loop
```

### AMOAND and AMOOR toggling GPIO in a Finite Atomic Loop

```
  li t6, 0x1001200C
  li t5, (1<<21)
  li s0, 6
loop:
  nop
  not t5, t5
  amoand.w x0, t5, (t6)
  not t5, t5
  amoor.w x0, t5, (t6)
  addi s0, s0, -1
  bnez s0, loop
```

#### Periodicity and the RISC-V `AMO` Instructions

When an AMO instruction has `x0` for its x[*rd*] and is in a tight little loop it behaves in a periodic but strangely and unevenly spaced way. Results vary depending how many NOPs are in the loop. This is unlike the non-atomic equivalent LW-op-SW, which always shows a periodic and evenly spaced pattern.

A RISC-V processor supports some finite number of in-flight I/O operations (the exact number being implementation dependent), and attempting to initiate another I/O operation when the buffer is full results in a pipeline flush. So you'll quickly get a few loop iterations' worth of AMOs in flight, then a subsequent iteration will incur a pipeline flush, making that iteration take several cycles longer than the other ones.

This phenomenon doesn't occur for the non-atomic variant because there's a RAW (Read-After-Write) hazard on the, e.g., XOR instruction that will result in a stall, preventing the processor from ever hitting the in-flight I/O limit.

Presumably, you could force the AMO version to behave similarly by inserting a dummy hazard. If you have the AMO write `t0` instead of `x0`--even if you never read the value it writes to t0--then there will be a loop-carried WAW (Write-After-Write) hazard that will cause the next iteration's AMO to stall until the current iteration's AMO completes.

Register `x0` is special; it is always zero, and when used as target of the instruction pipeline's write-back stage it never needs the CPU to “stall” the pipeline. Thus, careful consideration should be made when using register `x0` with any of the RISC-V AMO instructions.

### First Things, First - edit `riscv.mk` file and ...

... un-comment one set of *32-BIT* or *64-BIT* application tools, as desired.

... un-comment one set of *WIN* or *LIN* operating system variants, as desired.

... un-comment one set of *UM-232*, *TC*, *OLIMEX*, etc. hardware adapters, as desired.

### Workflow

To *clear* all intermediate and binary output files

`make -f riscv.mk clean`

To *assemble, compile, link, and load* program into target **RAM** memory

`make -f riscv.mk ramload`

To start target *running* from **RAM**

`make -f riscv.mk ramrun`

To *assemble, compile, link, and load* program into target **ROM** memory

`make -f riscv.mk romload`

To start target *running* from **ROM**

`make -f riscv.mk romrun`
 

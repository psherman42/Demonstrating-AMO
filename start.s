################################################
## atomic test
## 2023-08-30 pds    demo amo lock acq time

.section .text

###############################################
##
## entry point main reset vector
##

.globl _start
_start:
  lui a1, 0x80004
  addi sp, a1, -4

  li a0, 0x00001aaa # disable MPP, SPP. MPIE, SPIE, MIE, SIE
  csrrc x0, mstatus, a0

  csrw mip, zero
  csrw mie, zero

  # set trap handler
  la t0, clint_trap_handler
  csrrw zero, mtvec, t0

  #-------- gpio set up --------
  lui t6, 0x10012        # GPIO_BASE

  li t5, (1<<21)         # GPIO21
  li t4, (1<<22)         # GPIO22

  not t5, t5
  not t4, t4

  lw t0, 0x38(t6)        # x = gpio_iof_en
  and t0, t0, t5         # x &= ~GPIO21
  and t0, t0, t4         # x &= ~GPIO22
  sw t0, 0x38(t6)        # gpio_output_iof_en = x

  not t5, t5
  not t4, t4

  lw t0, 0x08(t6)        # x = gpio_output_en
  or t0, t0, t5          # x |= GPIO21
  or t0, t0, t4          # x |= GPIO22
  sw t0, 0x08(t6)        # gpio_output_en = x
  #-------- gpio set up --------

atomic_test:
  lui t6, 0x10012        # GPIO_BASE

  lw t0, 0x0C(t6)        # x = gpio_output_val
  or t0, t0, t4          # x |= GPIO22
  sw t0, 0x0C(t6)        # gpio_output_val = x

  #------- RV32I -------
  #
  li s0, 30
atomic_test_lwsw:
  lw t0, 0x0C(t6)        # x = gpio_output_val
  xor t0, t0, t5         # x ^= GPIO21
  sw t0, 0x0C(t6)        # gpio_output_val = x
  addi s0, s0, -1
  bnez s0, atomic_test_lwsw
  #
  #---------------------

  lw t0, 0x0C(t6)        # x = gpio_output_val
  xor t0, t0, t4         # x ^= GPIO22
  sw t0, 0x0C(t6)        # gpio_output_val = x

  addi t6, t6, 0x0C      # GPIO_BASE + GPIO_OUTPUT_VAL

  #------- RV32A -------
  #
#  nop
#atomic_test_amo_xor_inf:
#  amoxor.w x0, t5, (t6)  # gpio_output_val ^= GPIO21
# #amoxor.w t0, t5, (t6)  # gpio_output_val ^= GPIO21
#  j atomic_test_amo_xor_inf

#  li s0, 12
#atomic_test_amo_xor:
#  nop
#  nop
#  amoxor.w x0, t5, (t6)  # gpio_output_val ^= GPIO21
# #amoxor.w t0, t5, (t6)  # gpio_output_val ^= GPIO21
#  addi s0, s0, -1
#  bnez s0, atomic_test_amo_xor

  li s0, 6
atomic_test_amo_andor:
  nop
  not t5, t5
  amoand.w x0, t5, (t6)  # gpio_output_val &= ~GPIO21
 #amoand.w t0, t5, (t6)  # gpio_output_val &= ~GPIO21
  not t5, t5
  amoor.w x0, t5, (t6)   # gpio_output_val |= GPIO21
 #amoor.w t0, t5, (t6)   # gpio_output_val |= GPIO21
  addi s0, s0, -1
  bnez s0, atomic_test_amo_andor
  #
  #---------------------

  j atomic_test
  ret


  #-------- simple loop -------
#  lui t6, 0x10012        # GPIO_BASE
#  addi t6, t6, 0x0C      # GPIO_BASE + GPIO_OUTPUT_VAL
#  li t5, (1<<21)         # GPIO21
#simple_loop_init:
#  #nop              # stable.   0x0001
#  #addi x0, x0, 0   # stable.   0x0001
#  #add x0, x0, x0   # erratic.  00000033
#  #ori x0, x0, 0    # erratic.  00006013
#  #or x0, x0, x0    # erratic.  00006033
#simple_loop:
#  amoxor.w x0, t5, (t6)  # MARKER PULSE: gpio_output_val ^= (1<<22)
#  j simple_loop
  #-------- simple loop -------


.balign 8  # required 64-bit alignment for mtvec in vectored (non-direct) mode
clint_trap_handler: .weak clint_trap_handler
  j .

##############################
# RISC-V TOOL CHAIN
#
# Note: make sure to properly configure the tool chain
#   un-comment one set of 32-BIT or 64-BIt, as desired.
#   un-comment one set of WIN or LIN, as desired.
#   un-comment one set of UM-232 or TC or OLIMEX or ... as desired.
#
# Usage:
#   make -f riscv.mk clean
#   make -f riscv.mk [ramload | ramrun | ramdebug]
#   make -f riscv.mk [romload | romrun | romdebug]
#
# 2023-06-22  pds  initial cut
#

#---------- 32-BIT or 64-BIT ? -------------
#
#   use -g option for debugger (gdb) symbols, must be last in list
#   remove -g option to reduce code size and save memory
#
# 64-BIT: set PATH=%PATH%;D:\apps\riscv64-unknown-elf\bin
#         requires $(RVGNU)-ld option -b elf32-littleriscv
#
RVGNU = riscv64-unknown-elf
AOPS = -march=rv32imac -mabi=ilp32
COPS = -march=rv32imac -mabi=ilp32 -Wall -O2 -nostdlib -nostartfiles -ffreestanding -g
LKOPS = -b elf32-littleriscv

# 32-BIT: set PATH=%PATH%;D:\apps\riscv32-unknown-elf\bin
#         doesnt like -march option, for some reason
#
#RVGNU = riscv32-unknown-elf
#AOPS =                 -mabi=ilp32
#COPS =                 -mabi=ilp32 -Wall -O2 -nostdlib -nostartfiles -ffreestanding -g
#LKOPS = 
#-------------------------------------------


#------------- WIN or LIN ? ----------------
# WIN: set PATH=%PATH%;D:\apps\xpack-openocd-0.11.0-5\bin
LDCMD = openocd
DELCMD = del /q

# LIN: export PATH %PATH%:/opt/riscv/xpack-openocd-0.11.0-5/bin
#LDCMD = sudo openocd
#DELCMD = rm -f
#-------------------------------------------


#------- UM232 or TC or OLIMEX ? -----------
# UM232: 
#LD_DESC = {UM232H-B}
#LD_VID_PID = 0x0403 0x6014

# TAGCONNECT: 
#LD_DESC = {C232HD-DDHSP-0}
#LD_VID_PID = 0x0403 0x6014

# OLIMEX: 
LD_DESC = {Olimex OpenOCD JTAG ARM-USB-TINY-H}
LD_VID_PID = 0x15ba 0x002a

# WIRING CONNECTIONS:
# [31:24]=n/a
# [23:16]=ADBUS_VAL<7:0>
# [15:0]=ADBUS_DIR<7:0>
# [15]=/PWREN_LED
# [14]=/PWREN_OUT
# [9]=nSRST (optional)
# [8]=nTRST (optional)
# [3]=TMS
# [2]=TDI (DO, output from FT232H)
# [1]=TDO (DI, input to FT232H)
# [0]=TCK
LD_INIT_OLIMEX = 0x0b08 0x0b1b
LD_INIT_UM232  = 0x3fff 0xfffb
#-------------------------------------------

#-------------------------------------------
#----- raspberry pi adapter driver option --
# see https://github.com/psherman42/riscv-easy-as-pi
#-------------------------------------------
#adapter driver bcm2835gpio
#bcm2835gpio_peripheral_base 0x3f000000  ;# RPi 3B+
#bcm2835gpio_jtag_nums 6 13 26 12
#bcm2835gpio_swd_nums 6 13
#bcm2835gpio_trst_num 5
##bcm2835gpio_srst_num 5
## clk_mhz = sudo cat /sys/devices/system/cpu/0/cpufreq/cpuinfo_cur_freq
## clk_mhz = sudo cat /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_cur_freq
## speed-coeff = 162.448 * clk_mhz
## speed-offset = 0.040 * clk_mhz
## bcm2835gpio_speed_coeffs <speed-coeff> <speed-offset>
#bcm2835gpio_speed_coeffs 97469 24
##bcm2835gpio_speed_coeffs 113714 28
##bcm2835gpio_speed_coeffs 146203 36
##bcm2835gpio_speed_coeffs 194938 48
#------------------------------------------

#
# Assembling and Compiling
#

#----------- define your program here --------------
#
#    one line in OBJECTS for each source file, order critical, and
#    a pair of lines for each file in OBJECTS, in any order
#
PGM = atomic-test

OBJECTS = start.o

start.o : start.s
	$(RVGNU)-as $(AOPS) start.s -o start.o

#
#----------- define your program here --------------


#!!!!! BE VERY CAREFUL IF YOU TOUCH ANYTHING BELOW THIS LINE !!!!!

#
# Linking
#

# NOTE: use objdump -M no-aliases option to show "c." forms in listing output
${PGM}-ram.elf : linker-base.lds linker-layout-ram.lds $(OBJECTS)
	$(RVGNU)-ld $(OBJECTS) -g -T linker-base.lds -T linker-layout-ram.lds -o ${PGM}-ram.elf -Map ${PGM}-ram.map $(LKOPS)
	$(RVGNU)-objdump -D ${PGM}-ram.elf > ${PGM}-ram.lst

${PGM}-rom.elf : linker-base.lds linker-layout-rom.lds $(OBJECTS)
	$(RVGNU)-ld $(OBJECTS) -g -T linker-base.lds -T linker-layout-rom.lds -o ${PGM}-rom.elf -Map ${PGM}-rom.map $(LKOPS)
	$(RVGNU)-objdump -D ${PGM}-rom.elf > ${PGM}-rom.lst

${PGM}-ram.bin : ${PGM}-ram.elf
	$(RVGNU)-objcopy ${PGM}-ram.elf -O ihex ${PGM}-ram.hex
	$(RVGNU)-objcopy ${PGM}-ram.elf -O binary ${PGM}-ram.bin

${PGM}-rom.bin : ${PGM}-rom.elf
	$(RVGNU)-objcopy ${PGM}-rom.elf -O ihex ${PGM}-rom.hex
	$(RVGNU)-objcopy ${PGM}-rom.elf -O binary ${PGM}-rom.bin

#
# Loading, to RAM
#
#                 -c "ftdi layout_init 0x0b08 0x0b1b" \
#                 -c "ftdi layout_init 0x3fff 0xfffb" \

ramload : ${PGM}-ram.bin
	@echo "loading target RAM"
	@$(LDCMD) -c "adapter driver ftdi" \
                  -c "ftdi device_desc ${LD_DESC}" \
                  -c "ftdi vid_pid ${LD_VID_PID}" \
                  -c "ftdi layout_init 0x0b08 0x0b1b" \
                  -f ocd-jtag-riscv.cfg \
                  -c init \
                  -c halt \
                  -c "load_image ${PGM}-ram.bin 0x80000000 bin" \
                  -c "verify_image ${PGM}-ram.bin 0x80000000 bin" \
                  -c shutdown -c exit

ramrun : ${PGM}-ram.bin
	@echo "running target RAM"
	@$(LDCMD) -c "adapter driver ftdi" \
                  -c "ftdi device_desc ${LD_DESC}" \
                  -c "ftdi vid_pid ${LD_VID_PID}" \
                  -c "ftdi layout_init 0x0b08 0x0b1b" \
                  -f ocd-jtag-riscv.cfg \
                  -c init \
                  -c halt \
                  -c "resume 0x80000000" \
                  -c shutdown -c exit

ramdebug : ${PGM}-ram.elf
	@start $(LDCMD) -c "adapter driver ftdi" \
                        -c "ftdi device_desc ${LD_DESC}" \
                        -c "ftdi vid_pid ${LD_VID_PID}" \
                        -c "ftdi layout_init 0x0b08 0x0b1b" \
                        -f ocd-jtag-riscv.cfg \
                        -c "gdb_port 3333" \
                        -c init \
                        -c halt \
                        -c "load_image ${PGM}-ram.bin 0x80000000 bin" \
                        -c "verify_image ${PGM}-ram.bin 0x80000000 bin"
	$(RVGNU)-gdb -q ${PGM}-ram.elf -ex "target extended-remote localhost:3333"

#
# Loading, to ROM
#

romload : ${PGM}-rom.bin
	@echo "loading target ROM"
	@$(LDCMD) -c "adapter driver ftdi" \
                  -c "ftdi device_desc ${LD_DESC}" \
                  -c "ftdi vid_pid ${LD_VID_PID}" \
                  -c "ftdi layout_init 0x0b08 0x0b1b" \
                  -f ocd-jtag-riscv.cfg \
                  -c "gdb_port 3333" \
                  -c "flash bank spi0 fespi 0x20000000 0 0 0 riscv.cpu.0 0x10014000" \
                  -c init \
                  -c halt \
                  -c "flash protect 0 0 4 off" \
                  -c "flash erase_sector 0 0 4" \
                  -c "flash write_bank 0 ${PGM}-rom.bin" \
                  -c "flash verify_bank 0 ${PGM}-rom.bin" \
                  -c "flash protect 0 0 4 on" \
                  -c shutdown -c exit

romrun : ${PGM}-rom.bin
	@echo "running target ROM"
	@$(LDCMD) -c "adapter driver ftdi" \
                  -c "ftdi device_desc ${LD_DESC}" \
                  -c "ftdi vid_pid ${LD_VID_PID}" \
                  -c "ftdi layout_init 0x0b08 0x0b1b" \
                  -f ocd-jtag-riscv.cfg \
                  -c init \
                  -c halt \
                  -c "resume 0x20000000" \
                  -c shutdown -c exit

romdebug : ${PGM}-rom.elf
	@start $(LDCMD) -c "adapter driver ftdi" \
                        -c "ftdi device_desc ${LD_DESC}" \
                        -c "ftdi vid_pid ${LD_VID_PID}" \
                        -c "ftdi layout_init 0x0b08 0x0b1b" \
                        -f ocd-jtag-riscv.cfg \
                        -c "gdb_port 3333" \
                        -c "flash bank spi0 fespi 0x20000000 0 0 0 riscv.cpu.0 0x10014000" \
                        -c init \
                        -c halt \
                        -c "flash protect 0 0 4 off" \
                        -c "flash erase_sector 0 0 4" \
                        -c "flash write_bank 0 ${PGM}-rom.bin" \
                        -c "flash verify_bank 0 ${PGM}-rom.bin" \
                        -c "flash protect 0 0 4 on" \
                        -c "resume 0x20000000" \
	$(RVGNU)-gdb -q ${PGM}-rom.elf -ex "target extended-remote localhost:3333"

#
# housekeeping
#

clean :
	$(DELCMD) *.o
	$(DELCMD) $(PROGRAM)*.elf
	$(DELCMD) $(PROGRAM)*.map
	$(DELCMD) $(PROGRAM)*.lst
	$(DELCMD) $(PROGRAM)*.hex
	$(DELCMD) $(PROGRAM)*.bin


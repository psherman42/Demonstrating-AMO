OUTPUT_ARCH("riscv")

ENTRY( _start )

SECTIONS
{
  .text   : { PROVIDE(_text_start = .);   *(.text*);   PROVIDE(_text_end = .);   }> ram  /* ram or rom */
  . = ALIGN(4);
  .rodata : { PROVIDE(_rodata_start = .); *(.rodata*); PROVIDE(_rodata_end = .); }> ram  /* ram or rom */
  . = ALIGN(4);
  .bss    : { PROVIDE(_bss_start = .);    *(.bss*);    PROVIDE(_bss_end = .);    }> ram  /* ram always */
}

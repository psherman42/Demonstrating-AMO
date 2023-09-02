

/*MEMORY { rom          : ORIGIN = 0x20000000, LENGTH = 0x20000000 } */ /* 512MB off-chip, max */
  MEMORY { rom          : ORIGIN = 0x20000000, LENGTH = 0x1000000  }    /* 16MB off-chip */
  MEMORY { ram (wxa!ri) : ORIGIN = 0x80000000, LENGTH = 0x4000     }	    /* 16KB on-chip */

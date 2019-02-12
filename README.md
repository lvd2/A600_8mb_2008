# A600_8mb_2008
My old A600 memory expansion project, as of 2008, released under GPL v3 license.


Changes made for the release:

 - the whole PCB project was converted to pcad2006 format.

 - PCB design fixed for being like a single PCB, needs manual breaking after manufacturing.

 - gerber files are generated. WARNING: I haven't tested them in production! Use at your own risk.

 - Schematics converted to .pdf file.

 - added .bom file.



# Construction.

The board is kinda 2-floor design to fit nicely over the 68000 CPU.
You need plenty of PLD-10 2.00mm pin headers to raise one (main) part of the board over the another (containing PLCC-68 socket).

The CPLD is standard (yet outdated) EPM3064A in QFP-100 package. Those are probably still available on ebay or aliexpress (as of 2019).

SPX1117 is a standard (?) LM1117-like linear 3.3v regulator.

DRAM is the most obscure components. It is 5v-only DRAM (not SD(!)RAM) found often in old 72pin SIMMs.
I've added some datasheets of fitting chips. The package is SOJ42. From my experience, EDO chips won't work, but I've tested only single type of EDO chips.

There are jumpers to switch modes, you can have 4mb, 8mb or 4+1.5mb (AFAIR) memory configurations.
4mb and 8mb chunks are autoconfiguring.


There are also quartus design project files, along with verilog sources.
Quartus 7.2 should be enough to compile them, which also happens to work nicely under wine.
You can use native linux quartus 11.1+ to program the CPLD via usb-blaster. Don't forget to add the blaster to /etc/udev/rules.d or use programmer under superuser.


# Some (old) "user manual"
http://lvd.nedopc.com/Projects/a600_8mb_2/index.html


onbreak {quit -f}
onerror {quit -f}

vsim  -lib xil_defaultlib bram_instrucciones_opt

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure
view signals

do {bram_instrucciones.udo}

run 1000ns

quit -force

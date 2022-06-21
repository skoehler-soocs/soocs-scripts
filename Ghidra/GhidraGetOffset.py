# Import memory address
file = open('/tmp/memaddr.ghidra', "r")
memvalue = file.read()
file.close()

## Let addr be a valid function address
addr = toAddr(memvalue)
fn = getFunctionContaining(addr)

## Get function start and end address
fnstart = fn.getEntryPoint();
fnend = fn.getBody().getMaxAddress();

## Print function start and end address
print('Function start address: ' + str(fnstart))
print('Function end address: ' + str(fnend))

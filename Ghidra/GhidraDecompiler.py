import ghidra.app.decompiler as decomp

# Import memory address
file = open('/tmp/memaddr.ghidra', "r")
memvalue = file.read()
file.close()

## let addr be a valid function address
addr = toAddr(memvalue)
fn = getFunctionContaining(addr)

## get the decompiler interface
iface = decomp.DecompInterface()

## decompile the function
iface.openProgram(fn.getProgram())
d = iface.decompileFunction(fn, 60, monitor)

## get the C code as string
if not d.decompileCompleted():
    print(d.getErrorMessage())
else:
    code = d.getDecompiledFunction()
    ccode = code.getC()
    print(ccode)

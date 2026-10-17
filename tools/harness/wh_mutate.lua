-- apply one mutant to a file: lua5.1 wh_mutate.lua <file> <from> <to>   (from must occur exactly once)
local fh = assert(io.open(arg[1], "rb"))
local text = fh:read("*a")
fh:close()
local from, to = arg[2], arg[3]
local first = text:find(from, 1, true)
if not first then io.stderr:write("INVALID: text not found\n") os.exit(2) end
if text:find(from, first + 1, true) then io.stderr:write("INVALID: text occurs more than once\n") os.exit(2) end
text = text:sub(1, first - 1) .. to .. text:sub(first + #from)
fh = assert(io.open(arg[1], "wb"))
fh:write(text)
fh:close()

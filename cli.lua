local args = { ... }
local poster = require("poster")
local prints = require("print")

if args[1] == "poster" then
  local data

  if args[2]:sub(1, 7) == "http://" or args[2]:sub(1, 8) == "https://" then
    local h = http.get(args[2])
    data = textutils.unserialiseJSON(h.readAll())
    h.close()
  else
    local h = fs.open(args[2], "r")
    data = textutils.unserialiseJSON(h.readAll())
    h.close()
  end
  
  print(data)

  local pages = {}

  if data.pages then
    pages = data.pages
  else
    pages = { data }
  end

  local copies = tonumber(args[3])

  if not poster.canPrint(copies) then
    return printError("Cannot print")
  end

  poster.beginPrint(pages, copies)
elseif args[1] == "3d" then
  local toPrint

  if args[2]:sub(1, 7) == "http://" or args[2]:sub(1, 8) == "https://" then
    local h = http.get(args[2])
    toPrint = textutils.unserialiseJSON(h.readAll())
    h.close()
  else
    local h = fs.open(args[2], "r")
    toPrint = textutils.unserialiseJSON(h.readAll())
    h.close()
  end

  local copies = tonumber(args[3])

  if not prints.canPrint(toPrint, copies) then
    return printError("Cannot print")
  end

  prints.beginPrint({ toPrint }, copies)
else
  print([[Usage:
- cli poster <file> [count]
- cli poster <url> [count]
- cli 3d <file> [count]
- cli 3d <url> [count]
]])
end

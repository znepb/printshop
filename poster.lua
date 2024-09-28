local data = require("disk.data")
local ail = require("abstractInvLib")(data.barrels)

local printersAvailable = #data.posterPrinters

local function createWorker(pagesAssigned, printerID, idx)
  local printer = peripheral.wrap("poster_printer_" .. tostring(printerID))

  return function()
    local ok, err = pcall(function()
      for i, v in pairs(pagesAssigned) do
        printer.reset()
        printer.blitPalette(v.palette)
        printer.blitPixels(1, 1, v.pixels)
        printer.setLabel(v.label)
        printer.setTooltip(v.tooltip)
        printer.commit(1)

        sleep(1)
        while printer.status() == "busy" do
          sleep(1)
        end

        local ok = false

        repeat
          local wasOk, err = pcall(function()
            local nbt = printer.list()[3].nbt
            ail.pullItems(printer, 3, 1, nil, nbt)
          end)

          ok = wasOk

          if wasOk then break end
          if not wasOk then
            printError("AIL transfer failed:", err)
          end
        until ok
      end
    end)

    if not ok then
      printError("Worker failed! " .. err)
    else
      print("Print complete!")
    end
  end
end

local function beginPrint(pages, copies)
  local slotsRequired = #pages * math.ceil(copies / 64)
  if slotsRequired > ail.size() then return end

  print("Starting print with", #pages, "pages and", copies, "copies")
  print("Consumes", slotsRequired, "slots")
  print(printersAvailable, "printers available")

  -- duplicate pages for copies
  local pagesWithCopies = {}
  for i = 1, copies do
    for i, v in pairs(pages) do
      pagesWithCopies[#pagesWithCopies + 1] = v
    end
  end

  print("Page count:", #pagesWithCopies)

  local workers = {}
  local workersToAssign = math.min(#pagesWithCopies, printersAvailable)
  print("Will asign", workersToAssign, 'workers')

  for i = 1, workersToAssign do
    local printer = data.posterPrinters[i]
    local assign = {}

    for pi, v in pairs(pagesWithCopies) do
      -- if the remainder of page index / workers to assign equals this worker ID
      if pi % workersToAssign == (i - 1) then
        table.insert(assign, v)
      end
    end

    table.insert(workers, createWorker(assign, printer, i))
  end

  parallel.waitForAll(unpack(workers))
end

local function canPrint(totalCount)
  if totalCount > 1024 then return false end

  -- Calculate amount of ink that can be made
  rednet.open("left")
  local inkInStorage = #peripheral.call(data.chests.filledCartridges, "list")
  local _, inkThatCanBeMade = rednet.receive("InkLevels")
  local total = inkInStorage + (inkThatCanBeMade or 0)
  rednet.close()


  print("In storage:", inkInStorage)
  print("Can make:", inkThatCanBeMade)
  print("Total carts:", total)

  local printerCount = #data.posterPrinters
  local allPaperCount = 64
  local allInkCount = 100000
  for i, v in pairs(data.posterPrinters) do
    local paperSlot = peripheral.call("poster_printer_" .. tostring(v), "list")[1]
    allPaperCount = math.min(paperSlot and paperSlot.count or 0, allPaperCount)
    allInkCount = math.min(peripheral.call("poster_printer_" .. tostring(v), "getInkLevel"), allInkCount)
  end

  if total > 32 then
    allInkCount = allInkCount + math.floor(total / 32) * 50000
  end

  print("Min paper available:", allPaperCount)
  print("Minimum ink available:", allInkCount)

  return allPaperCount >= (totalCount / printerCount) and allInkCount >= (totalCount / printerCount) * 5000
end

local function clean()
  for i, v in pairs(data.posterPrinters) do
    local printer = peripheral.wrap("poster_printer_" .. tostring(v))
    local content = printer.list()[3]

    if content then
      ail.pullItems(printer, 3, 1, nil, content.nbt)
    end
  end
end

return {
  beginPrint = beginPrint,
  canPrint = canPrint
}
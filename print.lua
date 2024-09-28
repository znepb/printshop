local data = require("disk.data")
local utils = require("disk.utils")
local ail = require("abstractInvLib")(data.barrels)

local printersAvailable = #data.printers

local function createShapes(onShapes, offShapes)
  local function readArray(shapes, state)
    local output = {}

    for i, v in pairs(shapes) do
      local b = v.bounds
      local tint = type(v.tint) == "string" and tonumber(v.tint, "16") or v.tint
      print(type(v.tint), tint)

      table.insert(output, {
        b[1], b[2], b[3],
        b[4], b[5], b[6],
        texture = v.texture,
        state = state,
        tint = tint
      })
    end

    return output
  end

  return {
    unpack(readArray(onShapes, true)),
    unpack(readArray(offShapes, false))
  }
end

local function createWorker(printsAssigned, printerID, idx)
  local printer = peripheral.wrap("3d_printer_" .. tostring(printerID))

  return function()
    local ok, err = pcall(function()
      for i, v in pairs(printsAssigned) do
        local seat = v.seatPos
        
        printer.reset()
        printer.addShapes(createShapes(v.shapesOn, v.shapesOff))
        printer.setLabel(v.label)
        printer.setTooltip(v.tooltip)
        printer.setButtonMode(v.isButton or false)
        printer.setCollidable(v.collideWhenOff, v.collideWhenOn)
        printer.setLightLevel(v.lightLevel or 0)
        printer.setRedstoneLevel(v.redstoneLevel or 0)
        printer.setStateLighting(v.lightWhenOff or true, v.lightWhenOn or true)
        if seat then
          printer.setSeatPos(seat[1], seat[2], seat[3])
        end
        
        if v.seatPos and #v.seatPos == 3 then
          printer.setSeatPos(v.seatPos[1], v.seatPos[2], v.seatPos[3])
        end

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

local function beginPrint(blocks, copies)
  local slotsRequired = #blocks * math.ceil(copies / 64)
  if slotsRequired > ail.size() then return end

  print("Starting print with", #blocks, "blocks and", copies, "copies")
  print("Consumes", slotsRequired, "slots")
  print(printersAvailable, "printers available")

  -- duplicate pages for copies
  local blocksWithCopies = {}
  for i = 1, copies do
    for i, v in pairs(blocks) do
      blocksWithCopies[#blocksWithCopies + 1] = v
    end
  end

  print("Block count:", #blocksWithCopies)

  local workers = {}
  local workersToAssign = math.min(#blocksWithCopies, printersAvailable)
  print("Will asign", workersToAssign, 'workers')

  for i = 1, workersToAssign do
    local printer = data.printers[i]
    local assign = {}

    for pi, v in pairs(blocksWithCopies) do
      -- if the remainder of page index / workers to assign equals this worker ID
      if pi % workersToAssign == (i - 1) then
        table.insert(assign, v)
      end
    end

    table.insert(workers, createWorker(assign, printer, i))
  end

  parallel.waitForAll(unpack(workers))
end

local function canPrint(file, totalCount)
  if totalCount > 512 then return false end

  local printCost = utils.calculate3DPrintCost({
    unpack(file.shapesOn), unpack(file.shapesOff)
  }, file.redstoneLevel or 0, (not file.collideWhenOn) or (not file.collideWhenOff))

  print("Print chamelium cost:", printCost)

  -- Calculate amount of ink that can be made
  rednet.open("left")
  local inkInStorage = #peripheral.call(data.chests.filledCartridges, "list")
  local _, inkThatCanBeMade = rednet.receive("InkLevels")
  local total = inkInStorage + (inkThatCanBeMade or 0)
  rednet.close()


  print("In storage:", inkInStorage)
  print("Can make:", inkThatCanBeMade)
  print("Total carts:", total)

  local printerCount = #data.printers
  local leastChameliumCount = 1000000
  local leastInkCount = 100000
  for i, v in pairs(data.printers) do
    local chameliumSlot = peripheral.call("3d_printer_" .. tostring(v), "list")[1]
    local currentChameliumCount = peripheral.call("3d_printer_" .. tostring(v), "getChameliumLevel")
    leastInkCount = math.min(peripheral.call("3d_printer_" .. tostring(v), "getInkLevel"), leastInkCount)

    if chameliumSlot then
      currentChameliumCount = currentChameliumCount + (chameliumSlot.count * 2000)
    end

    leastChameliumCount = math.min(leastChameliumCount, currentChameliumCount)
  end

  if total > 32 then
    leastInkCount = leastInkCount + math.floor(total / 32) * 50000
  end

  print("Least chamelium available:", leastChameliumCount)
  print("Least ink available:", leastInkCount)

  return leastChameliumCount >= (totalCount / printerCount) * printCost and leastInkCount >= (totalCount / printerCount) * 5000
end

return {
  beginPrint = beginPrint,
  canPrint = canPrint
}

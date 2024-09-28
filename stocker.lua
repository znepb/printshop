local data = require("disk.data")

local paper = peripheral.wrap(data.chests.paper)
local chamelium = peripheral.wrap(data.chests.chamelium)


-- Moves paper to printer
local function pushPaper(to)
  local list = paper.list()
  local count = 0

  if to.list()[1] then
    count = to.list()[1].count
  end

  local needed = 64 - count

  for i, v in pairs(list) do
    if v.name == "minecraft:paper" then
      to.pullItems(data.chests.paper, i, needed, 1)
    end
    if needed <= 0 then return end
  end
end

-- Moves chamelium to printer
local function pushChamelium(to)
  local list = chamelium.list()
  local count = 0

  if to.list()[1] then
    count = to.list()[1].count
  end

  local needed = 64 - count

  for i, v in pairs(list) do
    if v.name == "sc-peripherals:chamelium" then
      to.pullItems(data.chests.chamelium, i, needed, 1)
    end
    if needed <= 0 then return end
  end
end

-- Move ink
local function moveInk(device)
  local list = device.list()

  -- no need to do anything if a full cartridge is already there
  if list[2] and list[2].name == "sc-peripherals:ink_cartridge" then return end

  -- move empty cartridge to storage
  if list[2] then
    device.pushItems(data.chests.emptyCartridges, 2)
  end

  -- get a new one
  local filledList = peripheral.call(data.chests.filledCartridges, "list")

  if filledList == 0 then
    print("Not enough ink!")
  end

  for i, v in pairs(filledList) do
    device.pullItems(data.chests.filledCartridges, i)
  end

  sleep()
  device.pushItems(data.chests.emptyCartridges, 2)
end

local function fill()
  for i, v in pairs(data.posterPrinters) do
    print("Checking poster printer", v)
    local printer = peripheral.wrap("poster_printer_" .. tostring(v))
    local list = printer.list()

    -- Fill Paper
    if list[1] == nil or list[1].count < 32 then
      pushPaper(printer)
    end

    -- Fill Ink
    if printer.getInkLevel() < 60000 then
      moveInk(printer)
    end
  end

  for i, v in pairs(data.printers) do
    print("Checking 3d printer", v)
    local printer = peripheral.wrap("3d_printer_" .. tostring(v))
    local list = printer.list()

    -- Fill Chamelium
    if list[1] == nil or list[1].count < 32 then
      pushChamelium(printer)
    end

    -- Fill Ink
    if printer.getInkLevel() < 60000 then
      moveInk(printer)
    end
  end
end

while true do
  fill()
  sleep(30)
end

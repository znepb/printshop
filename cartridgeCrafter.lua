local data = require(".disk.data")

local inkEnder = peripheral.wrap(data.chests.dyes)
local this = peripheral.call("left", "getNameLocal")
local slotMap = { 1, 2, 3, 5, 6, 7, 9, 10, 11 }

-- Refills ink levels
local function checkInk()
  local list = inkEnder.list()
  for i = 1, 4 do
    if turtle.getItemCount(slotMap[i + 1]) < 32 and list[i] then
      local moved = inkEnder.pushItems(this, i, 64, slotMap[i + 1])
      print("Moved", moved, list[i].name, "slot", i)
    end
  end

  local level = math.min(
    turtle.getItemCount(2),
    turtle.getItemCount(3),
    turtle.getItemCount(5),
    turtle.getItemCount(6)
  )

  return level, table.concat(
      {
        turtle.getItemCount(2),
        turtle.getItemCount(3),
        turtle.getItemCount(5),
        turtle.getItemCount(6)
      }, ", "
    )
end

local function checkCrafts()
  local inkLevel, levels = checkInk()
  print("Ink level:", inkLevel)
  if inkLevel < 1 then return end

  turtle.select(1)
  while turtle.suckUp() do
    peripheral.call(
      "back",
      "setSignText",
      "Cartridge Filler",
      tostring(os.getComputerID()) .. " / " .. this:gsub("turtle_", ""),
      "Crafting",
      levels .. " (" .. tostring(inkLevel) .. ")"
    )
    turtle.craft()
    turtle.dropDown()

    inkLevel = inkLevel - 1
    if inkLevel <= 0 then break end
  end

  peripheral.call(
    "back",
    "setSignText",
    "Cartridge Filler",
    tostring(os.getComputerID()) .. " / " .. this:gsub("turtle_", ""),
    "Idle",
    levels .. " (" .. tostring(inkLevel) .. ")"
  )

  return inkLevel
end

rednet.open("left")

while true do
  checkCrafts()

  local inkLevel = checkInk()
  rednet.broadcast(inkLevel, "InkLevels")

  sleep(1)
end
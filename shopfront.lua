local bigfont = require("bigfont")
local checks = require("checks")
local utils = require("disk.utils")

local m = peripheral.wrap("top")
m.setTextScale(0.5)

local state = {
  page = "home"
}

local chameliumMax = 2.348

local rates = {
  flatFee = 0.01,
  perChamelium = 0.05
}

local function findMaxCopies(uniquePages)
  return math.floor(864 / uniquePages) * 64
end

local function drawHeader()
  m.setBackgroundColor(colors.gray)
  m.clear()
  m.setTextColor(colors.blue)
  bigfont.writeOn(m, 1, "Snowflake", 2, 2)
  m.setTextColor(colors.white)
  m.setCursorPos(2, 5)
  m.write("Printing Services")
end

local pageFunctions = {
  home = function()
    drawHeader()

    m.setCursorPos(2, 7)
    m.write("Welcome to Snowflake Printing Services! Here, you can")
    m.setCursorPos(2, 8)
    m.write("get bulk 3D and 2D prints at reasonable prices.")

    m.setCursorPos(2, 10)
    m.write("-- Rates -- ")
    m.setCursorPos(2, 11)
    m.write("Posters (1 stack) - K" .. tostring(math.ceil(rates.flatFee * 64)))
    m.setCursorPos(2, 12)
    m.write("3D prints (1 stack) - K1 to K" .. tostring(math.ceil(rates.perChamelium * chameliumMax * 64)) .. "*")

    m.setCursorPos(2, 15)
    m.write("Use \\print <url> [count] to get started!")
    --m.setCursorPos(2, 16)
    --m.write("started!")

    m.setTextColor(colors.lightGray)
    m.setCursorPos(2, 13)
    m.write("Large order rates available for >32 stacks (2048 items)")
    m.setCursorPos(2, 22)
    m.write("* Depends on print volume, collision, and redstone")
    m.setCursorPos(2, 23)
    m.write("level. Use \\print price <url> [count] to find price.")
  end,
  verify = function()
    drawHeader()

    m.setCursorPos(2, 7)
    m.write("Verifying file...")
  end,
  prep = function()
    drawHeader()
    local y = 11

    m.setCursorPos(2, 7)
    m.write("Type: " .. state.type)
    m.setCursorPos(2, 8)
    m.write("Price per copy (per stack): K" .. tostring(state.costEach) .. " (K" .. tostring(state.costEach * 64) .. ")")
    if state.unique > 1 or state.type:sub(1, 3) == "2dj" then
      y = y + 1
      m.setCursorPos(2, 9)
      m.write("Pages: " .. state.unique)
    end

    state.incrementY = y

    local copiesStr = tostring(state.copies)
    if #copiesStr == 1 then copiesStr = "  " .. copiesStr .. " "
    elseif #copiesStr == 2 then copiesStr = " " .. copiesStr .. " "
    elseif #copiesStr == 3 then copiesStr = " " .. copiesStr
    end

    m.setCursorPos(2, y - 1)
    m.write("Select copies:")

    m.setCursorPos(2, y)
    m.blit((" "):rep(20), ("f"):rep(20), "eeee666ffffff555dddd")
    m.setCursorPos(2, y + 1)
    m.blit(" --  -  " .. copiesStr .. "  +  ++ ", ("0"):rep(20), "eeee666ffffff555dddd")
    m.setCursorPos(2, y + 2)
    m.blit((" "):rep(20), ("f"):rep(20), "eeee666ffffff555dddd")

    m.setCursorPos(2, y + 4)
    m.write("Total items: " .. tostring(state.copies * state.unique))

    local printCost = state.copies * state.costEach
    m.setCursorPos(2, y + 5)
    m.write("Price: K" .. tostring(printCost))

    local printTime = math.ceil((state.copies * state.unique) / 32) * 12
    local printTimeStr = tostring(printTime) .. "s"

    if printTime > 60 then
      printTimeStr = math.floor(printTime / 60) .. "m"

      if printTime % 60 ~= 0 then
        printTimeStr = printTimeStr .. math.floor(printTime % 60) .. "s"
      end
    end

    m.setCursorPos(2, y + 6)
    m.write("Estimated time to print: " .. printTimeStr)

    if state.copies * state.unique > 1024 then
      m.setTextColor(colors.red)
      m.setCursorPos(2, 23)
      m.write("Maximum 1024 items")
    else
      m.setTextColor(colors.white)
      m.setCursorPos(2, 23)
      m.write("Pay K" .. tostring(printCost) .. " to prints.kst to get started.")
    end

    m.setCursorPos(49, 23)
    m.blit(" Cancel ", "00000000", "88888888")
  end
}

local function render()
  pageFunctions[state.page]()
end

local function reset()
  state.page = "home"
  render()
end

local function tell(who, what)
  chatbox.tell(who, what, "&bSnowflake &rPrinting Services", nil, "format")
end

local function loadFileFromURL(user, path)
  local itemType, file, initialCount = nil, nil, 1

  local ok, err = pcall(function()
    local f = http.get(path)
    local content = f.readAll()
    f.close()

    if #content >= 4 * 1024 * 1024 then
      tell(user, "&cFile is too large. Maximum size is 4 MiB please.")
      return
    end

    data = textutils.unserialiseJSON(content)
    if type(data) ~= "table" then
      tell(user, "&cBad file.")
      return
    end

    if data.pixels then
      local ok, err = checks.check2DJ(data)
      if not ok then
        tell(user, "&c" .. err)
        return
      end

      itemType = "2dj"
    elseif data.pages then
      local ok, err = checks.check2DJA(data)
      if not ok then
        tell(user, "&c" .. err)
        return
      end

      itemType = "2dja"
      initialCount = #data.pages
    elseif data.shapesOff then
      local ok, err = checks.check3DJ(data)
      if not ok then
        tell(user, "&c" .. err)
        return
      end

      itemType = "3dj"
    end
    file = data
  end)

  if not ok then
    printError(err)
    tell(user, "&cAn unknown error occured. Please check your URL.")
    return
  end

  return itemType, file, initialCount
end

local function calculatePricePerCopy(file)
  local costEach = rates.flatFee

  if itemType == "3dj" then
    for i, v in pairs(file) do
      print(i, v)
    end

    costEach = ((utils.calculate3DPrintCost({
      unpack(file.shapesOn), unpack(file.shapesOff)
    }, file.redstoneLevel or 0, (not file.collideWhenOn) or (not file.collideWhenOff))) / 2000) * rates.perChamelium
  elseif itemType == "2dja" then
    costEach = costEach * #file.pages
  end

  return math.ceil(costEach * 100) / 100
end

render()

while true do
  local e = { os.pullEvent() }

  if e[1] == "command" and e[3] == "print" then
    local _, user, _, args, data = unpack(e)

    if args[1] == nil then
      tell(user, "Come check out the Snowflake Print Store at 658, 73, 79!")
    elseif args[1] == "price" then
    print(args[2])
      local itemType, file, initialCount = loadFileFromURL(user, args[2])

      if not itemType then
        reset()
      else
        local costEach = calculatePricePerCopy(file)
        tell(user, "It would cost K" .. costEach .. " each to print this.")
      end
    elseif args[1]:sub(1, 7) == "http://" or args[1]:sub(1, 8) == "https://" then
      if state.page == "home" then
        state.page = "verify"
        render()

        local itemType, file, initialCount = loadFileFromURL(user, args[1])

        if not itemType then
          reset()
        else
          local costEach = calculatePricePerCopy(file)

          state = {
            page = "prep",
            type = itemType,
            unique = initialCount,
            costEach = math.max(costEach, rates.flatFee),
            copies = 1,
            file = file,
            expireTimer = os.startTimer(30)
          }

          render()
        end
      else
        tell(user, "&cAnother session is already active. Please try again later.")
      end
    end
  elseif e[1] == "monitor_touch" and e[2] == "top" then
    local x, y = e[3], e[4]
    if state.page == "prep" then
      if y >= state.incrementY and y <= state.incrementY + 2 then
        local max = findMaxCopies(state.unique)
        state.expireTimer = os.startTimer(120)

        if x >= 2 and x <= 5 then
          state.copies = math.max(1, state.copies - 10)
        elseif x >= 6 and x <= 9 then
          state.copies = math.max(1, state.copies - 1)
        elseif x >= 15 and x <= 17 then
          state.copies = math.min(state.copies + 1, max)
        elseif x >= 18 and x <= 21 then
          state.copies = math.min(state.copies + 10, max)
        end

        state.copies = math.min(state.copies, 9999)

        print("Would print", state.copies * state.unique)

        render()
      elseif y == 23 and x >= 49 then
        reset()
      end
    end
  elseif e[1] == "timer" then
    if e[2] == state.expireTimer then
      reset()
    end
  end
end
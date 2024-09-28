local function calculate3DPrintCost(allShapes, redstoneLevel, collosionDisabled)
  local volume = 0

  for i, v in pairs(allShapes) do
    local minX, minY, minZ = v.bounds[1], v.bounds[2], v.bounds[3]
    local maxX, maxY, maxZ = v.bounds[4], v.bounds[5], v.bounds[6]
    local w, h, d = maxX - minX, maxY - minY, maxZ - minZ
    local v = w * h * d
    volume = volume + v
  end

  local cost = math.max(volume / 2, 1)
  if redstoneLevel > 1 and redstoneLevel < 15 then
    cost = cost + 300
  end

  if collosionDisabled then
    cost = cost * 2
  end

  return math.ceil(cost)
end

return {
  calculate3DPrintCost = calculate3DPrintCost
}
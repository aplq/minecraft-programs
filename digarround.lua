local component = require("component")
local computer = require("computer")
local robot = require("robot")
local shell = require("shell")
local sides = require("sides")
local gen = component.generator

if not component.isAvailable("robot") then
  io.stderr:write("can only run on robots")
  return
end

local args, options = shell.parse(...)
if #args < 3 then
  io.write("Usage: dig [-s] <starting heirth> <mineing heigth> <starting radius>\n")
  io.write(" -s: shutdown when done.")
  return
end

local sheigth = tonumber(args[1])
if not sheigth then
  io.stderr:write("invalid starting heigth")
  return
end
local mheigth = tonumber(args[2])
if not mheigth then
  io.stderr:write("invalid mining heigth")
  return
end
local srad = tonumber(args[3])
if not srad then
  io.stderr:write("invalid starting radius")
  return
end

local r = component.robot
local x, y, z, f = 0, 0, 0, 0
local dropping = false -- avoid recursing into drop()
local delta = {[0] = function() x = x + 1 end, [1] = function() y = y + 1 end,
               [2] = function() x = x - 1 end, [3] = function() y = y - 1 end}

local function turnRight()
  robot.turnRight()
  f = (f + 1) % 4
end

local function turnLeft()
  robot.turnLeft()
  f = (f - 1) % 4
end

local function turnTowards(side)
  if f == side - 1 then
    turnRight()
  else
    while f ~= side do
      turnLeft()
    end
  end
end

local checkedDrop -- forward declaration

local function clearBlock(side, cannotRetry)
  while r.suck(side) do
    checkedDrop()
  end
  local result, reason = r.swing(side)
  if result then
    checkedDrop()
  else
    local _, what = r.detect(side)
    if cannotRetry and what ~= "air" and what ~= "entity" then
      return false
    end
  end
  return true
end

local function tryMove(side)
  side = side or sides.forward
  local tries = 10
  while not r.move(side) do
    tries = tries - 1
    if not clearBlock(side, tries < 1) then
      return false
    end
  end
  if side == sides.down then
    z = z + 1
  elseif side == sides.up then
    z = z - 1
  else
    delta[f]()
  end
  return true
end

local function moveTo(tx, ty, tz, backwards)
  local axes = {
    function()
      if y > ty then
        turnTowards(3)
        repeat tryMove() until y == ty
      elseif y < ty then
        turnTowards(1)
        repeat tryMove() until y == ty
      end
    end,
    function()
      if x > tx then
        turnTowards(2)
        repeat tryMove() until x == tx
      elseif x < tx then
        turnTowards(0)
        repeat tryMove() until x == tx
      end
    end,
    function()
      while z > tz do
        tryMove(sides.up)
      end
      while z < tz do
        tryMove(sides.down)
      end
    end
  }
  if backwards then
    for axis = 3, 1, -1 do
      axes[axis]()
    end
  else
    for axis = 1, 3 do
      axes[axis]()
    end
  end
end

function checkedDrop(force)
  local empty = 0
  for slot = 1, 16 do
    if robot.count(slot) == 0 then
      empty = empty + 1
    end
  end
  if not dropping and empty == 0 or force and empty < 16 then
    local ox, oy, oz, of = x, y, z, f
    dropping = true
    moveTo(0, 0, 0)
    turnTowards(2)

    for slot = 1, 16 do
      if robot.count(slot) > 0 then
        robot.select(slot)
        local wait = 1
        repeat
          if not robot.drop() then
            os.sleep(wait)
            wait = math.min(10, wait + 1)
          end
        until robot.count(slot) == 0
      end
    end
    robot.select(1)

    dropping = false
    moveTo(ox, oy, oz, true)
    turnTowards(of)
  end
end

local function genPower():
  for a=1,16,1
    do
    robot.select(a)
    gen.insert()
  end
end

local function mineCells(numberToMine)
  for a=1,3*numberToMine,1
    do
    if not tryMove() then
      return false
    end
  end
  clearBlock(sides.front, true)
  return true
end

local function digLayer()
  for c=(sheight-mheight),0,-1 do
    tryMove(sides.down)
  end
  if (srad%2)==0 then
    mineCells(srad/2)
    turnRight()
    mineCells(srad/2)
    turnRight()
  else
    turnLeft()
    mineCells((srad-1)/2)
    turnLeft()
    mineCells(srad/2)
    turnRight()
    turnRight()
  end
  size=srad
  repeat
    io.write("current radius: "+tostring(size))
    io.write("Level: "+tostring(mheight))
    if not mineCells(size) then
      return false
    end
    turnRight()
    if not mineCells(size) then
      return false
    end
    size=size+1
    turnRight()
    genPower()
  until(false)
end

digLayer()
moveTo(0, 0, 0)
turnTowards(0)
checkedDrop(true)

if options.s then
  computer.shutdown()
end

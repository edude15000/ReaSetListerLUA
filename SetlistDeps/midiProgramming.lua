local midiProgramming = {}

local lightsDriverName = 'Apple Inc. - IAC Driver - Bus 1'
local lightsDriverDeviceNumber = nil

local wingDriverName = 'BEHRINGER - WING - Port 1'
local wing2DriverName = 'BEHRINGER - WING - Port 2'
local wingDriverDeviceNumber = nil

local currentTempo = 0

local reaper = {}

function midiProgramming.init(r)
    reaper = r
    SetDriverMidi()
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,90,math.random(0,127)))
end

function midiProgramming.midiStuff()
    local midi_in = GetMIDIInput()
    for k, midi_table in ipairs(midi_in) do
        local type, ch, data1, data2 = UnpackMIDIMessage(midi_table.msg)
        if ch == 11 and data1 == 12 then
          midiProgramming.sendLightSignal(data2)
        end
    end
    
    if (wingDriverDeviceNumber ~= nil) then
      local tempo = reaper.Master_GetTempo()
      if (tempo ~= currentTempo) then
        local ms = math.ceil(60000 / tempo)
        reaper.SendMIDIMessageToHardware(wingDriverDeviceNumber, PackMIDIMessage(11,11,15,math.floor(((ms - 1) * 127) / (3000 - 1)))) --first delay FX tap tempo
        reaper.SendMIDIMessageToHardware(wingDriverDeviceNumber, PackMIDIMessage(11,12,15,math.floor(((ms - 60) * 127) / (650 - 60)))) --second delay FX tap tempo
        currentTempo = tempo
      end
    end
end

function midiProgramming.sendLightSignal(code)
  -- first always 9, second always 1, third is channel connected to qlc control, fourth is velocity
  local redPar1 = 110
  local greenPar1 = 111
  local bluePar1 = 112
  local parShutter1 = 113 -- 64+ = strobe, solid brightness = 63
  
  local derbyRotation1 = 114
  local derbyStrobe1 = 115 -- 0 = solid, 7-119 = strobe, 120+ = sound
  local derbyColors1 = 122
  
  local redPar2 = 90
  local greenPar2 = 91
  local bluePar2 = 92
  local parShutter2 = 93
  
  local derbyRotation2 = 94
  local derbyStrobe2 = 95
  local derbyColors2 = 96
  
  local laserColor = 116 -- 20+ is not blackout
  local laserStrobe = 117 -- 0 = solid, 7-119 = strobe, 120+ = sound
  local laserRotation = 118
  
  local strobePattern = 119
  local strobeUvBrightness = 120
  local strobeSpeed = 121
  
  local floorLeft = 123
  local floorMiddle = 124
  local floorRight = 125
  
  local par1RedAmount = 1
  local par1GreenAmount = 1
  local par1BlueAmount = 1
  local flashSpeedPars1 = math.random(64,119)
  
  local par2RedAmount = 1
  local par2GreenAmount = 1
  local par2BlueAmount = 1
  local flashSpeedPars2 = math.random(64,119)
  
  local derbyColors1Amount = 1
  local derbyRotation1Amount = math.random(0,127)
  local flashSpeedDerbys1 = math.random(7,119)
  
  local derbyColors2Amount = 1
  local derbyRotation2Amount = math.random(0,127)
  local flashSpeedDerbys2 = math.random(7,119)
  
  local floorLightsBrightness = 127
  local flashSpeedStrobes = math.random(0,127)
  local flashSpeedLasers = math.random(7,119)
  
  local randomColorValue1 = math.random(0,12)
  local randomColorValue2 = math.random(0,12)
  local randomColorValue3 = math.random(0,12)
  local randomColorValue4 = math.random(0,12)
  
  local sameAmountChance = math.random(0,2)
  if (sameAmountChance == 0) then -- all 4 different (1111)
    par1RedAmount, par1GreenAmount, par1BlueAmount = SetParColorById(randomColorValue1)
    par2RedAmount, par2GreenAmount, par2BlueAmount = SetParColorById(randomColorValue2)
    derbyColors1Amount = SetDerbyColorById(randomColorValue3)
    derbyColors2Amount = SetDerbyColorById(randomColorValue4)
  elseif (sameAmountChance == 1) then -- inside same, outside same
    par1RedAmount, par1GreenAmount, par1BlueAmount = SetParColorById(randomColorValue1)
    derbyColors1Amount = SetDerbyColorById(randomColorValue2)
    derbyColors2Amount = derbyColors1Amount
    par2RedAmount = par1RedAmount
    par2GreenAmount = par1GreenAmount
    par2BlueAmount = par1BlueAmount
  elseif (sameAmountChance == 2) then -- all same (0000)
    par1RedAmount, par1GreenAmount, par1BlueAmount = SetParColorById(randomColorValue1)
    derbyColors1Amount = SetDerbyColorById(randomColorValue1)
    derbyColors2Amount = derbyColors1Amount
    par2RedAmount = par1RedAmount
    par2GreenAmount = par1GreenAmount
    par2BlueAmount = par1BlueAmount
  end
  
  if code == 0 then -- chorus solid
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,redPar1,par1RedAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,greenPar1,par1GreenAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,bluePar1,par1BlueAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,parShutter1,63))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,redPar2,par2RedAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,greenPar2,par2GreenAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,bluePar2,par2BlueAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,parShutter2,63))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyRotation1,derbyRotation1Amount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyStrobe1,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyColors1,derbyColors1Amount))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyRotation2,derbyRotation2Amount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyStrobe2,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyColors2,derbyColors2Amount))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserColor,math.random(20,127)))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserStrobe,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserRotation,math.random(0,127)))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobePattern,math.random(0,104)))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobeUvBrightness,255))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobeSpeed,0))
  elseif code == 1 then -- chorus flashing
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,redPar1,par1RedAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,greenPar1,par1GreenAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,bluePar1,par1BlueAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,parShutter1,flashSpeedPars1))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,redPar2,par2RedAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,greenPar2,par2GreenAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,bluePar2,par2BlueAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,parShutter2,flashSpeedPars2))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyRotation1,derbyRotation1Amount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyStrobe1,flashSpeedDerbys1))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyColors1,derbyColors1Amount))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyRotation2,derbyRotation2Amount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyStrobe2,flashSpeedDerbys2))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyColors2,derbyColors2Amount))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserColor,math.random(20,127)))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserStrobe,flashSpeedLasers))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserRotation,math.random(0,127)))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobePattern,math.random(0,104)))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobeUvBrightness,255))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobeSpeed,flashSpeedStrobes))
  elseif code == 2 then -- verse solid
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,redPar1,par1RedAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,greenPar1,par1GreenAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,bluePar1,par1BlueAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,parShutter1,63))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,redPar2,par2RedAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,greenPar2,par2GreenAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,bluePar2,par2BlueAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,parShutter2,63))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyRotation1,derbyRotation1Amount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyStrobe1,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyColors1,derbyColors1Amount))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyRotation2,derbyRotation2Amount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyStrobe2,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyColors2,derbyColors2Amount))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserColor,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserStrobe,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserRotation,0))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobePattern,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobeUvBrightness,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobeSpeed,0))
  elseif code == 3 then -- verse flashing
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,redPar1,par1RedAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,greenPar1,par1GreenAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,bluePar1,par1BlueAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,parShutter1,flashSpeedPars1))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,redPar2,par2RedAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,greenPar2,par2GreenAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,bluePar2,par2BlueAmount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,parShutter2,flashSpeedPars2))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyRotation1,derbyRotation1Amount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyStrobe1,flashSpeedDerbys1))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyColors1,derbyColors1Amount))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyRotation2,derbyRotation2Amount))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyStrobe2,flashSpeedDerbys2))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyColors2,derbyColors2Amount))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserColor,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserStrobe,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserRotation,0))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobePattern,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobeUvBrightness,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobeSpeed,0))
  elseif code == 4 then -- white solid
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,redPar1,127))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,greenPar1,127))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,bluePar1,127))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,parShutter1,63))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,redPar2,127))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,greenPar2,127))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,bluePar2,127))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,parShutter2,63))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyRotation1,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyStrobe1,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyColors1,98))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyRotation2,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyStrobe2,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyColors2,98))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserColor,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserStrobe,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserRotation,0))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobePattern,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobeUvBrightness,255))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobeSpeed,0))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,floorLeft,floorLightsBrightness))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,floorMiddle,floorLightsBrightness))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,floorRight,floorLightsBrightness))
  elseif code == 5 then -- clear all
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,redPar1,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,greenPar1,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,bluePar1,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,parShutter1,0))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,redPar2,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,greenPar2,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,bluePar2,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,parShutter2,0))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyRotation1,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyStrobe1,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyColors1,0))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyRotation2,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyStrobe2,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,derbyColors2,0))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserColor,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserStrobe,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,laserRotation,0))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobePattern,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobeUvBrightness,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,strobeSpeed,0))
    
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,floorLeft,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,floorMiddle,0))
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,floorRight,0))
  elseif code == 6 then -- Floor Left On
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,floorLeft,floorLightsBrightness))
  elseif code == 7 then -- Floor Middle On
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,floorMiddle,floorLightsBrightness))
  elseif code == 8 then -- Floor Right On
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,floorRight,floorLightsBrightness))
  elseif code == 9 then -- Floor Left Off
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,floorLeft,0))
  elseif code == 10 then -- Floor Middle Off
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,floorMiddle,0))
  elseif code == 11 then -- Floor Right Off
    reaper.SendMIDIMessageToHardware(lightsDriverDeviceNumber, PackMIDIMessage(9,1,floorRight,0))
  end
  
end

function SetParColorById(colorId)
  if (colorId == 0) then -- white 127, 127, 127 / 180
    return 127, 127, 127
  elseif (colorId == 1) then -- red 127, 0, 0 / 13
    return 127, 0, 0
  elseif (colorId == 2) then -- blue 0, 0, 127 / 36
    return 0, 0, 127
  elseif (colorId == 3) then -- green 0, 127, 0 / 26
    return 0, 127, 0
  elseif (colorId == 4) then -- yellow 127, 127, 0 / 52
    return 127, 127, 0
  elseif (colorId == 5) then -- violet 127, 0, 127 / 64
    return 127, 0, 127
  elseif (colorId == 6) then -- cyan 0, 127, 127 / 78
    return 0, 127, 127
  elseif (colorId == 7) then -- mid green 63, 127, 0 / 52
    return 63, 127, 0
  elseif (colorId == 8) then -- mid dark blue 0, 127, 63
    return 0, 127, 63
  elseif (colorId == 9) then -- mid purple 63, 0, 127 / 64
    return 63, 0, 127
  elseif (colorId == 10) then -- mid cyan 0, 63, 127 / 78
    return 0, 63, 127
  elseif (colorId == 11) then -- orange 127, 63, 0 / 52
    return 127, 63, 0
  elseif (colorId == 12) then -- mid pink 127, 0, 63 / 64
    return 127, 0, 63
  end
end

function SetDerbyColorById(colorId)
  if (math.random(0,4) == 4) then
    return 127
  elseif (colorId == 0) then -- white 127, 127, 127 / 180
    return 180
  elseif (colorId == 1) then -- red 127, 0, 0 / 13
    return 13
  elseif (colorId == 2) then -- blue 0, 0, 127 / 36
    return 36
  elseif (colorId == 3) then -- green 0, 127, 0 / 26
    return 26
  elseif (colorId == 4) then -- yellow 127, 127, 0 / 52
    return 52
  elseif (colorId == 5) then -- violet 127, 0, 127 / 64
    return 64
  elseif (colorId == 6) then -- cyan 0, 127, 127 / 78
    return 78
  elseif (colorId == 7) then -- mid green 63, 127, 0 / 52
    return 52
  elseif (colorId == 8) then -- mid dark blue 0, 127, 63
    return 63
  elseif (colorId == 9) then -- mid purple 63, 0, 127 / 64
    return 64
  elseif (colorId == 10) then -- mid cyan 0, 63, 127 / 78
    return 78
  elseif (colorId == 11) then -- orange 127, 63, 0 / 52
    return 52
  elseif (colorId == 12) then -- mid pink 127, 0, 63 / 64
    return 64
  end
end

---Pack a midi message in a string form. Each character is a midi byte. Can receive as many data bytes needed. Just join midi_type and midi_ch in the status bytes and thow it in PackMessage. 
---@param midi_type number midi message type: Note Off = 8; Note On = 9; Aftertouch = 10; CC = 11; Program Change = 12; Channel Pressure = 13; Pitch Vend = 14; text = 15.
---@param midi_ch number midi ch 1-16 (1 based.)
---@param ... number sequence of data bytes can be number (will be converted to string(a character with the equivalent byte)) or can be a string that will be added to the message (useful for midi text where each byte is a character).
function PackMIDIMessage(midi_type,midi_ch,...)
    local midi_ch = midi_ch - 1 -- make it 0 based
    local status_byte = (midi_type<<4)+midi_ch -- where is your bitwise operation god now?
    return PackMessage(status_byte,...)
end

---Receives numbers(0-255). or strings. and return them in a string as bytes
---@param ... number
---@return strings
function PackMessage(...)
    local msg = ''
    for i, v in ipairs( { ... } ) do
        local new_val
        if type(v) == 'number' then 
            new_val = string.char(v) 
        elseif type(v) == 'string' then -- In case it is a string (useful for midi text where each byte is a character)
            new_val = v
        elseif not v then -- in case some of the messages is nil. No problem! This is useful as PackMIDITable will send .val2 and .text. not all midi have val2 and not all midi have .text
            new_val = ''
        end
        msg = msg..new_val
    end
    return msg
end

---Get MIDI input. Use for get MIDI between defer loops.
---@param midi_last_retval number need to store the last MIDI retval from MIDI_GetRecentInputEvent. Start the script with `MIDILastRetval = reaper.MIDI_GetRecentInputEvent(0)` and feed it here. Optionally pass nill here and it will create a global variable called "MIDILastRetval_Hidden" and manage that alone. 
---@return table midi_table midi table with all the midi values. each index have another table = {msg = midi message, ts = time, device = midi device idx}
---@return number midi_last_retval updated reval number.
function GetMIDIInput(last_retval)
    local idx = 0
    local first_retval
    local midi_table = {}
    local is_save_hidden_retval -- if not last_retval then it will save it in a global variable MIDILastRetval_Hidden and use it later

    -- if last_retval == true then it will manage the retval alone.
    if not last_retval then
        if not MIDILastRetval_Hidden then
            MIDILastRetval_Hidden = reaper.MIDI_GetRecentInputEvent(0)
            last_retval = MIDILastRetval_Hidden
        else 
            last_retval = MIDILastRetval_Hidden
        end
        is_save_hidden_retval = true
    end
    -- Get all recent inputs
    while true do
        local retval, msg, ts, device_idx = reaper.MIDI_GetRecentInputEvent(idx)
        if idx == 0 then
            first_retval = retval
        end

        if retval == 0 or retval == last_retval then
            last_retval = first_retval
            if is_save_hidden_retval then 
                MIDILastRetval_Hidden = first_retval
            end
            return midi_table, last_retval
        end
        midi_table[#midi_table+1] = {msg = msg, ts = ts, device = device_idx}
        
        idx = idx + 1
    end
end

---Unpack a packed string MIDI message in different values
---@param msg string midi as packed string
---@return number msg_type midi message type: Note Off = 8; Note On = 9; Aftertouch = 10; CC = 11; Program Change = 12; Channel Pressure = 13; Pitch Vend = 14; text = 15. 
---@return number msg_ch midi message channel 1 based (1-16)
---@return number data2 databyte1 -- like note pitch, cc num
---@return number data3 databyte2 -- like note velocity, cc val. Some midi messages dont have databyte2 and this will return nill. For getting the value of the pitchbend do databyte1 + databyte2
---@return string text if message is a text return the text
---@return table allbytes all bytes in a table in order, starting with statusbyte. usefull for longer midi messages like text
function UnpackMIDIMessage(msg)
    local msg_type = msg:byte(1)>>4
    local msg_ch = (msg:byte(1)&0x0F)+1 --msg:byte(1)&0x0F -- 0x0F = 0000 1111 in binary. this is a bitmask. +1 to be 1 based

    local text
    if msg_type == 15 then
        text = msg:sub(3)
    end

    local val1 = msg:byte(2)
    local val2 = (msg_type ~= 15) and msg:byte(3) -- return nil if is text
    return msg_type,msg_ch,val1,val2,text,msg
end

function SetDriverMidi()
  local deviceNumTotal = reaper.GetNumMIDIOutputs()
  for i=0, deviceNumTotal do
    local retval, nameout = reaper.GetMIDIOutputName(i, lightsDriverName)
    local retval2, nameout2 = reaper.GetMIDIOutputName(i, wingDriverName)
    local retval3, nameout3 = reaper.GetMIDIOutputName(i, wing2DriverName)
    if retval == true and nameout == lightsDriverName then
      lightsDriverDeviceNumber = i
    end
    if retval2 == true and nameout2 == wingDriverName then
      wingDriverDeviceNumber = i
    end
    if retval3 == true and nameout3 == wing2DriverName then
      wingDriverDeviceNumber = i
    end
  end
end

return midiProgramming

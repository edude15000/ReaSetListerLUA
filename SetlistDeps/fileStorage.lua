local fileStorage = {}

local reaper, setlistController = {}, {}

local lastLoadedSetNameFile = 'lastSetName.txt'

function fileStorage.init(r, controller)
  reaper = r
  setlistController = controller
  if setlistController.regions == nil then
    setlistController.regions = {}
  end
  if setlistController.markers == nil then
    setlistController.markers = {}
  end
end

function fileStorage.getDirectory()
  if (GetOs() == "win") then
    return os.getenv( "USERPROFILE" ) .. '\\Documents\\ReaSetlister\\'
  else
    return os.getenv( "HOME" ) .. '/Documents/ReaSetlister/'
  end   
end

function fileStorage.saveSetlist(setListNameEntry)
  if (setlistController.regions ~= nil and setlistController.regions ~= empty and 
      setListNameEntry.value ~= nil and setListNameEntry.value ~= '') then
      
      if (GetOs() == "win") then
         reaper.RecursiveCreateDirectory(fileStorage.getDirectory(), 0)
      else
        os.execute( 'mkdir -p ' .. fileStorage.getDirectory() .. ' 2>/dev/null')
      end   
      
      local func = function() 
        Nt2_write(fileStorage.getDirectory()..setListNameEntry.value..'.csv') 
        SaveLastLoadedFile(setListNameEntry.value..'.csv')
      end
      
      local file = io.open(fileStorage.getDirectory() ..setListNameEntry.value..'.csv', "r")
      if (file ~= nil) then
        file:close()
        confirmationPopup("A file with the name "
          ..setListNameEntry.value..".csv' already exists, do you want to replace it?",
          func)
      else
        func()
      end
  else
    errorPopup('Please type a setlist name and have at least one song in the set!')
  end
  
end

function fileStorage.loadRegionsFromFileCommand(fileName)
  local path = fileStorage.getDirectory()..fileName
  for k in pairs (setlistController.regions) do setlistController.regions[k] = nil end
  local file = io.open(path, "r") 
  for line in io.lines(path) do
    local index, name, start, ending, color, stopAfter, jump = 
      line:match("%s*(.*),%s*(.*),%s*(.*),%s*(.*),%s*(.*),%s*(.*),%s*(.*)")
    setlistController.regions[#setlistController.regions+1] = {Start = tonumber(start), End = tonumber(ending), 
            Name = name, Color = tonumber(color), Index = tonumber(index), 
            StopAfter = stopAfter, Jump = tonumber(jump)}
  end
  
  file:close()
  SaveLastLoadedFile(fileName)
end

function fileStorage.readLastLoadedSet()
  local setName = nil
  local file = io.open(fileStorage.getDirectory()..lastLoadedSetNameFile, "r")
  if file then
      setName = file:read()
      file:close()
  end
  return setName
end

function Nt2_write(path)
    local file = assert(io.open(path, "w"))
    for k, v in pairs(setlistController.regions) do
      if (v["Jump"] == nil) then
        v["Jump"] = 0
      end
      file:write(v["Index"] .. "," .. v["Name"] .. "," .. 
        v["Start"] .. "," .. v["End"] .. "," .. v["Color"] 
        .. "," .. v["StopAfter"] .. "," .. v["Jump"])
      file:write('\n')
    end
    file:close()
end

function GetOs()
    return package.config:sub(1,1) == "\\" and "win" or "unix"
end

function SaveLastLoadedFile(setToSave)
  local file = assert(io.open(fileStorage.getDirectory()..lastLoadedSetNameFile, "w"))
  file:write(setToSave)
  file:close()
end

function DeleteFile(fileName)
  local path = fileStorage.getDirectory()..fileName.label
  local func = function() assert(os.remove(path)) end
  confirmationPopup('Are you sure you want to delete the setlist: '..fileName.label..' ?', func)
end


return fileStorage

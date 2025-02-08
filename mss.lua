-- settings
local accessCode = nil -- the password for the storage center
local allowHealthCheckups = true -- allow health checkups?
local healthCheckupDelay = 300 -- health checkup delays (seconds)

local nTime = os.time()
local nDay = os.day()
local time = textutils.formatTime(nTime,false)..", Day "..nDay

local logs = {{"STARTUP AT "..time,colors.blue}}
local drives = {}
local original = {}
local allowed = {}

local drivesY = 0
local logsY = 0
local autoscroll = true

local s,e = pcall(function () peripheral.find("modem",rednet.open) end)
if not s then
    print("connect a modem")
    return
end

-- window creation.

local w,h = term.getSize()

local bg = window.create(term.current(),1,2,w,h)
bg.setBackgroundColor(colors.white)
bg.setTextColor(colors.lightGray)
local title = window.create(term.current(),1,1,w,1)
title.setBackgroundColor(colors.gray)
title.setTextColor(colors.white)

local drivestats = window.create(term.current(),2,4,w-2,(h/2)-2)
drivestats.setBackgroundColor(colors.lightGray)
local drivetitle = window.create(term.current(),2,3,w-2,1)
drivetitle.setBackgroundColor(colors.gray)
drivetitle.setTextColor(colors.lightGray)
    
local logshow = window.create(term.current(),2,(h/2)+4,w-2,(h/2)-3)
logshow.setBackgroundColor(colors.lightGray)
local logtitle = window.create(term.current(),2,(h/2)+3,w-2,1)
logtitle.setBackgroundColor(colors.gray)
logtitle.setTextColor(colors.lightGray)

function formatBytes(bytes)
    -- theres no way you are reaching Terra Bytes.
    local units = {"Bytes", "KB", "MB", "GB", "TB"}

    local scale = 0
    while bytes >= 1024 and scale < #units - 1 do
        bytes = bytes / 1024
        scale = scale + 1
    end

    return string.format("%.2f %s", bytes, units[scale + 1])
end

function table.find(list,element)
    for i,v in pairs(list) do
        if v == element then
            return i
        end
    end
    return nil
end

function log(log,color)
    table.insert(logs,{log,color})
    if autoscroll then
        logsY = -math.max(0,#logs - (h/2-3))
    end
end

function getDisks()
    drives = {}
    for i,v in pairs({peripheral.find("drive")}) do
        local path = v.getMountPath()
        if path then
            local id = tonumber(string.sub(path,5,105))
            if not id then
                id = 1
            end
            drives[id] = path
        end
    end
end

-- the main FUNCTIONS

function write(name,content)
    local size = string.len(content)
    local getPos = 1
    local wdisks = {}
    for i,v in pairs(drives) do
        local space = fs.getFreeSpace(v)
        if space ~= 0 then
            local write = string.sub(content,getPos,getPos+space-1)
            getPos = getPos + space
            local writing = fs.open(v.."/"..name,"w")
            writing.write(write)
            writing.close()
            table.insert(wdisks,v)
            if getPos > size then
                log("wrote "..name.." to "..table.concat(wdisks,", "),colors.lightBlue)
                break
            end
        end
    end
    if #wdisks == 0 then
        log("STORAGE IS FULL, UNABLE TO WRITE "..name,colors.red)
    end
end

function read(name)
    local r = ""
    for i,v in pairs(drives) do
        local path = v.."/"..name
        if fs.exists(path) then
            local reading = fs.open(path,"r")
            r =r..reading.readAll()
            reading.close()
        end
    end
    return r
end

function delete(name)
    for i,v in pairs(drives) do
        local path = v.."/"..name
        if fs.exists(path) then
            fs.delete(path)
        end
    end
end

function list(dir)
    local dirs,files = {},{}
    local total = {}
    for i,disk in pairs(drives) do
        if fs.exists(shell.resolve(disk.."/"..dir)) then
            local stuffs = fs.list(shell.resolve(disk.."/"..dir))
            for i,v in pairs(stuffs) do
                if not table.find(total,v) then
                    table.insert(total,v)
                    if fs.isDir(v) then
                        table.insert(dirs,v)
                    else
                        table.insert(files,v)
                    end
                end
            end
        end
    end
    return {dirs,files}
end

function isDir(dir)
    for i,disk in pairs(drives) do
        if fs.isDir(shell.resolve(disk.."/"..dir)) then
            return true
        end
    end
    return false
end

function communicationTask()
    while true do
        local id,msg = rednet.receive("MSS")
        local mode = msg[1]
        
        if mode == "ping" then
            log(id.." pinged",colors.lightBlue)
            rednet.send(id,"pinged successful, id: ","MSS")
        end
    
        if mode == "login" then
            if msg[2] == accessCode then
                log(id.." successfully logged in",colors.blue)
                rednet.send(id,"SUCCESS","MSS")
                table.insert(allowed,id)
            else
                log(id.." failed logging in",colors.yellow)
            end
        end
    
        if table.find(allowed,id) then
    
            if mode == "logout" then
                log(id.." logged out",colors.blue)
                local pos = table.find(allowed,id)
                table.remove(allowed,pos)
            end
    
            if mode == "write" then
                local name = msg[2]
                local content = msg[3]
                if name and content then
                    log(id.." requested to "..mode.." "..name,colors.lime)
                    write(name,content)
                    renderDiskData()
                end
            end
        
            if mode == "read" then
                local name = msg[2]
                if name then
                    log(id.." requested to "..mode.." on "..name,colors.lime)
                    local r = read(name)
                    rednet.send(id,r,"MSS")
                end
            end
        
            if mode == "delete" then
                local name = msg[2]
                if name then
                    log(id.." requested to "..mode.." "..name,colors.red)
                    delete(name)
                    renderDiskData()
                end
            end
    
            if mode == "ls" then
                local dir = msg[2]
                if dir then
                    log(id.." requested to list "..dir,colors.lime)
                    local data = list(dir)
                    rednet.send(id,data,"MSS")
                end
            end
    
            if mode == "isDir" then
                local dir = msg[2]
                if dir then
                    log(id.." requested to isDir "..dir,colors.lime)
                    local data = isDir(dir)
                    rednet.send(id,data,"MSS")
                end
            end
    
        elseif mode ~= "ping" then
            log(id.." has unauthorized access",colors.red)
            rednet.send(id,"FAILURE","MSS")
        end
        renderLogs()
    end
end

function inBounds(px,py,x,y,sx,sy)
    return px >= x and px < x+sx and py >= y and py < y+sy
end

function interactionTask()
    while true do
        local event, dir, x, y = os.pullEvent()

        if event == "mouse_scroll" then
            if inBounds(x,y,2,4,w-2,(h/2)-2) then
                drivesY = math.min(0,drivesY - dir)
            end
    
            if inBounds(x,y,2,(h/2)+4,w-2,(h/2)-3) then
                logsY = math.min(0,logsY - dir)
            end
        end

        if event == "mouse_click" then
            if inBounds(x,y,2,(h/2)+2,w-2,1) then
                autoscroll = not autoscroll
            end
        end
    end
end

term.setCursorPos(1,1)
term.setTextColor(colors.white)
print("fetching all of the disks.")
getDisks()
original = drives
print("finished!")
sleep(1)

function setup()
    bg.clear()
    title.clear()
    title.setCursorPos(1,1)
    title.write("Mass Storage System [V.2.0]")
end

function renderDiskData()
    getDisks()
    drivestats.clear()
    drivetitle.clear()
    drivestats.setBackgroundColor(1,1)
    drivetitle.setCursorPos(1,1)
    drivetitle.write("Drive status (restart to register more)")

    local totalFree = 0
    local totalUsed = 0
    local totalCapacity = 0
    local totalLost = 0
    local totalDrives = 0
    for i,v in ipairs(original) do
        if table.find(drives,v) then
            totalDrives = totalDrives+1
            local free = fs.getFreeSpace(v)
            local capacity = fs.getCapacity(v)
            totalFree = totalFree + free
            totalUsed = totalUsed + (capacity - free)
            totalCapacity = totalCapacity + capacity
        else
            totalLost = totalLost + 1
        end
    end
    drivestats.setBackgroundColor(colors.lightGray)
    drivestats.setCursorPos(1,1)
    drivestats.setTextColor(colors.lime)
    drivestats.write("Total Capacity: "..formatBytes(totalCapacity).." ("..totalDrives.." Disks)")

    -- fancy coloring
    drivestats.setTextColor(colors.lime)
    if totalFree < 10240 then
        drivestats.setTextColor(colors.yellow)
        if totalFree < 1024 then
            drivestats.setTextColor(colors.red)
        end
    end

    drivestats.setCursorPos(1,2)
    local s1 = string.format("Used storage: %s (%.2f%%)",formatBytes(totalUsed), (totalUsed/totalCapacity)*100)
    drivestats.write(s1)

    drivestats.setCursorPos(1,3)
    drivestats.write("Free storage: "..formatBytes(totalFree))

    -- fancy coloring
    local s2 = "Lost Disks: 0"
    drivestats.setTextColor(colors.white)
    if totalLost >= 1 then
        s2 = "/!\\ Lost Disks: "..totalLost.." /!\\"
        drivestats.setTextColor(colors.red)
    end
    drivestats.setCursorPos(1,4)
    drivestats.write(s2)
end

function renderLogs()
    logshow.clear()
    logtitle.clear()
    logtitle.setCursorPos(2,1)
    logtitle.write("Logs (auto-scroll: "..tostring(autoscroll)..", press to toggle)")

    for i=1,6 do
        logshow.setCursorPos(1,i)
        logshow.setTextColor((logs[i+logsY] or {})[2] or colors.white)
        logshow.write((logs[i+logsY] or {})[1] or "")
    end
end

setup()
renderDiskData()
renderLogs()

function healthCheckup()
    if allowHealthCheckups then
        while true do
            renderDiskData()
            sleep(healthCheckupDelay)
        end
    end
end

parallel.waitForAll(communicationTask,interactionTask,healthCheckup)

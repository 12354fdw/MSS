local s = pcall(function ()
    peripheral.find("modem",rednet.open)
end)
if not s then
    printError("connect a modem")
    return
end

local args = {...}
local accessCode = args[1]
rednet.broadcast({"ping"},"MSS")
local id,msg = rednet.receive("MSS",0.5)
if not id then
    printError("Unable to ping")
    return
end
print(msg..id)
rednet.send(id,{"login",accessCode},"MSS")
local useless = rednet.receive("MSS",0.05)
if not useless then
    printError("access denied")
    return
end

function fetch(data)
    rednet.send(id,data,"MSS")
    local useless,msg = rednet.receive("MSS",0.05)
    return msg
end

local ldir = "\n\n"
local isDir = true

local w,h = term.getSize()
local cur = term.current()

local bg = window.create(cur,1,3,w,h-2)
bg.setBackgroundColor(colors.white)
bg.setTextColor(colors.lightGray)
local title = window.create(cur,1,1,w,1)
title.setBackgroundColor(colors.gray)
title.setTextColor(colors.white)

local localSwitch = window.create(cur,1,2,w/2,1)
localSwitch.setBackgroundColor(colors.lightGray)
localSwitch.setTextColor(colors.white)
local storageSwitch = window.create(cur,w/2+1,2,w/2+1,1)
storageSwitch.setBackgroundColor(colors.gray)
storageSwitch.setTextColor(colors.white)

-- file column X
local thrid = w/3
local fc1 = window.create(cur,1,4,thrid-1,h-3)
fc1.setBackgroundColor(colors.white)
local fc2 = window.create(cur,thrid+1,4,thrid-1,h-3)
fc2.setBackgroundColor(colors.white)
local fc3 = window.create(cur,thrid*2+1,4,thrid-1,h-3)
fc3.setBackgroundColor(colors.white)
local fcd = {{},{},{}}

local dir = ""
local storageMode = false

-- file read y
local fry = 0

local fcs = {
    fc1,
    fc2,
    fc3
}

function string.split(inputstr, sep)
    if sep == nil then 
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function render()
    bg.clear()
    title.clear()
    title.setCursorPos(1,1)
    title.write("Mass Storage System Access Terminal (MSSAT)")

    localSwitch.clear()
    localSwitch.setCursorPos(1,1)
    localSwitch.write("Local computer")
    storageSwitch.clear()
    storageSwitch.setCursorPos(1,1)
    storageSwitch.write("Storage")
end

function renderDir(dirs,files)
    fc1.clear()
    fc2.clear()
    fc3.clear()
    local fcx = 1
    local height = 1
    
    fcd = {{},{},{}}

    for i,v in pairs(dirs) do
        fcs[fcx].setTextColor(colors.green)
        fcs[fcx].setCursorPos(1,height)
        fcs[fcx].write(v)
        table.insert(fcd[fcx],v)
        fcx = fcx + 1
        if fcx % 4 == 0 then
            fcx = 1
            height = height + 1
        end
    end

    for i,v in pairs(files) do
        fcs[fcx].setTextColor(colors.lightBlue)
        fcs[fcx].setCursorPos(1,height)
        fcs[fcx].write(v)
        table.insert(fcd[fcx],v)
        fcx = fcx + 1
        if fcx % 4 == 0 then
            fcx = 1
            height = height + 1
        end
    end
end

local cache = ""
local content = {}
function renderFile()
    bg.clear()
    if ldir ~= dir then
        content = {}
        cache = ""
        if storageMode then
            local read = fetch({"read",dir})
            cache = read
            for i,v in pairs(string.split(read,"\n")) do
                table.insert(content,v)
            end
        else
            local reading = fs.open(dir,"r")
            local read  = reading.readAll()
            cache = read
            reading.close()
            for i,v in pairs(string.split(read,"\n")) do
                table.insert(content,v)
            end
        end
    end
    local y = 2
    for i=fry+1,h-4+fry do
        local v = content[i]
        if v then
            bg.setCursorPos(2,y)
            bg.write(v)
        end
        y = y+1
    end
end

function inBounds(px,py,x,y,sx,sy)
    return px >= x and px < x+sx and py >= y and py < y+sy
end

function getLocalFiles()
    local lists = fs.list(shell.resolve(dir))
    local dirs,files = {},{}
    for i,v in pairs(lists) do
        if fs.isDir(dir.."/"..v) then
            table.insert(dirs,v)
        else
            table.insert(files,v)
        end
    end
    table.sort(dirs)
    table.sort(files)
    return {dirs,files}
end

function renderLocal()
    if isDir then
        if dir ~= "" then
            local delete = window.create(cur,w-(w/8-2),h,w/8,1)
            delete.setBackgroundColor(colors.red)
            delete.clear()
            delete.write("delete")
        end
    else
        local upload = window.create(cur,w/8+1,h,w/8,1)
        upload.setBackgroundColor(colors.lightBlue)
        upload.clear()
        upload.write("upload")
        local delete = window.create(cur,w-(w/8-2),h,w/8,1)
        delete.setBackgroundColor(colors.red)
        delete.clear()
        delete.write("delete")
    end
    bg.setTextColor(colors.lime)
    bg.setCursorPos(1,1)
    bg.write(dir)
    bg.setTextColor(colors.lightGray)
    local back = window.create(cur,1,h,w/8,1)
    back.setBackgroundColor(colors.lime)
    back.clear()
    back.write("...dir")
end

function renderStorage()
    if isDir then
        if dir ~= "" then
            local delete = window.create(cur,w-(w/8-2),h,w/8,1)
            delete.setBackgroundColor(colors.red)
            delete.clear()
            delete.write("delete")
        end
    else
        local download = window.create(cur,w/8+1,h,w/8,1)
        download.setBackgroundColor(colors.lightBlue)
        download.clear()
        download.write("downld")
        local delete = window.create(cur,w-(w/8-2),h,w/8,1)
        delete.setBackgroundColor(colors.red)
        delete.clear()
        delete.write("delete")
    end
    bg.setTextColor(colors.lime)
    bg.setCursorPos(1,1)
    bg.write(dir)
    bg.setTextColor(colors.lightGray)
    local back = window.create(cur,1,h,w/8,1)
    back.setBackgroundColor(colors.lime)
    back.clear()
    back.write("...dir")
end

function fileClick()
    while true do 
        local event,button,x,y = os.pullEvent("mouse_click")
        if isDir then
            if inBounds(x,y,1,4,thrid-1,h-3) then
                local change = fcd[1][y-3]
                if change then
                    dir = shell.resolve(dir.."/"..change)
                end
            end
    
            if inBounds(x,y,thrid+1,4,thrid-1,h-3) then
                local change = fcd[2][y-3]
                if change then
                    dir = shell.resolve(dir.."/"..change)
                end
            end
    
            if inBounds(x,y,thrid*2+1,4,thrid-1,h-3) then
                local change = fcd[3][y-3]
                if change then
                    dir = shell.resolve(dir.."/"..change)
                end
            end
            if storageMode then

                if dir ~= "" then
                    if inBounds(x,y,w-(w/8-2),h,w/8,1) then
                        fetch({"delete",dir})
                        local new = shell.resolve(dir.."/..")
                        if fs.isDir(new) then
                            fry = 0
                            dir = new
                        end
                    end
                end

            else
                if dir ~= "" then
                    if inBounds(x,y,w-(w/8-2),h,w/8,1) then
                        fs.delete(dir)
                        local new = shell.resolve(dir.."/..")
                        if fs.isDir(new) then
                            fry = 0
                            dir = new
                        end
                    end
                end
            end
        else
            if storageMode then
                if inBounds(x,y,w/8+1,h,w/8,1) then
                    local writing = fs.open(dir,"w")
                    writing.write(cache)
                    writing.close()
                end

                if dir ~= "" then
                    if inBounds(x,y,w-(w/8-2),h,w/8,1) then
                        fetch({"delete",dir})
                        local new = shell.resolve(dir.."/..")
                        if fs.isDir(new) then
                            fry = 0
                            dir = new
                        end
                    end
                end
                
            else

                if inBounds(x,y,w/8+1,h,w/8,1) then
                    fetch({"write",dir,cache})
                end
                
                if inBounds(x,y,w-(w/8-2),h,w/8,1) then
                    fs.delete(dir)
                    local new = shell.resolve(dir.."/..")
                    if fs.isDir(new) then
                        fry = 0
                        dir = new
                    end
                end
            end
        end

        if inBounds(x,y,1,h,w/8,1) then
            local new = shell.resolve(dir.."/..")
            if fs.isDir(new) then
                fry = 0
                dir = new
            end
        end
    end
end

local files = {}
function main()
    while true do
        render()
        if storageMode then
            if ldir ~= dir then
                isDir = fetch({"isDir",dir})
                if isDir then
                    files = fetch({"ls",dir})
                end
            end
            if isDir then
                renderDir(files[1],files[2])
            else
                renderFile(dir)
            end
            renderStorage()
            ldir = dir
        else

            if ldir ~= dir then
                isDir = fs.isDir(dir)
                if isDir then
                    files = getLocalFiles()
                end
            end
            if isDir then
                renderDir(files[1],files[2])
            else
                renderFile(dir)
            end
            renderLocal()

        end
        ldir = dir
        sleep(0.1)

    end
end

function interaction()
    while true do
        local event,what,x,y = os.pullEvent()

        if event == "mouse_scroll" then
            if not isDir then
                fry = math.max(0,fry + what)
            end
        end

        if event == "mouse_click" then
            if inBounds(x,y,1,2,w/2,1) then
                storageMode = false
                storageSwitch.setBackgroundColor(colors.gray)
                localSwitch.setBackgroundColor(colors.lightGray)
                ldir = "\n\n"
                dir = ""
            end
            if inBounds(x,y,w/2+1,2,w/2+1,1) then
                storageMode = true
                storageSwitch.setBackgroundColor(colors.lightGray)
                localSwitch.setBackgroundColor(colors.gray)
                ldir = "\n\n"
                dir = ""
            end
        end

    end
end

parallel.waitForAll(main,interaction,fileClick)
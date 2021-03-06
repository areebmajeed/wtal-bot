local testing = false
--Depenendencies--
local discordia = require('discordia')
local http = require('coro-http')
local fromage = require('fromage')
local transfromage = require('transfromage')
local timer = require('timer')
local json = require('json')
local enum = require(testing and 'enum-test' or 'enum')
local hi = require('replies')
local md5 = require('md5')

local discord = discordia.Client({
    cacheAllMembers = true
})

local forums = fromage()
local tfm = transfromage.client:new()

local guild = nil
local updated = false
local histLogs = {}
local members = {}
local verificationKeys = {}
local onlineMembers = {
    ["Wtal#5272"] = true
}
local tribeHouseCount = 0
local onlineCount = 1
local totalMembers = 0
local attempts = 5

loop = function()
    forums.getTribeHistory(enum.id)
    tfm:playEmoticon(math.random(0, 9))
    timer.setTimeout(1000 * 60 * 5, coroutine.wrap(loop))
end

local getStoredName = function(name, memberList)
    memberList = memberList or members
    for n, r in next, memberList do             
        if not not n:find(name .. '#?%d*') then
            return n
        end
    end
    return nil
end

local removeRanks = function(member)
    for role, id in next, enum.roles do
        if member:hasRole(id) and role ~= "manager" and role ~= "member" and role ~= "Verified" then
            member:removeRole(id)
        end
    end
end

setRank = function(member, fromTfm)
    print('setting rank')
    if (not fromTfm) and updated and member:hasRole(enum.roles["Verified"]) then
        print('Setting rank of ' .. member.name)
        for name, data in next, members do
            local rank = data.rank
            if name:lower():find(member.name:lower() .. '#?%d*') then
                print('Found member mathcing the given instance')
                print('Removing existing rank')            
                removeRanks(member)
                print('Adding the new rank \'' .. rank .. '\'')
                member:addRole(enum.roles[rank])
                return
            end
        end
        removeRanks(member)
        member:addRole(enum.roles['Passer-by'])
    elseif fromTfm and updated then
        print('Setting rank of ' .. member)
        for k, v in pairs(guild.members) do      
            if member:find(v.name .. '#?%d*') then
                setRank(v, false)
            end
        end
    end
end


local getMembers = function()
    print('Connecting to members...')
    local page = 1
    local p1 = forums.getTribeMembers(enum.id, page)
    print('Fetching members... (total pages:' .. p1._pages .. ')')
    while page <= p1._pages do
        print('Getting page ' .. page .. ' of ' ..p1._pages .. ' ...')
        for _, member in next, forums.getTribeMembers(enum.id, page) do
            if (type(member) == 'table') then
                members[member.name] = {rank=member.rank, joined=member.timestamp / 1000, name=member.name}
                totalMembers = totalMembers + 1
            end
        end
        page = page + 1
    end
    print('Updated all members!')
    updated = true
    tfm:joinTribeHouse()
end

local encodeUrl = function(url)
	local out, counter = {}, 0

	for letter in string.gmatch(url, '.') do
		counter = counter + 1
		out[counter] = string.upper(string.format("%02x", string.byte(letter)))
	end

	return '%' .. table.concat(out, '%')
end

local reply = function(name)
    local res = ""
    xpcall(function()
        print("Requesting useless facts...")
        local head, body = http.request('GET', 'https://uselessfacts.jsph.pl/random.md?language=en', {{ "user-agent", 'Seniru' }})
        res = hi[math.random(1, #hi)] .. " " .. name .. "! Wanna hear a fact?\n" .. body
        print("Request completed!")
    end, function() print("Request failed!") res = "Oops! An error occured!" end)
    return res
end

local formatName = function(name)
    return name:sub(1, 1):upper() .. name:sub(2):lower()
end

local getProfile = function(name, msg)
    xpcall(function()
        name = formatName(name)
        print('> p ' .. name)
        local mem = members[getStoredName(name)]
        
        -- setting member name to the name given if the member is not in the tribe
        if not mem then
            if name:find("#%d%d%d%d") then
                mem = {name = name}
            else 
                mem = {name = name .. "#0000"}
            end
        end

        local fName = mem.name:sub(1, -6)
        local disc = mem.name:sub(-4)

        --retrieving html chunk from cfm and atelier801 forums
        local _, cfm = http.request('GET', 'https://cheese.formice.com/transformice/mouse/' .. fName .. "%23" .. disc)
        --retrieving profile data from forums (using fromage)
        local p = forums.getProfile(mem.name)

        if p == nil then -- send an error message if the player is not available
            msg:reply("We couldn't find what you were looking for :(")
            return
        end
        --extracting data from html chunk
        local title = cfm:match("«(.+)»")
        title = encodeUrl(title or 'Little mouse')
        local _, tb = http.request('GET', 'https://translate.yandex.net/api/v1.5/tr.json/translate?key=' .. os.getenv('TRANSLATE_KEY') .. '&text=' .. title .. '&lang=es-en&format=plain')
        title = json.parse(tb)["text"][1]
        local level = cfm:match("<b>Level</b>: (%d+)<br>")
        local outfit = cfm:match("<a href=\"(https://cheese.formice.com/dressroom.+)\" target=\"_blank\">View outfit in use</a>")
        --returning the string containing profile data
        msg.channel:send {
            embed = {
                title = name .. "'s Profile",
                description = 
                    "**" .. mem.name .. "** \n*«" .. (title or "Little mouse") .. 
                    "»*" .. (mem.rank and "\n\nRank: " .. mem.rank or (p.tribe and "\n\nTribe: " .. p.tribe or "")) ..
                    (mem.joined and "\nMember since: " .. os.date('%d-%m-%Y %H:%M',mem.joined) or "") .. 
                    "\nGender: " .. ({"None", "Female", "Male"})[p.gender + 1] .. 
                    "\nLevel: " .. (level or 1) .. 
                    (p.birthday and "\nBirthday: " .. p.birthday or "") ..
                    (p.location and "\nLocation: " .. p.location or "") .. 
                    (p.soulmate and "\nSoulmate: " .. p.soulmate or "") ..
                    "\nRegistration date: " .. p.registrationDate ..
                    "\n\n[Forum Profile](https://atelier801.com/profile?pr=" .. fName .. "%23" .. disc ..")" ..
                    "\n[CFM Profile](https://cheese.formice.com/transformice/mouse/" .. fName .. "%23" .. disc .. ")" ..
                    ("\n[Outfit](" .. outfit .. ")"),
                thumbnail = {url = p.avatarUrl}           
            }
        }
    end, function(err) print("Error occured: " .. err) end)
end

local printOnlineUsers = function(from, target)
    local res = ""
    if from == "tfm" then
        -- iterating through all online members in transformice
        for name, _ in next, onlineMembers do
            res = res .. "\n• ".. name
        end
        
        target:send {
            embed = {
                title = "Online members from transformice",
                description = res == "" and "Nobody is online right now!" or res
            }
        }

    elseif from == "discord" then
        local totalCount = 0
        -- iterating through all the members in discord
        tfm:sendWhisper(target, "Online members from disord: ")
        for id, member in pairs(guild.members) do
            if member ~= nil and member.name ~= nil and not member.user.bot and member.status ~= "offline" then
                res = res .. member.name .. ", "
                totalCount = totalCount + 1
            end
            if res:len() > 230 then
                tfm:sendWhisper(target, res:sub(1, -3))
                res = ""
            end
        end
        tfm:sendWhisper(target, total == 0 and "Nobody is online right now" or res:sub(1, -3))
        tfm:sendWhisper(target, "Total members: " .. totalCount .. " (Ingame member list is accessible with the tribe menu)")
    end
end

local generateVerificationkey = function(id, randomseed)
    math.randomseed(randomseed or os.time())
    return md5.sumhexa(tostring(math.random(0, 10000) * id + math.random(0, 10000)))
end

local sendVerificationKey = function(member, channel, force)
    if member:hasRole(enum.roles['Verified']) then
        if force and member:hasRole(enum.roles["manager"]) then
            local key = generateVerificationkey(member.user.id)
            verificationKeys[key] = member
            member.user:send("Here's your verification key! `" .. key .. "\n`Whisper the following to Wtal#5272 (`/c Wtal#5272`) to get verified\n")
            member.user:send("```!verify " .. key .. "```")
        elseif force then
            channel:send("You are not permitted for force verification")
        else
            channel:send("You are verified already!")
        end
    else
        local key = generateVerificationkey(member.user.id)
        verificationKeys[key] = member
        member.user:send("Here's your verification key! `" .. key .. "\n`Whisper the following to Wtal#5272 (`/c Wtal#5272`) to get verified\n")
        member.user:send("```!verify " .. key .. "```")
    end
end

coroutine.wrap(function()
    
    --[[Transfromage events]]

    tfm:once("ready", function()
        print('Logging into transformice...')
	    tfm:connect("Wtal#5272", os.getenv('FORUM_PASSWORD'))
    end)
    
    tfm:on("connection", function(name, comm, id, time)
        attempts = 5
        print('Logged in successfully!')
        tfm:sendTribeMessage("Connected to tribe chat!")
        print('Logging in with forums...')
        forums.connect('Wtal#5272', os.getenv('FORUM_PASSWORD'))
        getMembers()
        discord:setGame(onlineCount .. " / " .. totalMembers .. " Online!")
        loop()
    end)

    tfm:on("connectionFailed", function()
        if attempts > 0 then
            print("Connection to transformice failed!\nTrying again (Attempts: " .. attempts .. " / 5)")
            attempts = attempts - 1
            tfm:connect("Wtal#5272", os.getenv('FORUM_PASSWORD'))
        else
            print("Connection to transformice failed!\nRestarting!")
			os.exit(1)
        end
    end)

    tfm:on("disconnection", function()
        print("disconnected")
    end)

    tfm:on("tribeMemberConnection", function(member)
        tfm:sendTribeMessage("Welcome back " .. member .. "!")
        guild:getChannel(enum.channels.tribe_chat):send("> **" .. member .. "** just connected!")
        onlineMembers[member] = true
        onlineCount = onlineCount + 1
        discord:setGame(onlineCount .. " / " .. totalMembers .. " Online!")
    end)

    tfm:on("tribeMemberDisconnection", function(member)
        guild:getChannel(enum.channels.tribe_chat):send("> **" .. member .. "** has disconnected!")
        if onlineMembers[member] then
			onlineCount = onlineCount - 1
			onlineMembers[member] = nil
			discord:setGame(onlineCount .. " / " .. totalMembers .. " Online!")
        end
    end)

    tfm:on("newTribeMember", function(member)
        tfm:sendTribeMessage("Welcome to 'We Talk a Lot' " .. member .. "!")
        tfm:sendTribeMessage("Don't forget to check our discord server at https://discord.gg/8g7Hfnd")
        members[member] = {rank='Stooge', joined=os.time(), name=member}
        setRank(member, true)
		onlineMembers[member] = true
        onlineCount = onlineCount + 1
        totalMembers = totalMembers + 1
        discord:setGame(onlineCount .. " / " .. totalMembers .. " Online!")
    end)

    tfm:on("tribeMemberLeave", function(member)
        members[member].rank = 'Passer-by'
        setRank(member, true)
		if onlineMembers[member] then
        	onlineCount = onlineCount - 1
			onlineMembers[member] = nil
		end
        totalMembers = totalMembers - 1
        discord:setGame(onlineCount .. " / " .. totalMembers .. " Online!")
    end)

    tfm:on("tribeMemberGetRole", function(member, setter, role)
        members[member].rank = role
        setRank(member, true)
    end)

    tfm:on("tribeMessage", function(member, message)
        if message == "!who" then
            printOnlineUsers("discord", member)
        else
            guild:getChannel(enum.channels.tribe_chat):send("> **[" .. member .. "]** " .. message)
        end
        if not onlineMembers[member] then
            onlineCount = onlineCount + 1
            onlineMembers[member] = true
            discord:setGame(onlineCount .. " / " .. totalMembers .. " Online!")
        end
    end)

    tfm:on("whisperMessage", function(playerName, message, community)
        if message:find("!verify .+") then
            local key = message:match("!verify (.+)")
            if not verificationKeys[key] then
                tfm:sendWhisper(playerName, "Your verification key doesn't match with any key in the database!")
                tfm:sendWhisper(playerName, "Try verify again (> verify) or contact the admininstration for support")
            else
                tfm:sendWhisper(playerName, "Succesfully verified and connected player with " .. verificationKeys[key].name .. " on discord!")
                verificationKeys[key]:setNickname(playerName:sub(1, -6))
                verificationKeys[key]:addRole(enum.roles['Verified'])
                guild:getChannel(enum.channels.general_chat):send(verificationKeys[key].mentionString )
                guild:getChannel(enum.channels.general_chat):send {
                    embed = {
                        description = "Welcome here buddy･:+(ﾉ◕ヮ◕)ﾉ*:･\nSay hi and introduce yourself to others. Also heads onto <#620437243944763412> to add some roles!",
                        color = 0x22ff22                        
                    }
                }
                verificationKeys[key] = nil
            end
        end
    end)

    tfm:on("newPlayer", function(playerData)
        tribeHouseCount = tribeHouseCount + 1
        print("Player joined: (total players: " .. tribeHouseCount .. ")") 
        if updated then tfm:sendRoomMessage("Hello " .. playerData.playerName .. "!") end
        if not onlineMembers[playerData.playerName] and members[playerData.playerName] then
            onlineCount = onlineCount + 1
            onlineMembers[playerData.playerName] = true
            discord:setGame(onlineCount .. " / " .. totalMembers .. " Online!")
        end
    end)

    tfm:on("playerLeft", function(playerData)
        tribeHouseCount = tribeHouseCount - 1
        print("Player left: (total players: " .. tribeHouseCount .. ")")
        if tribeHouseCount == 1 then
            tfm:sendCommand("module stop")
        end
    end)

    tfm:on("joinTribeHouse", function(tribeName)
        tfm:emit("refreshPlayerList")
    end)

    tfm:on("refreshPlayerList", function(playerList)
        tribeHouseCount = playerList and (playerList.count or 0) or 0
        if playerList and updated then
            print("Joined tribe house. (Player count: " .. tribeHouseCount .. ")")
            for name, data in next, playerList do
                if (not onlineMembers[name]) and members[name] then
                    onlineCount = onlineCount + 1
                    onlineMembers[name] = true
                    discord:setGame(onlineCount .. " / " .. totalMembers .. " Online!")
                end
            end
        end
    end)


    --[[ Discord events]]

    discord:once("ready", function()
        guild = discord:getGuild(enum.guild)
        forums.connect('Wtal#5272', os.getenv('FORUM_PASSWORD'))
        print("Starting transformice client...")
        tfm:handlePlayers(true)
        tfm:start("89818485", os.getenv('TRANSFROMAGE_KEY'))
    end)

    discord:on('messageCreate', function(msg)
        local mentioned = msg.mentionedUsers
        --For testing purposes
        if msg.content:lower() == '> ping' then
            msg:reply('Pong!')
        -- profile command
        elseif mentioned:count() == 1 and mentioned.first.id == '654987403890524160' then
            msg:reply(reply(msg.author.mentionString))
        elseif msg.content:find("^>%s*p%s*$") then
            getProfile(msg.member.name, msg)            
        elseif msg.content:find('^>%s*p%s+<@!%d+>%s*$') and mentioned:count() == 1 and not msg.mentionsEveryone then
            getProfile(discord:getGuild(enum.guild):getMember(mentioned.first.id).name, msg)
        elseif msg.content:find('^>%s*p%s+(.-#?%d*)%s*$') then
            getProfile(msg.content:match("^>%s*p%s+(.+#?%d*)%s*$"), msg)
        -- online users
        elseif msg.content:find("^>%s*who%s*$") then
            printOnlineUsers("tfm", msg.channel)
        -- tribe chat
        elseif msg.channel.id == enum.channels.tribe_chat then
            _, count = msg.content:gsub("`", "")
            if msg.content:find("^`.+`$") and count == 2 then
                local cont = msg.content:gsub("`+", "")
                tfm:sendTribeMessage("[" .. msg.member.name .. "] " .. cont)
            end
        -- verification
        elseif msg.content:lower() == "> verify" then
            sendVerificationKey(msg.member, msg.channel, false)
        elseif msg.content:lower() == "> verify force" then
            sendVerificationKey(msg.member, msg.channel, true)
        -- restart command
        elseif msg.content:lower() == "> restart" then
            if msg.member:hasRole(enum.roles["manager"]) then
                msg:reply("Restarting the bot...")
                os.exit(1)
            else
                msg:reply("You don't have enough permissions to do this action!")
            end
        end

    end)

    discord:on('memberJoin', function(member)
        guild:getChannel(enum.channels.lobby):send(member.user.mentionString)
        guild:getChannel(enum.channels.lobby):send { 
            embed = {
                title = "Welcome!",
                description = 'Welcome to the WTAL server (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧\nWe have sent you a DM to verify you in order to give you the best experience!',
                color = 0x0066ff
            }
         }
        member:addRole(enum.roles["member"])
        sendVerificationKey(member)
    end)

    discord:on('memberUpdate', function(member)
        print('Member Update event fired!')
        local stored = members[getStoredName(member.name)]
        if not member.user.bot and not member:hasRole(stored and enum.roles[stored.rank] or enum.roles['Passer-by']) then
            setRank(member)
        end
    end)
end)()


discord:run('Bot ' .. os.getenv('DISCORD'))

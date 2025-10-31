local playerCache = {}

local function PerformHttpRequest(url, method, data, headers, callback)
    PerformHttpRequest(url, callback, method, data and json.encode(data) or '', headers or {})
end

local function GetDiscordUser(userId, callback)
    if not Config.BotToken or Config.BotToken == '' then
        callback(false, nil)
        return
    end

    local endpoint = ('https://discord.com/api/v10/guilds/%s/members/%s'):format(Config.GuildId, userId)
    
    PerformHttpRequest(endpoint, 'GET', nil, {
        ['Authorization'] = 'Bot ' .. Config.BotToken,
        ['Content-Type'] = 'application/json'
    }, function(statusCode, response)
        if statusCode == 200 then
            local data = json.decode(response)
            if data then
                callback(true, data)
            else
                callback(false, nil)
            end
        else
            callback(false, nil)
        end
    end)
end

local function GetDiscordRoles(userId, callback)
    if not Config.EnableRoleCheck or not Config.BotToken or Config.BotToken == '' then
        callback(false, {})
        return
    end

    GetDiscordUser(userId, function(success, data)
        if success and data and data.roles then
            callback(true, data.roles)
        else
            callback(false, {})
        end
    end)
end

local function GetDiscordUsername(userId, callback)
    if not Config.BotToken or Config.BotToken == '' then
        callback(false, nil)
        return
    end

    GetDiscordUser(userId, function(success, data)
        if success and data and data.user then
            local username = data.nick or data.user.global_name or data.user.username
            callback(true, username, data.user.discriminator)
        else
            callback(false, nil, nil)
        end
    end)
end

local function GetDiscordAvatar(userId, callback)
    if not Config.BotToken or Config.BotToken == '' then
        callback(false, nil)
        return
    end

    GetDiscordUser(userId, function(success, data)
        if success and data and data.user then
            local avatarHash = data.user.avatar
            if avatarHash then
                local avatarUrl = ('https://cdn.discordapp.com/avatars/%s/%s.png'):format(userId, avatarHash)
                callback(true, avatarUrl)
            else
                local defaultAvatar = ((tonumber(data.user.discriminator) or 0) % 5)
                local defaultUrl = ('https://cdn.discordapp.com/embed/avatars/%s.png'):format(defaultAvatar)
                callback(true, defaultUrl)
            end
        else
            callback(false, nil)
        end
    end)
end

local function SendWebhook(webhookType, data)
    if not Config.EnableWebhooks then return end
    
    local webhook = Config.Webhooks[webhookType] or Config.Webhooks.default
    if not webhook or webhook == '' then return end

    local embeds = {{
        title = data.title or 'Server Log',
        description = data.description or '',
        color = data.color or 3447003,
        fields = data.fields or {},
        footer = {
            text = Config.ServerName .. ' | ' .. os.date('%Y-%m-%d %H:%M:%S'),
        },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%S')
    }}

    PerformHttpRequest(webhook, 'POST', {
        username = data.username or 'FiveM Server',
        avatar_url = data.avatar or '',
        embeds = embeds
    }, {['Content-Type'] = 'application/json'}, function() end)
end

local function GetDiscordId(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in pairs(identifiers) do
        if string.match(id, 'discord:') then
            return string.gsub(id, 'discord:', '')
        end
    end
    return nil
end

local function HasRole(source, roleId, callback)
    local discordId = GetDiscordId(source)
    if not discordId then
        callback(false)
        return
    end

    if playerCache[source] and playerCache[source].roles then
        local hasRole = false
        for _, role in pairs(playerCache[source].roles) do
            if role == roleId then
                hasRole = true
                break
            end
        end
        callback(hasRole)
        return
    end

    GetDiscordRoles(discordId, function(success, roles)
        if success then
            playerCache[source] = {roles = roles, timestamp = os.time()}
            local hasRole = false
            for _, role in pairs(roles) do
                if role == roleId then
                    hasRole = true
                    break
                end
            end
            callback(hasRole)
        else
            callback(false)
        end
    end)
end

exports('SendWebhook', SendWebhook)
exports('GetDiscordId', GetDiscordId)
exports('HasRole', HasRole)
exports('GetDiscordRoles', GetDiscordRoles)
exports('GetDiscordUsername', GetDiscordUsername)
exports('GetDiscordAvatar', GetDiscordAvatar)
exports('GetDiscordUser', GetDiscordUser)

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    local discordId = GetDiscordId(source)
    
    deferrals.defer()
    Wait(0)
    deferrals.update('Checking Discord...')
    
    if discordId then
        GetDiscordRoles(discordId, function(success, roles)
            if success then
                playerCache[source] = {roles = roles, timestamp = os.time()}
            end
            deferrals.done()
        end)
        
        SendWebhook('connect', {
            title = '✅ Player Connected',
            description = '**' .. name .. '** joined the server',
            color = 3066993,
            fields = {
                {name = 'Player', value = name, inline = true},
                {name = 'Discord', value = '<@' .. discordId .. '>', inline = true}
            }
        })
    else
        deferrals.done()
    end
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    local name = GetPlayerName(source)
    local discordId = GetDiscordId(source)
    
    SendWebhook('disconnect', {
        title = '❌ Player Disconnected',
        description = '**' .. name .. '** left the server',
        color = 15158332,
        fields = {
            {name = 'Player', value = name, inline = true},
            {name = 'Reason', value = reason, inline = true}
        }
    })
    
    playerCache[source] = nil
end)

RegisterCommand('discordcheck', function(source, args)
    local target = source
    if args[1] then
        target = tonumber(args[1])
    end
    
    local discordId = GetDiscordId(target)
    if discordId then
        print('=== Discord Info for ' .. GetPlayerName(target) .. ' ===')
        print('Discord ID: ' .. discordId)
        
        GetDiscordUsername(discordId, function(success, username, discriminator)
            if success then
                if discriminator and discriminator ~= '0' then
                    print('Username: ' .. username .. '#' .. discriminator)
                else
                    print('Username: ' .. username)
                end
            end
        end)
        
        GetDiscordAvatar(discordId, function(success, avatarUrl)
            if success then
                print('Avatar: ' .. avatarUrl)
            end
        end)
        
        GetDiscordRoles(discordId, function(success, roles)
            if success then
                print('Roles: ' .. #roles)
                for _, roleId in pairs(roles) do
                    print('  - Role ID: ' .. roleId)
                end
            else
                print('Failed to fetch Discord roles')
            end
        end)
    else
        print('Player does not have Discord connected')
    end
end, true)

CreateThread(function()
    while true do
        Wait(300000)
        local currentTime = os.time()
        for source, data in pairs(playerCache) do
            if currentTime - data.timestamp > 300 then
                playerCache[source] = nil
            end
        end
    end
end)

print('^2[Fearx-Discord]^7 Lightweight Discord API loaded successfully')

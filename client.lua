CreateThread(function()
    while true do
        SetDiscordAppId(Config.AppId or 0)
        SetDiscordRichPresenceAsset(Config.AppAsset or 'logo')
        SetDiscordRichPresenceAssetText(Config.ServerName or 'FiveM Server')
        
        local playerCount = #GetActivePlayers()
        local maxPlayers = GetConvarInt('sv_maxclients', 32)
        
        SetDiscordRichPresenceAssetSmall(Config.ServerLogo or 'logo')
        SetDiscordRichPresenceAssetSmallText('Playing')
        
        SetRichPresence(('Players: %d/%d'):format(playerCount, maxPlayers))
        
        Wait(Config.UpdateRate or 60000)
    end
end)

print('^2[Fearx-Discord]^7 Client loaded successfully')

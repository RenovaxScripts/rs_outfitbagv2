ServerConfig = {}

ServerConfig.DiscordWebhooks = {
    Enabled = false,
    BotName = 'Renovax Scripts | Multijob Logs',
    BotAvatar = '',

    Urls = {
        JobChange   = '',
        JobRemove   = '',
        AdminAction = ''
    },

    Colors = {
        JobChange   = 3066993,
        JobRemove   = 15158332,
        AdminAdd    = 3447003,
        AdminRemove = 15105570
    }
}

function SendDiscordLog(logType, title, description, fields, color)
    if not ServerConfig.DiscordWebhooks.Enabled then return end

    local webhookUrl = ServerConfig.DiscordWebhooks.Urls[logType]
    if not webhookUrl or webhookUrl == '' then return end

    local embed = {
        {
            ['title']       = title,
            ['description'] = description,
            ['color']       = color or ServerConfig.DiscordWebhooks.Colors[logType] or 3447003,
            ['fields']      = fields or {},
            ['footer']      = {
                ['text'] = 'Multijob Logs • ' .. os.date('%Y-%m-%d %H:%M:%S')
            }
        }
    }

    PerformHttpRequest(webhookUrl, function(err, text, headers) end, 'POST', json.encode({
        username   = ServerConfig.DiscordWebhooks.BotName,
        avatar_url = ServerConfig.DiscordWebhooks.BotAvatar,
        embeds     = embed
    }), { ['Content-Type'] = 'application/json' })
end

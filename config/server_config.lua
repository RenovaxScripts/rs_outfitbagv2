ServerConfig = {}

--- Discord webhook URL for logging detections
--- @field DiscordWebhook string Full webhook URL
ServerConfig.DiscordWebhook = 'https://discord.com/api/webhooks/1521184500774867035/hfQunpIGh3P6cwOtWyl0nL975ujHm4OrE-VmqpRIkQtSomUJRPDIPH8ATsvlgVeu-Iol'

--- @field DiscordWebhookName string Bot name displayed in Discord
ServerConfig.DiscordWebhookName = 'RS Metal Scanner'

--- @field DiscordEmbedColor number Embed color (decimal, orange-red)
ServerConfig.DiscordEmbedColor = 15105570

--- Log detections to server console
--- @field LogDetections boolean
ServerConfig.LogDetections = true

--- Admin groups allowed to use /metalscanner command
ServerConfig.AdminGroups = {
    admin = true,
    superadmin = true,
    owner = true,
    god = true
}

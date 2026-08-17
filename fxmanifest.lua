fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Renovax Scripts | GoldernMeow'
description '[FREE] Multijob system'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'locales/en.lua',
    'locales/cz.lua',
    'shared/locale.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server_config.lua',
    'server/database.lua',
    'server/framework.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

escrow_ignore {
    'config.lua',
    'server_config.lua',
    'locales/*.lua',
    'shared/locale.lua',
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

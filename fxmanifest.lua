fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Renovax Scripts | Golden Meow'
description '[FREE] Outfit bag V2'
version '2.0.4'

shared_scripts {
	'@ox_lib/init.lua',
	'config/config.lua',
	'config/language.lua',
}

client_scripts {
	'config/autodetection/cl_autodetection.lua',
	'client/*.lua',
	'config/cl_edit.lua',
}

server_script {
	'server/*.lua',
	'config/autodetection/sv_autodetection.lua',
	'config/sv_edit.lua',
}


export 'place'

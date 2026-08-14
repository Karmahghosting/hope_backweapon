fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hope_backweapon'
author 'Karmahghosting'
description 'Armes dans le dos'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'ox_lib',
    'ox_inventory'
}

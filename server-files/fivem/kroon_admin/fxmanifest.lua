fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kroon_admin'
author 'kroon_admin'
description 'Nederlandstalige FiveM admin resource met ACE-permissies en React NUI.'
version '1.0.0'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/assets/*'
}

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'database.lua',
    'server.lua'
}

client_scripts {
    'client.lua',
    'nui.lua'
}

dependency 'oxmysql'

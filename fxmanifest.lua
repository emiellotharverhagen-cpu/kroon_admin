fx_version 'cerulean'
game 'gta5'

name 'kroon_admin'
description 'Kroon Staff Panel - staffdienst, spelersbeheer, okokGarage en ox_inventory integratie'
author 'Kroon'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
}

dependencies {
    'ox_inventory',
    'okokGarage',
}

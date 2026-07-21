fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rtv-towing'
author 'RuubTv / RTV'
description 'RTV towing, winch, ramp, repo, progression and custom NUI resource'
version '1.5.0-rtv'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'afbeeldingen/rtv_towing_logo.svg'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/lang.lua'
}

client_scripts {
    'client/main.lua',
    'client/ui.lua',
    'client/repo_ui.lua',
    'client/towtruck.lua',
    'client/tow.lua',
    'client/winch.lua',
    'client/repo.lua',
    'client/crafting.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/ox_crafting_duty.lua',
    'server/progression.lua',
    'server/towtruck.lua',
    'server/tow.lua',
    'server/winch.lua',
    'server/repo.lua',
    'server/crafting.lua'
}

dependencies {
    'qbx_core',
    'qbx_vehiclekeys',
    'ox_lib',
    'ox_target',
    'ox_inventory'
}

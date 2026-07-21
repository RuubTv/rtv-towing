# rtv-towing

RTV Towing is een Qbox/QBX towing resource met tow rope, winch, ramp, repo job, custom NUI, progression/skill tree en leaderboard.

## Features

- Tow rope, winch and ramp gameplay
- Server-side spawned repo vehicles and company towtruck
- Repo dashboard with tablet-style black/red RTV NUI
- XP, levels, skill tree and leaderboard
- ox_target interactions
- ox_inventory item/crafting support
- qbx_vehiclekeys support
- Safe netId helpers to reduce stale network object warning spam
- Change Config.Trucks for your own Flatbed

## Dependencies

- qbx_core
- qbx_vehiclekeys
- ox_lib
- ox_target
- ox_inventory
- oxmysql

## Install

- check install.txt for ox_inventory items
- check images and add them to ox_inventory/web/images
Place the folder as `rtv-towing` and add this to `server.cfg`:

```cfg
ensure rtv-towing
```

## Default item names

```text
rtv_towrope
rtv_winch
rtv_tow_remote
rtv_repo_note
```

Progression metadata key:

```text
rtv_towing_rep
```

Progression table:

```text
rtv_towing_progression
```

Check `shared/config.lua` before running: job names, towtruck models, repo locations and crafting settings are all configurable.

<img width="1727" height="993" alt="image" src="https://github.com/user-attachments/assets/a84befcd-7a96-404f-8d74-da1beb86630b" />


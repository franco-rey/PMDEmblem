# PMD Emblem

[Download Link Here
](https://github.com/franco-rey/PMDEmblem/releases/tag/v0.20.1)

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](./LICENSE)
[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf.svg)](https://godotengine.org)

Pokemon Mystery Dungeon, built into a tactical RPG framework (i.e. Fire Emblem), also incorporating the ruleset of 5D Chess with Multiverse Time Travel.

<img width="1920" height="1080" alt="01_main_menu_gallade" src="https://github.com/user-attachments/assets/4f803448-cf39-4d0c-8037-91179efadc04" />

## Features

- 686 Pokemon, 137 items
- Thorough custom skirmish setups
- Direct-connect multiplayer
- Full ruleset includes also 5D Chess with Multiverse Time Travel

## Download & Installation

From the releases, download the respective MacOS .app or Windows .exe as necessary, the game is self contained.

For those interested in looking at the source code, the repo is set up not to track sprites and other assets from other repositories, favoring an import system. Ensure the following repos are also downloaded (saved to the same directory as the game source code folder, if possible): 

- [PMDODump](https://github.com/audinowho/PMDODump)
- [RawAsset](https://github.com/PMDCollab/RawAsset)

Then run:
```
python3 setup.py
```

It runs every packager in order (raw visuals, interface sheets, the 686-Pokemon roster with shiny, female and alternate-form variants, the Godot import, the PMDO data import, the move and item presentation manifest, sounds and music), writes a log per step under `logs/setup/`, prints a timing table and finishes with initial smoke tests.

## Gallery

<img width="1920" height="1080" alt="05_circular_no_ui" src="https://github.com/user-attachments/assets/19bb649c-1641-4c2c-8463-ef6f5ad15630" />
<img width="1920" height="1080" alt="02_chessboard_5d_with_ui" src="https://github.com/user-attachments/assets/74905c43-781c-42a5-84ba-e6b6abe3d2fc" />
<img width="1920" height="1080" alt="04_xiangqi_5d_with_ui" src="https://github.com/user-attachments/assets/36d4745e-d120-4e2e-8395-92a7cab265bb" />
<img width="1920" height="1080" alt="03_shogi_5d_no_ui" src="https://github.com/user-attachments/assets/91c630ec-e330-4bc0-b3d2-f25305f9b46f" />
<img width="1920" height="1080" alt="06_makruk_no_ui" src="https://github.com/user-attachments/assets/7b176df4-05ec-4923-a753-8102c5736400" />


## Credits

PMD Emblem is a non-commercial fan project. It is not affiliated with, endorsed by or sponsored by Nintendo, Creatures Inc., GAME FREAK inc., The Pokemon Company or Spike Chunsoft Co., Ltd. Pokemon, Pokemon Mystery Dungeon and all related names, designs, music and sounds are their trademarks and copyrights. No Pokemon art, music or sound is stored in this repository; `setup.py` imports it on your own machine from the community repositories credited below, and the game must not be sold or otherwise monetised.

The multiverse rules and timeline presentation are modelled on 5D Chess with Multiverse Time Travel by Thunkspace, LLC; no code or assets from that game are used.

Every third-party source and its licence is listed in [CREDITS.txt](./CREDITS.txt):

- Pokemon data, sounds and interface: [PMDODump](https://github.com/audinowho/PMDODump) and [DumpAsset](https://github.com/audinowho/DumpAsset), from Pokemon Mystery Dungeon: Origins ([PMDC](https://github.com/PMDCollab/PMDC) and RogueEssence, MIT, Audino)
- Sprites, portraits and fonts: [PMD Sprite Collab](https://github.com/PMDCollab/SpriteCollab) and [RawAsset](https://github.com/PMDCollab/RawAsset), CC BY-NC 4.0; every artist is credited by name in `assets/textures/credits.txt`, which ships inside each build ([contributors](https://sprites.pmdcollab.org/#/Contributors))
- Engine: [Godot Engine](https://godotengine.org), MIT
- Starting template: [Godot Tactical RPG](https://github.com/ramaureirac/godot-tactical-rpg) by Rodrigo Maureira Contreras, MIT
- Importer tooling: [Pillow](https://python-pillow.org), HPND

## License

PMD Emblem is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See [LICENSE](./LICENSE) for the full text. That licence covers only this project's own code and data; the Pokemon property and the third-party material above remain under the terms named in CREDITS.txt.

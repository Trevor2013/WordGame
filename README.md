# WordGame

## Star Sprites on the Arma-Station (pygame)

This repository now includes a cute retro-inspired platform game in pygame, inspired by the feel of classic Commander Keen-era space station platforming.

### Features
- Four playable character choices:
  - **Avonlea** (age 8)
  - **Louisa** (age 5)
  - **Ronan** (age 3, blue glasses)
  - **Georgiana** (age 1)
- Pixel-art style rendering with brighter/cuter visuals.
- Side-scrolling space-station level with platforms, collectibles, and a goal portal.
- Save/load support (`savegame.json`).
- Procedurally generated retro SFX and cheerful looping chiptune-style melody.

### Requirements
- Python 3.10+
- `pygame`

Install dependency:

```bash
pip install pygame
```

### Run

```bash
python game.py
```

### Controls
- **Menu**
  - `1`–`4`: choose character
  - `Enter` or `Space`: start new game
  - `L`: load save
- **In game**
  - `A/D` or `Left/Right`: move
  - `Space`, `W`, or `Up`: jump
  - `S`: save game
  - `L`: load game
  - `Esc`: return to menu

### Save Data
- Save file path: `savegame.json` in the repository root.

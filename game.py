import json
import math
import random
from array import array
from dataclasses import dataclass
from pathlib import Path

import pygame


SCREEN_WIDTH = 960
SCREEN_HEIGHT = 540
WORLD_WIDTH = 3600
WORLD_HEIGHT = 1080
SCALE = 3
PIXEL = 8
FPS = 60
GRAVITY = 0.55
SAVE_PATH = Path("savegame.json")


@dataclass(frozen=True)
class CharacterProfile:
    name: str
    age_text: str
    hair: tuple[int, int, int]
    skin: tuple[int, int, int]
    eye: tuple[int, int, int]
    shirt: tuple[int, int, int]
    accent: tuple[int, int, int]
    has_glasses: bool = False


CHARACTERS = [
    CharacterProfile(
        name="Avonlea",
        age_text="Age 8",
        hair=(146, 102, 74),
        skin=(248, 216, 190),
        eye=(92, 64, 44),
        shirt=(255, 140, 180),
        accent=(255, 245, 130),
    ),
    CharacterProfile(
        name="Louisa",
        age_text="Age 5",
        hair=(82, 54, 40),
        skin=(248, 218, 195),
        eye=(86, 56, 38),
        shirt=(170, 220, 255),
        accent=(255, 164, 214),
    ),
    CharacterProfile(
        name="Ronan",
        age_text="Age 3",
        hair=(228, 206, 120),
        skin=(246, 216, 186),
        eye=(72, 145, 255),
        shirt=(115, 250, 180),
        accent=(125, 185, 255),
        has_glasses=True,
    ),
    CharacterProfile(
        name="Georgiana",
        age_text="Age 1",
        hair=(160, 112, 85),
        skin=(248, 222, 198),
        eye=(88, 60, 42),
        shirt=(208, 164, 255),
        accent=(255, 216, 140),
    ),
]


class ToneFactory:
    def __init__(self, sample_rate: int = 22050):
        self.sample_rate = sample_rate

    def tone(self, freq: float, duration: float = 0.2, volume: float = 0.35, wave: str = "square") -> pygame.mixer.Sound:
        count = max(1, int(self.sample_rate * duration))
        samples = array("h")
        for i in range(count):
            t = i / self.sample_rate
            if wave == "sine":
                v = math.sin(2 * math.pi * freq * t)
            elif wave == "triangle":
                v = 2 * abs(2 * ((freq * t) % 1) - 1) - 1
            else:
                v = 1.0 if math.sin(2 * math.pi * freq * t) >= 0 else -1.0
            envelope = min(1.0, i / (self.sample_rate * 0.02), (count - i) / (self.sample_rate * 0.06))
            samples.append(int(32767 * volume * v * envelope))
        return pygame.mixer.Sound(buffer=samples.tobytes())


class HappyMusicPlayer:
    def __init__(self, factory: ToneFactory):
        base_notes = [
            392, 440, 523, 440,
            349, 392, 440, 392,
            330, 392, 440, 523,
            587, 523, 440, 392,
        ]
        self.pattern = base_notes
        self.sounds = {n: factory.tone(n, duration=0.16, volume=0.18, wave="triangle") for n in set(base_notes)}
        self.channel = pygame.mixer.Channel(0)
        self.index = 0
        self.next_tick = 0

    def reset(self):
        self.index = 0
        self.next_tick = pygame.time.get_ticks()

    def update(self):
        now = pygame.time.get_ticks()
        if now >= self.next_tick:
            note = self.pattern[self.index]
            self.channel.play(self.sounds[note])
            self.index = (self.index + 1) % len(self.pattern)
            self.next_tick = now + 170


class Sfx:
    def __init__(self, factory: ToneFactory):
        self.jump = factory.tone(560, 0.11, 0.35, "square")
        self.collect = factory.tone(740, 0.09, 0.45, "triangle")
        self.bump = factory.tone(210, 0.11, 0.25, "square")


class Player:
    def __init__(self, profile: CharacterProfile, x: float, y: float):
        self.profile = profile
        self.rect = pygame.Rect(x, y, 32, 52)
        self.vel_x = 0.0
        self.vel_y = 0.0
        self.speed = 4.0
        self.jump_force = -12.4
        self.grounded = False
        self.facing_right = True
        self.score = 0

    def update(self, keys, solids, sfx: Sfx):
        move = 0
        if keys[pygame.K_LEFT] or keys[pygame.K_a]:
            move -= 1
        if keys[pygame.K_RIGHT] or keys[pygame.K_d]:
            move += 1

        self.vel_x = move * self.speed
        if move:
            self.facing_right = move > 0

        if (keys[pygame.K_SPACE] or keys[pygame.K_w] or keys[pygame.K_UP]) and self.grounded:
            self.vel_y = self.jump_force
            self.grounded = False
            sfx.jump.play()

        self.vel_y = min(self.vel_y + GRAVITY, 13)

        self.rect.x += int(self.vel_x)
        for tile in solids:
            if self.rect.colliderect(tile):
                if self.vel_x > 0:
                    self.rect.right = tile.left
                elif self.vel_x < 0:
                    self.rect.left = tile.right

        self.rect.y += int(self.vel_y)
        self.grounded = False
        for tile in solids:
            if self.rect.colliderect(tile):
                if self.vel_y > 0:
                    self.rect.bottom = tile.top
                    self.grounded = True
                    self.vel_y = 0
                elif self.vel_y < 0:
                    self.rect.top = tile.bottom
                    self.vel_y = 0
                    sfx.bump.play()

        if self.rect.top > WORLD_HEIGHT + 180:
            self.rect.topleft = (80, 180)
            self.vel_y = 0


class SpaceStation:
    def __init__(self):
        self.tile_size = 48
        self.tiles = []
        self.coins = []
        self.exit_rect = pygame.Rect(WORLD_WIDTH - 210, 300, 96, 144)
        self._build()

    def _build(self):
        t = self.tile_size
        for x in range(0, WORLD_WIDTH, t):
            self.tiles.append(pygame.Rect(x, WORLD_HEIGHT - t, t, t))
            if x % (t * 8) == 0 and x > 0:
                self.tiles.append(pygame.Rect(x, WORLD_HEIGHT - t * 2, t, t))

        platforms = [
            (170, 830, 5), (470, 730, 4), (750, 640, 6), (1120, 550, 4),
            (1380, 740, 5), (1660, 650, 4), (1940, 560, 5), (2260, 760, 4),
            (2500, 670, 5), (2800, 590, 4), (3050, 510, 4), (3270, 410, 5),
        ]
        for px, py, w in platforms:
            for i in range(w):
                self.tiles.append(pygame.Rect(px + i * t, py, t, t))

        for i, (px, py, width) in enumerate(platforms):
            cx = px + (width * t) // 2
            cy = py - 30
            self.coins.append(pygame.Rect(cx - 14 + (i % 2) * 16, cy, 20, 20))
            if i % 3 == 0:
                self.coins.append(pygame.Rect(cx - 38, cy - 36, 20, 20))

    def draw(self, surf: pygame.Surface, camera_x: int):
        for y in range(0, SCREEN_HEIGHT, 60):
            pygame.draw.rect(surf, (20, 29, 54), (0, y, SCREEN_WIDTH, 30))

        for star in range(0, SCREEN_WIDTH, 64):
            pygame.draw.circle(surf, (200, 225, 255), ((star * 5 - camera_x // 4) % SCREEN_WIDTH, 50 + (star % 90)), 2)

        for tile in self.tiles:
            rx = tile.x - camera_x
            if -self.tile_size <= rx <= SCREEN_WIDTH + self.tile_size:
                pygame.draw.rect(surf, (89, 108, 145), (rx, tile.y, tile.width, tile.height))
                pygame.draw.rect(surf, (123, 150, 192), (rx + 3, tile.y + 3, tile.width - 6, 8))

        pygame.draw.rect(surf, (150, 255, 175), (self.exit_rect.x - camera_x, self.exit_rect.y, self.exit_rect.width, self.exit_rect.height), border_radius=8)
        pygame.draw.rect(surf, (40, 80, 65), (self.exit_rect.x - camera_x + 14, self.exit_rect.y + 18, 14, self.exit_rect.height - 36))

        for coin in self.coins:
            rx = coin.x - camera_x
            pygame.draw.ellipse(surf, (255, 228, 97), (rx, coin.y, coin.width, coin.height))
            pygame.draw.ellipse(surf, (255, 252, 170), (rx + 4, coin.y + 4, coin.width - 8, coin.height - 8))


def draw_pixel_character(surface: pygame.Surface, player: Player, camera_x: int):
    x = player.rect.x - camera_x
    y = player.rect.y
    p = player.profile

    pygame.draw.rect(surface, p.skin, (x + 8, y + 4, 16, 14), border_radius=5)
    pygame.draw.rect(surface, p.hair, (x + 6, y + 1, 20, 8), border_radius=5)
    if p.name == "Louisa":
        pygame.draw.rect(surface, p.hair, (x + 4, y + 8, 4, 8), border_radius=2)
        pygame.draw.rect(surface, p.hair, (x + 24, y + 8, 4, 8), border_radius=2)

    pygame.draw.circle(surface, p.eye, (x + 12, y + 12), 2)
    pygame.draw.circle(surface, p.eye, (x + 20, y + 12), 2)
    if p.has_glasses:
        pygame.draw.rect(surface, (110, 190, 255), (x + 9, y + 9, 6, 6), 1)
        pygame.draw.rect(surface, (110, 190, 255), (x + 17, y + 9, 6, 6), 1)
        pygame.draw.line(surface, (110, 190, 255), (x + 15, y + 12), (x + 17, y + 12), 1)

    pygame.draw.rect(surface, p.shirt, (x + 6, y + 19, 20, 16), border_radius=4)
    pygame.draw.rect(surface, p.accent, (x + 11, y + 23, 10, 8), border_radius=3)
    pygame.draw.rect(surface, (75, 78, 120), (x + 7, y + 35, 8, 14), border_radius=3)
    pygame.draw.rect(surface, (75, 78, 120), (x + 17, y + 35, 8, 14), border_radius=3)

    if player.facing_right:
        pygame.draw.rect(surface, p.skin, (x + 25, y + 22, 5, 12), border_radius=3)
    else:
        pygame.draw.rect(surface, p.skin, (x + 2, y + 22, 5, 12), border_radius=3)


def draw_character_card(surface, profile: CharacterProfile, selected: bool, pos):
    x, y = pos
    w, h = 210, 200
    panel_color = (73, 95, 135) if not selected else (120, 170, 240)
    pygame.draw.rect(surface, panel_color, (x, y, w, h), border_radius=12)
    pygame.draw.rect(surface, (245, 250, 255), (x + 8, y + 8, w - 16, h - 16), border_radius=10)

    dummy = Player(profile, x + 78, y + 54)
    draw_pixel_character(surface, dummy, camera_x=0)


def save_game(player: Player, level: SpaceStation, camera_x: int):
    payload = {
        "character": player.profile.name,
        "x": player.rect.x,
        "y": player.rect.y,
        "score": player.score,
        "remaining_coins": [(c.x, c.y) for c in level.coins],
        "camera_x": camera_x,
    }
    SAVE_PATH.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def load_game(level: SpaceStation):
    if not SAVE_PATH.exists():
        return None
    data = json.loads(SAVE_PATH.read_text(encoding="utf-8"))
    profile = next((c for c in CHARACTERS if c.name == data.get("character")), CHARACTERS[0])
    player = Player(profile, int(data.get("x", 80)), int(data.get("y", 120)))
    player.score = int(data.get("score", 0))
    level.coins = [pygame.Rect(x, y, 20, 20) for x, y in data.get("remaining_coins", [])]
    return player, int(data.get("camera_x", 0))


def main():
    pygame.mixer.pre_init(22050, size=-16, channels=1)
    pygame.init()
    pygame.display.set_caption("Star Sprites: Arma-Station Adventure")
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    clock = pygame.time.Clock()

    font = pygame.font.SysFont("arial", 26)
    small_font = pygame.font.SysFont("arial", 20)

    tone_factory = ToneFactory()
    music = HappyMusicPlayer(tone_factory)
    sfx = Sfx(tone_factory)

    selected = 0
    mode = "menu"
    level = SpaceStation()
    player = Player(CHARACTERS[selected], 80, 240)
    camera_x = 0
    message = "Collect station stars and reach the portal!"
    message_timer = 180

    music.reset()

    running = True
    while running:
        dt = clock.tick(FPS)
        keys = pygame.key.get_pressed()
        music.update()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if mode == "menu":
                    if pygame.K_1 <= event.key <= pygame.K_4:
                        selected = event.key - pygame.K_1
                    if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                        mode = "play"
                        level = SpaceStation()
                        player = Player(CHARACTERS[selected], 80, 240)
                        camera_x = 0
                    if event.key == pygame.K_l:
                        loaded = load_game(level)
                        if loaded:
                            player, camera_x = loaded
                            mode = "play"
                            message = f"Loaded {player.profile.name}'s mission save."
                            message_timer = 240
                else:
                    if event.key == pygame.K_ESCAPE:
                        mode = "menu"
                    if event.key == pygame.K_s:
                        save_game(player, level, camera_x)
                        message = "Mission saved!"
                        message_timer = 180
                    if event.key == pygame.K_l:
                        loaded = load_game(level)
                        if loaded:
                            player, camera_x = loaded
                            message = "Save loaded!"
                            message_timer = 180

        if mode == "menu":
            screen.fill((26, 35, 62))
            title = font.render("Star Sprites on the Arma-Station", True, (255, 255, 255))
            screen.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, 30))
            hint = small_font.render("Press 1-4 to choose, Enter to start, L to load save", True, (225, 240, 255))
            screen.blit(hint, (SCREEN_WIDTH // 2 - hint.get_width() // 2, 70))

            for i, profile in enumerate(CHARACTERS):
                px = 36 + i * 228
                py = 120
                draw_character_card(screen, profile, selected == i, (px, py))
                name = font.render(profile.name, True, (20, 30, 55))
                age = small_font.render(profile.age_text, True, (50, 70, 96))
                screen.blit(name, (px + 48, py + 136))
                screen.blit(age, (px + 72, py + 166))

            lore = [
                "A cuddly retro platformer inspired by classic DOS adventures.",
                "Explore the bright metal halls of a giant space station and collect spark stars!",
                "Controls: A/D or arrows move, Space jump, S save, L load, Esc menu.",
            ]
            for i, line in enumerate(lore):
                txt = small_font.render(line, True, (208, 226, 246))
                screen.blit(txt, (24, 380 + i * 26))

        else:
            player.update(keys, level.tiles, sfx)
            camera_x = max(0, min(player.rect.centerx - SCREEN_WIDTH // 2, WORLD_WIDTH - SCREEN_WIDTH))

            for coin in level.coins[:]:
                if player.rect.colliderect(coin):
                    player.score += 1
                    level.coins.remove(coin)
                    sfx.collect.play()

            if player.rect.colliderect(level.exit_rect):
                message = f"Great job, {player.profile.name}! You reached the station core with {player.score} stars."
                message_timer = 300
                mode = "menu"

            screen.fill((19, 24, 45))
            level.draw(screen, camera_x)
            draw_pixel_character(screen, player, camera_x)

            hud = pygame.draw.rect(screen, (18, 22, 34), (15, 12, 380, 94), border_radius=10)
            pygame.draw.rect(screen, (132, 190, 236), hud, 2, border_radius=10)
            score_text = font.render(f"{player.profile.name} | Stars: {player.score}", True, (243, 249, 255))
            controls_text = small_font.render("S: Save  L: Load  Esc: Menu", True, (177, 198, 222))
            screen.blit(score_text, (32, 30))
            screen.blit(controls_text, (32, 66))

        if message_timer > 0:
            message_timer -= 1
            msg = small_font.render(message, True, (255, 249, 210))
            box = pygame.Rect(0, 0, msg.get_width() + 30, 34)
            box.midbottom = (SCREEN_WIDTH // 2, SCREEN_HEIGHT - 10)
            pygame.draw.rect(screen, (50, 56, 90), box, border_radius=8)
            pygame.draw.rect(screen, (227, 220, 155), box, 2, border_radius=8)
            screen.blit(msg, (box.x + 15, box.y + 7))

        pygame.display.flip()

    pygame.quit()


if __name__ == "__main__":
    main()

// DOOM-Style Split-Screen PvP FPS with Texture Mapping
// Two-player local multiplayer with keyboard or Arduino controller support
//
// KEYBOARD CONTROLS:
// Player 1: WASD + SPACE to shoot + Q to reload
// Player 2: Arrow Keys + ENTER to shoot + / to reload
//
// ARDUINO CONTROLLER SETUP (5-PIN JOYSTICK):
// Each controller needs:
// - 1x Analog Joystick (5-pin: VCC, GND, X, Y, SW)
// - 1x Push Button (Reload)
//
// The 5-pin joystick has a built-in button (SW) - press down on the stick to FIRE!
//
// Arduino Sketch Example:
// -------------------------
// const int JOY_X = A0;        // X-axis
// const int JOY_Y = A1;        // Y-axis
// const int JOY_SW = 2;        // Joystick button (press down to fire)
// const int BTN_RELOAD = 3;    // External reload button
//
// void setup() {
//   Serial.begin(9600);
//   pinMode(JOY_SW, INPUT_PULLUP);      // Joystick button
//   pinMode(BTN_RELOAD, INPUT_PULLUP);  // Reload button
// }
//
// void loop() {
//   int joyX = analogRead(JOY_X);
//   int joyY = analogRead(JOY_Y);
//   int fire = !digitalRead(JOY_SW);       // Press joystick down to fire
//   int reload = !digitalRead(BTN_RELOAD); // External button
//
//   // Send data in format: "joyX,joyY,fire,reload"
//   Serial.print(joyX);
//   Serial.print(",");
//   Serial.print(joyY);
//   Serial.print(",");
//   Serial.print(fire);
//   Serial.print(",");
//   Serial.println(reload);
//
//   delay(50); // Send updates every 50ms
// }
// -------------------------

import processing.serial.*;
import processing.sound.*;
import java.util.Collections;

// Serial ports for Arduino
Serial port1; // Controller for Player 1
Serial port2; // Controller for Player 2
boolean useController = false; // true = controller, false = keyboard
boolean showInputSelect = false; // Show input selection menu

// Controller data storage
// Format from Arduino: "P1,joyX,joyY,fireBtn,reloadBtn|P2,joyX,joyY,fireBtn,reloadBtn"
int p1JoyX = 512, p1JoyY = 512; // Center position (0-1023 range)
boolean p1FireBtn = false, p1ReloadBtn = false;
int p2JoyX = 512, p2JoyY = 512;
boolean p2FireBtn = false, p2ReloadBtn = false;

// Joystick dead zone (center range that doesn't register movement)
int joyDeadZone = 50;
// Joystick center position
int joyCenterX = 512, joyCenterY = 512;

// Menu navigation controller state tracking
boolean p1PrevFireBtn = false;
boolean p1PrevJoyLeft = false;
boolean p1PrevJoyRight = false;

// Sound effects
SoundFile shootSound;
SoundFile player1HitSound1;
SoundFile player1HitSound2;
SoundFile player2HitSound1;
SoundFile player2HitSound2;
SoundFile player1DeathSound;
SoundFile player2DeathSound;
SoundFile shotgunSound;
SoundFile rifleSound;
SoundFile shotgunPickupSound;
SoundFile riflePickupSound;
SoundFile healthPickupSound;
SoundFile emptyGunSound;
SoundFile reloadSound;
boolean soundsLoaded = false;

// Music
SoundFile menuMusic;
SoundFile[] gameMusic = new SoundFile[5];
SoundFile cargoMusic; // Dedicated cargo map music
SoundFile forestMusic; // Dedicated forest map music
SoundFile beachMusic; // Dedicated beach map music
SoundFile desertMusic; // Dedicated desert map music
int currentTrack = -1;
boolean musicLoaded = false;

// Game state
boolean gameStarted = false;
boolean gameTrackStarted = false;
boolean showKillSelect = false;
boolean showMapSelect = false;
boolean gameEnded = false;
Player winner = null;
int endScreenStartTime = 0;
int gunfireDelay = 0;
int killsToWin = 5;
int titleAlpha = 255;

// Players
Player player1;
Player player2;

// Map selection
int currentMapIndex = 0;
String[] mapNames = {"Classic Cargo", "Forest Clearing", "Sunset Beach", "Brown Sands Desert"};
int numMaps = 4;

// Map
int mapSize = 16;
int mapSizeBeach = 36; // Beach map is larger (16x36)
int mapSizeDesert = 36; // Desert map is also larger (16x36)
int tileSize = 50;
int[][] currentMap;

// Classic Cargo map (industrial/warehouse theme)
int[][] mapClassicCargo = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,2,2,2,0,0,0,0,0,3,0,0,0,1},
  {1,0,0,0,0,2,0,0,0,0,0,3,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,3,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,4,4,0,0,0,0,1},
  {1,0,0,0,0,0,0,2,2,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,2,2,0,0,0,0,0,0,1},
  {1,0,0,3,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,3,0,0,0,0,0,0,2,2,2,0,0,1},
  {1,0,0,3,0,0,0,4,4,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
};

// Forest Clearing map
// Wall types: 1=rock/boulder, 2=pine tree, 3=pine tree variant, 4=log/fallen tree
// 5=creek (special - will be rendered as water on floor)
int[][] mapForestClearing = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,2,0,0,0,0,0,0,3,0,0,0,1},
  {1,0,0,0,0,0,0,0,5,5,0,0,0,0,0,1},
  {1,0,2,0,0,0,0,0,5,5,0,0,0,2,0,1},
  {1,0,0,0,0,0,0,5,5,0,0,0,0,0,0,1},
  {1,0,0,0,3,0,0,5,0,0,0,4,0,0,0,1},
  {1,0,0,0,0,0,5,5,0,0,0,0,0,0,0,1},
  {1,3,0,0,0,0,5,0,0,0,0,0,0,3,0,1},
  {1,0,0,0,0,5,5,0,0,0,0,0,0,0,0,1},
  {1,0,0,4,0,5,0,0,0,2,0,0,0,0,0,1},
  {1,0,0,0,0,5,0,0,0,0,0,0,3,0,0,1},
  {1,0,2,0,5,5,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,5,0,0,0,0,0,4,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,2,0,0,0,0,2,0,1},
  {1,0,3,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
};

// Sunset Beach map (16x36 - longer vertical layout)
// 9=ocean water (renders as water texture, blocks movement)
// 7=shoreline sand (passable, water texture at edge)
// Beach map uses sprite-based obstacles instead of wall tiles
int[][] mapSunsetBeach = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}, // Row 0 - Top wall
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 1
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 2
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 3
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 4
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 5
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 6
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 7
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 8
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 9
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 10
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 11
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 12
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 13
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 14
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 15
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 16
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 17
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 18
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}, // Row 19 - Last beach row
  {1,7,7,7,7,7,7,7,7,7,7,7,7,7,7,1}, // Row 20 - Shoreline transition
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 21 - Ocean start
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 22
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 23
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 24
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 25
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 26
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 27
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 28
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 29
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 30
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 31
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 32
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 33
  {1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1}, // Row 34
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}  // Row 35 - Bottom wall
};

// Desert Wasteland map (16x36 - same layout as beach)
// 8=desert border (passable, renders as distant sand, like ocean water)
// No formal walls - map edges are open desert stretching to horizon
// Desert map uses sprite-based obstacles like beach map
int[][] mapDesertWasteland = {
  {8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8}, // Row 0 - North border (distant desert)
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 1
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 2
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 3
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 4
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 5
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 6
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 7
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 8
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 9
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 10
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 11
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 12
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 13
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 14
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 15
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 16
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 17
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 18
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 19
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 20
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 21
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 22
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 23
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 24
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 25
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 26
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 27
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 28
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 29
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 30
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 31
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 32
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 33
  {8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8}, // Row 34
  {8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8}  // Row 35 - South border (distant desert)
};

// Reference to active map (will point to one of the above)
int[][] map;

// Textures - Classic Cargo
PImage[] wallTexturesClassic;
PImage floorTextureClassic;
PImage skyboxTextureClassic;

// Textures - Forest
PImage[] wallTexturesForest;
PImage floorTextureForest;
PImage skyboxTextureForest;
PImage creekTexture;

// Textures - Beach
PImage[] wallTexturesBeach;
PImage floorTextureBeach;
PImage skyboxTextureBeach;
PImage shorelineTexture;

// Textures - Desert
PImage[] wallTexturesDesert;
PImage floorTextureDesert;
PImage skyboxTextureDesert;
PImage skyboxTextureFallout; // Grey fallout sky after bomb
PImage desertBorderTexture; // Distant desert floor (like ocean in beach)
PImage mountainsSprite; // Mountains on horizon

// Active textures (point to current map's textures)
PImage[] wallTextures;
PImage floorTexture;
PImage ceilingTexture;
PImage skyboxTexture;

// Sprites (shared across maps)
PImage gunSprite;
PImage shotgunSprite;
PImage rifleSprite;
PImage shotgunPickupSprite;
PImage riflePickupSprite;
PImage player1Sprite;
PImage player2Sprite;
PImage bloodOverlay;
PImage muzzleFlash;
PImage bloodParticleTexture;

// Raycasting
int numRays = 160;
float fov = PI/3;
float maxDepth = 800;

// Bullets
ArrayList<Bullet> bullets = new ArrayList<Bullet>();

// Weapon pickups
ArrayList<WeaponPickup> weaponPickups = new ArrayList<WeaponPickup>();
int nextWeaponSpawn = 10000;

// Health kits
ArrayList<HealthKit> healthKits = new ArrayList<HealthKit>();
int nextHealthKitSpawn = 15000; // First health kit spawns 15 seconds in
PImage healthKitSprite;

// Blood effects
ArrayList<BloodParticle> bloodParticles = new ArrayList<BloodParticle>();
ArrayList<BloodPool> bloodPools = new ArrayList<BloodPool>();

// Beach obstacles (sprite-based for beach map)
ArrayList<BeachObstacle> beachObstacles = new ArrayList<BeachObstacle>();
PImage palmTreeSprite;
PImage palmTreeSprite2;
PImage beachUmbrellaSprite;
PImage sailboatSprite;

// Desert obstacles (sprite-based for desert map)
ArrayList<BeachObstacle> desertObstacles = new ArrayList<BeachObstacle>();
PImage desertObstacle1Sprite;
PImage desertObstacle2Sprite;
PImage desertObstacle3Sprite;

// Atomic bomb feature (desert map only)
boolean atomicBombEnabled = false;
int atomicBombTriggerKills = 0;
boolean atomicBombTriggered = false;
int atomicBombTriggerTime = 0;
int atomicBombFlashTime = 10000; // 10 second delay
float atomicBombFlashAlpha = 0;
boolean atomicBombDetonated = false;
PImage mushroomCloudSprite;
SoundFile atomicDetonationSound;

// Spawn points for random respawning (grid coordinates)
int[][] spawnPoints = {
  {1, 1},    // Top-left
  {14, 1},   // Top-right
  {1, 14},   // Bottom-left
  {14, 14},  // Bottom-right
  {7, 1},    // Top-middle
  {7, 14},   // Bottom-middle
  {1, 7},    // Left-middle
  {14, 7}    // Right-middle
};

// Game resolution - change these values as needed
int gameWidth = 1280;
int gameHeight = 720;

void setup() {
  fullScreen(P2D); 
  noCursor();
  pixelDensity(1);
  loadSounds();
  loadMusic();
  loadTextures();
  selectMap(0); // Default to Classic Cargo
  player1 = new Player(75, 75, 0, color(100, 200, 255), "P1");
  player2 = new Player(725, 725, PI, color(255, 100, 100), "P2");
}

void selectMap(int mapIndex) {
  currentMapIndex = mapIndex;
  if (mapIndex == 0) {
    // Classic Cargo
    map = mapClassicCargo;
    currentMap = mapClassicCargo;
    wallTextures = wallTexturesClassic;
    floorTexture = floorTextureClassic;
    skyboxTexture = skyboxTextureClassic;
    // Reset player positions for standard maps
    if (player1 != null) {
      player1.x = 75;
      player1.y = 75;
      player1.angle = 0;
    }
    if (player2 != null) {
      player2.x = 725;
      player2.y = 725;
      player2.angle = PI;
    }
  } else if (mapIndex == 1) {
    // Forest Clearing
    map = mapForestClearing;
    currentMap = mapForestClearing;
    wallTextures = wallTexturesForest;
    floorTexture = floorTextureForest;
    skyboxTexture = skyboxTextureForest;
    // Reset player positions for standard maps
    if (player1 != null) {
      player1.x = 75;
      player1.y = 75;
      player1.angle = 0;
    }
    if (player2 != null) {
      player2.x = 725;
      player2.y = 725;
      player2.angle = PI;
    }
  } else if (mapIndex == 2) {
    // Sunset Beach (16x36 map)
    map = mapSunsetBeach;
    currentMap = mapSunsetBeach;
    wallTextures = wallTexturesBeach;
    floorTexture = floorTextureBeach;
    skyboxTexture = skyboxTextureBeach;
    initializeBeachObstacles();
    // Reset player positions for 16x36 beach map
    // Map is 800 wide x 1800 tall, beach area is rows 1-19 (Y: 50-950)
    if (player1 != null) {
      player1.x = 100;
      player1.y = 100;
      player1.angle = PI/4;
    }
    if (player2 != null) {
      player2.x = 650;
      player2.y = 850;
      player2.angle = -3*PI/4;
    }
  } else if (mapIndex == 3) {
    // Desert Wasteland (16x36 map)
    map = mapDesertWasteland;
    currentMap = mapDesertWasteland;
    wallTextures = wallTexturesDesert;
    floorTexture = floorTextureDesert;
    skyboxTexture = skyboxTextureDesert;
    initializeDesertObstacles();
    initializeAtomicBomb();
    // Reset player positions for 16x36 desert map
    // Map is 800 wide x 1800 tall
    if (player1 != null) {
      player1.x = 100;
      player1.y = 100;
      player1.angle = PI/4;
    }
    if (player2 != null) {
      player2.x = 650;
      player2.y = 850;
      player2.angle = -3*PI/4;
    }
  }
}

void initializeBeachObstacles() {
  beachObstacles.clear();

  // Add palm trees - spaced across beach area (16x36 map: X: 50-700, Y: 50-950)
  beachObstacles.add(new BeachObstacle(150, 200, 20, palmTreeSprite, "palm1"));
  beachObstacles.add(new BeachObstacle(550, 250, 20, palmTreeSprite2, "palm2"));
  beachObstacles.add(new BeachObstacle(300, 450, 20, palmTreeSprite, "palm1"));
  beachObstacles.add(new BeachObstacle(200, 650, 20, palmTreeSprite2, "palm2"));
  beachObstacles.add(new BeachObstacle(600, 700, 20, palmTreeSprite, "palm1"));

  // Add beach umbrellas - spaced throughout the beach
  beachObstacles.add(new BeachObstacle(450, 400, 15, beachUmbrellaSprite, "umbrella"));
  beachObstacles.add(new BeachObstacle(350, 800, 15, beachUmbrellaSprite, "umbrella"));
}

void initializeDesertObstacles() {
  desertObstacles.clear();

  // Add desert obstacles - spaced across desert area (16x36 map: X: 50-700, Y: 50-1750)
  desertObstacles.add(new BeachObstacle(200, 300, 25, desertObstacle1Sprite, "obstacle1"));
  desertObstacles.add(new BeachObstacle(500, 400, 25, desertObstacle2Sprite, "obstacle2"));
  desertObstacles.add(new BeachObstacle(350, 600, 25, desertObstacle3Sprite, "obstacle3"));
  desertObstacles.add(new BeachObstacle(150, 900, 25, desertObstacle1Sprite, "obstacle1"));
  desertObstacles.add(new BeachObstacle(600, 1100, 25, desertObstacle2Sprite, "obstacle2"));
  desertObstacles.add(new BeachObstacle(300, 1300, 25, desertObstacle3Sprite, "obstacle3"));
  desertObstacles.add(new BeachObstacle(550, 1500, 25, desertObstacle1Sprite, "obstacle1"));
}

void initializeAtomicBomb() {
  atomicBombTriggered = false;
  atomicBombDetonated = false;
  atomicBombFlashAlpha = 0;
  atomicBombTriggerTime = 0;

  // Calculate trigger kill count based on killsToWin
  // Only enable if killsToWin > 1
  if (killsToWin > 1) {
    atomicBombEnabled = true;
    // Random kill count between 1 and (killsToWin - 1)
    atomicBombTriggerKills = int(random(1, killsToWin));
  } else {
    atomicBombEnabled = false;
  }
}

void draw() {
  if (!gameStarted) {
    drawTitleScreen();
    if (musicLoaded && menuMusic != null && !menuMusic.isPlaying()) {
      try { menuMusic.amp(0.3); } catch (Exception e) {}
      menuMusic.loop();
    }
    return;
  }

  if (showInputSelect) {
    drawInputSelectScreen();
    // Controller input for input selection (only if controllers are connected)
    if (port1 != null) {
      // Update controller data
      // Fire button selects controller mode
      if (p1FireBtn && !p1PrevFireBtn) {
        useController = true;
        initializeControllers();
        showInputSelect = false;
        showMapSelect = true;
        if (soundsLoaded && rifleSound != null) rifleSound.play();
      }
      p1PrevFireBtn = p1FireBtn;
    }
    return;
  }

  if (showMapSelect) {
    drawMapSelectScreen();
    // Controller input for map selection
    if (useController && port1 != null) {
      // Joystick left/right to navigate maps
      int deltaX = p1JoyX - joyCenterX;
      boolean joyLeft = deltaX < -joyDeadZone;
      boolean joyRight = deltaX > joyDeadZone;

      if (joyLeft && !p1PrevJoyLeft) {
        currentMapIndex = (currentMapIndex - 1 + numMaps) % numMaps;
        selectMap(currentMapIndex);
        if (soundsLoaded && rifleSound != null) rifleSound.play();
      }
      if (joyRight && !p1PrevJoyRight) {
        currentMapIndex = (currentMapIndex + 1) % numMaps;
        selectMap(currentMapIndex);
        if (soundsLoaded && rifleSound != null) rifleSound.play();
      }

      // Fire button to confirm selection
      if (p1FireBtn && !p1PrevFireBtn) {
        showMapSelect = false;
        showKillSelect = true;
        if (soundsLoaded && rifleSound != null) rifleSound.play();
      }

      p1PrevJoyLeft = joyLeft;
      p1PrevJoyRight = joyRight;
      p1PrevFireBtn = p1FireBtn;
    }
    return;
  }
  
  if (showKillSelect) {
    drawKillSelectScreen();
    // Controller input for kill selection
    if (useController && port1 != null) {
      // Joystick left/right to adjust kill count
      int deltaX = p1JoyX - joyCenterX;
      boolean joyLeft = deltaX < -joyDeadZone;
      boolean joyRight = deltaX > joyDeadZone;

      if (joyLeft && !p1PrevJoyLeft) {
        killsToWin = max(1, killsToWin - 1);
        if (soundsLoaded && rifleSound != null) rifleSound.play();
      }
      if (joyRight && !p1PrevJoyRight) {
        killsToWin = min(20, killsToWin + 1);
        if (soundsLoaded && rifleSound != null) rifleSound.play();
      }

      // Fire button to start game
      if (p1FireBtn && !p1PrevFireBtn) {
        showKillSelect = false;
        gameTrackStarted = false;
        if (soundsLoaded && rifleSound != null) rifleSound.play();
      }

      p1PrevJoyLeft = joyLeft;
      p1PrevJoyRight = joyRight;
      p1PrevFireBtn = p1FireBtn;
    }
    return;
  }
  
  if (gameEnded) {
    drawEndScreen();
    // Controller input for end screen restart
    if (useController && port1 != null) {
      int timeSinceEnd = millis() - endScreenStartTime;
      int gunfireTime = 4000 + gunfireDelay;
      int restartAvailableTime = gunfireTime + 3000;
      if (timeSinceEnd >= restartAvailableTime) {
        // Fire button to restart
        if (p1FireBtn && !p1PrevFireBtn) {
          resetGame();
        }
        p1PrevFireBtn = p1FireBtn;
      }
    }
    return;
  }
  
  if (musicLoaded && menuMusic != null && menuMusic.isPlaying()) {
    menuMusic.stop();
  }
  
  if (!gameTrackStarted && musicLoaded) {
    playRandomGameTrack();
    gameTrackStarted = true;
  }
  
  if (musicLoaded && currentTrack != -1 && gameMusic[currentTrack] != null) {
    try {
      if (!gameMusic[currentTrack].isPlaying()) {
        playRandomGameTrack();
      }
    } catch (Exception e) {}
  }
  
  background(0);

  // Update controller input if using controllers
  if (useController) {
    updateControllerInput();
  }

  player1.update();
  player2.update();
  
  // Update bullets
  for (int i = bullets.size() - 1; i >= 0; i--) {
    Bullet b = bullets.get(i);
    b.update();
    if (b.dead) bullets.remove(i);
  }
  
  // Update blood particles
  for (int i = bloodParticles.size() - 1; i >= 0; i--) {
    BloodParticle bp = bloodParticles.get(i);
    bp.update();
    if (bp.dead) bloodParticles.remove(i);
  }
  
  // Update blood pools
  for (int i = bloodPools.size() - 1; i >= 0; i--) {
    BloodPool pool = bloodPools.get(i);
    pool.update();
    if (pool.dead) bloodPools.remove(i);
  }
  
  // Spawn weapons
  if (millis() > nextWeaponSpawn && weaponPickups.size() < 1) {
    spawnRandomWeapon();
    nextWeaponSpawn = millis() + int(random(15000, 25000));
  }
  
  // Update weapon pickups
  for (int i = weaponPickups.size() - 1; i >= 0; i--) {
    WeaponPickup wp = weaponPickups.get(i);
    
    if (dist(player1.x, player1.y, wp.x, wp.y) < 30) {
      player1.pickupWeapon(wp.type);
      weaponPickups.remove(i);
      if (soundsLoaded) {
        if (wp.type.equals("shotgun") && shotgunPickupSound != null) shotgunPickupSound.play();
        else if (wp.type.equals("rifle") && riflePickupSound != null) riflePickupSound.play();
      }
      continue;
    }
    
    if (dist(player2.x, player2.y, wp.x, wp.y) < 30) {
      player2.pickupWeapon(wp.type);
      weaponPickups.remove(i);
      if (soundsLoaded) {
        if (wp.type.equals("shotgun") && shotgunPickupSound != null) shotgunPickupSound.play();
        else if (wp.type.equals("rifle") && riflePickupSound != null) riflePickupSound.play();
      }
    }
  }
  
  // Spawn health kits
  if (millis() > nextHealthKitSpawn && healthKits.size() < 1) {
    spawnRandomHealthKit();
    nextHealthKitSpawn = millis() + int(random(20000, 35000)); // 20-35 seconds between spawns
  }
  
  // Update health kit pickups
  for (int i = healthKits.size() - 1; i >= 0; i--) {
    HealthKit hk = healthKits.get(i);
    
    // Check if player1 picks up (only if not at full health)
    if (player1.health < 100 && dist(player1.x, player1.y, hk.x, hk.y) < 30) {
      player1.health = 100;
      healthKits.remove(i);
      if (soundsLoaded && healthPickupSound != null) healthPickupSound.play();
      continue;
    }
    
    // Check if player2 picks up (only if not at full health)
    if (player2.health < 100 && dist(player2.x, player2.y, hk.x, hk.y) < 30) {
      player2.health = 100;
      healthKits.remove(i);
      if (soundsLoaded && healthPickupSound != null) healthPickupSound.play();
    }
  }
  
  checkPlayerHits();
  
  if (player1.kills >= killsToWin) {
    triggerEndScreen(player1);
  } else if (player2.kills >= killsToWin) {
    triggerEndScreen(player2);
  }
  
  // Handle atomic bomb flash and detonation (desert map only)
  if (atomicBombTriggered && currentMapIndex == 3) {
    int timeSinceTrigger = millis() - atomicBombTriggerTime;

    if (timeSinceTrigger >= atomicBombFlashTime && !atomicBombDetonated) {
      // Initial white flash
      atomicBombDetonated = true;
      atomicBombFlashAlpha = 255;
      skyboxTexture = skyboxTextureFallout; // Change to fallout grey sky

      // Play detonation sound (louder)
      if (soundsLoaded && atomicDetonationSound != null) {
        atomicDetonationSound.amp(0.8); // Increase volume
        atomicDetonationSound.play();
      }
    }

    if (atomicBombDetonated && atomicBombFlashAlpha > 0) {
      // Fade out the white flash over 4 seconds (1 second longer)
      atomicBombFlashAlpha -= 255.0 / (4.0 * 60.0); // Assuming 60 FPS
      if (atomicBombFlashAlpha < 0) atomicBombFlashAlpha = 0;
    }
  }

  renderPlayer(player1, 0, 0, width/2, height);
  renderPlayer(player2, width/2, 0, width/2, height);

  // Render white flash overlay for atomic bomb
  if (atomicBombFlashAlpha > 0 && currentMapIndex == 3) {
    fill(255, 255, 255, atomicBombFlashAlpha);
    noStroke();
    rect(0, 0, width, height);
  }

  stroke(255);
  strokeWeight(4);
  line(width/2, 0, width/2, height);
}

void drawMapSelectScreen() {
  // Dark forest green background for map select
  background(15, 25, 15);
  
  // Animated lines
  for (int i = 0; i < 50; i++) {
    float x = (frameCount * 0.3 + i * 50) % width;
    stroke(30, 60, 30, 100);
    line(x, 0, x, height);
  }
  
  fill(100, 255, 100);
  textAlign(CENTER, CENTER);
  textSize(60);
  text("SELECT MAP", width/2, height/6);
  
  // Map preview area
  float previewW = 400;
  float previewH = 300;
  float previewX = width/2 - previewW/2;
  float previewY = height/2 - previewH/2 - 20;
  
  // Draw map preview border
  stroke(100, 200, 100);
  strokeWeight(3);
  noFill();
  rect(previewX - 5, previewY - 5, previewW + 10, previewH + 10);
  noStroke();
  
  // Draw minimap preview
  int[][] previewMap;
  if (currentMapIndex == 0) {
    previewMap = mapClassicCargo;
  } else if (currentMapIndex == 1) {
    previewMap = mapForestClearing;
  } else if (currentMapIndex == 2) {
    previewMap = mapSunsetBeach;
  } else {
    previewMap = mapDesertWasteland;
  }

  // Use actual map dimensions for proper rendering
  int mapWidth = previewMap[0].length;
  int mapHeight = previewMap.length;
  float cellW = previewW / mapWidth;
  float cellH = previewH / mapHeight;

  for (int y = 0; y < mapHeight; y++) {
    for (int x = 0; x < mapWidth; x++) {
      int cell = previewMap[y][x];
      if (cell == 0) {
        // Floor
        if (currentMapIndex == 0) {
          fill(60, 50, 40); // Warehouse floor
        } else if (currentMapIndex == 1) {
          fill(45, 70, 35); // Grass
        } else if (currentMapIndex == 2) {
          fill(220, 200, 160); // Beach sand
        } else {
          fill(210, 180, 120); // Desert sand
        }
      } else if (cell == 5) {
        // Creek (forest only)
        fill(40, 80, 120);
      } else if (cell == 7) {
        // Shoreline (beach only)
        fill(30, 120, 180);
      } else if (cell == 8) {
        // Desert border (desert only)
        fill(190, 160, 100);
      } else if (cell == 9) {
        // Ocean/invisible barrier (beach only)
        fill(40, 130, 200);
      } else {
        // Walls
        if (currentMapIndex == 0) {
          // Classic Cargo colors
          if (cell == 1) fill(120, 120, 120);
          else if (cell == 2) fill(150, 50, 40);
          else if (cell == 3) fill(40, 60, 120);
          else fill(80, 80, 90);
        } else if (currentMapIndex == 1) {
          // Forest colors
          if (cell == 1) fill(100, 90, 80); // Rocks
          else if (cell == 2) fill(30, 80, 30); // Pine trees
          else if (cell == 3) fill(25, 70, 25); // Pine variant
          else fill(80, 60, 40); // Logs
        } else if (currentMapIndex == 2) {
          // Beach colors
          if (cell == 1) fill(180, 170, 160); // Rock walls
          else fill(220, 200, 160); // Default to sand
        } else {
          // Desert colors
          fill(210, 180, 120); // Default to desert sand
        }
      }
      rect(previewX + x * cellW, previewY + y * cellH, cellW + 1, cellH + 1);
    }
  }
  
  // Map name
  fill(255, 255, 100);
  textSize(45);
  text(mapNames[currentMapIndex], width/2, previewY + previewH + 50);
  
  // Map description
  fill(200, 200, 200);
  textSize(18);
  if (currentMapIndex == 0) {
    text("First day at your union freight yard job", width/2, previewY + previewH + 85);
  } else if (currentMapIndex == 1) {
    text("Forest clearing with pine trees, boulders, and a winding creek - you're finally awake.", width/2, previewY + previewH + 85);
  } else if (currentMapIndex == 2) {
    text("Wasting away...", width/2, previewY + previewH + 85);
  } else {
    text("Restricted federal property - how did you even get here?", width/2, previewY + previewH + 85);
  }
  
  // Navigation arrows
  fill(255, 255, 255);
  textSize(80);
  float arrowY = height/2 - 20;
  
  // Left arrow
  text("<", 80, arrowY);
  // Right arrow
  text(">", width - 80, arrowY);
  
  // Map counter
  fill(150, 150, 150);
  textSize(20);
  text("Map " + (currentMapIndex + 1) + " of " + numMaps, width/2, previewY + previewH + 115);
  
  // Instructions
  fill(200, 200, 200);
  textSize(20);
  text("Use LEFT/RIGHT arrows or A/D to browse maps", width/2, height - 100);
  
  fill(255, 255, 0, 150 + sin(frameCount * 0.1) * 105);
  textSize(35);
  text("PRESS SPACE OR ENTER TO CONFIRM", width/2, height - 50);
}

void drawKillSelectScreen() {
  background(20, 10, 10);
  for (int i = 0; i < 50; i++) {
    float x = (frameCount * 0.5 + i * 50) % width;
    stroke(80, 20, 20, 100);
    line(x, 0, x, height);
  }
  fill(255, 50, 50);
  textAlign(CENTER, CENTER);
  textSize(60);
  text("GAME SETTINGS", width/2, height/4);
  fill(255, 255, 255);
  textSize(30);
  text("KILLS TO WIN", width/2, height/2 - 100);
  float sliderX = width/2 - 200;
  float sliderY = height/2;
  float sliderW = 400;
  float sliderH = 20;
  fill(60, 60, 60);
  rect(sliderX, sliderY - sliderH/2, sliderW, sliderH, 10);
  float fillW = map(killsToWin, 1, 20, 0, sliderW);
  fill(255, 50, 50);
  rect(sliderX, sliderY - sliderH/2, fillW, sliderH, 10);
  float handleX = map(killsToWin, 1, 20, sliderX, sliderX + sliderW);
  fill(255, 255, 255);
  ellipse(handleX, sliderY, 30, 30);
  fill(255, 255, 0);
  textSize(60);
  text(killsToWin, width/2, height/2 + 80);
  fill(200, 200, 200);
  textSize(20);
  text("Use LEFT/RIGHT arrows or A/D to adjust", width/2, height/2 + 150);
  fill(255, 255, 0, 150 + sin(frameCount * 0.1) * 105);
  textSize(35);
  text("PRESS SPACE OR ENTER TO START", width/2, 3*height/4);
}

void drawEndScreen() {
  int timeSinceEnd = millis() - endScreenStartTime;
  background(0);
  int spriteAppearTime = 2000;
  int pickupSoundTime = spriteAppearTime + 2000;
  int gunfireTime = pickupSoundTime + gunfireDelay;
  
  if (timeSinceEnd >= spriteAppearTime) {
    float spriteSize = 400;
    PImage winnerSprite = (winner == player1) ? player1Sprite : player2Sprite;
    if (winnerSprite != null) {
      imageMode(CENTER);
      image(winnerSprite, width/2, height/2 + 50, spriteSize, spriteSize);
      imageMode(CORNER);
    } else {
      fill(winner.teamColor);
      rectMode(CENTER);
      rect(width/2, height/2 + 50, spriteSize * 0.6, spriteSize);
      rectMode(CORNER);
    }
  }
  
  if (timeSinceEnd >= pickupSoundTime && timeSinceEnd < pickupSoundTime + 100) {
    if (soundsLoaded && shotgunPickupSound != null) shotgunPickupSound.play();
  }
  
  if (timeSinceEnd >= gunfireTime) {
    if (timeSinceEnd >= gunfireTime && timeSinceEnd < gunfireTime + 100) {
      if (soundsLoaded && shootSound != null) shootSound.play();

      // Play loser's death sound
      if (soundsLoaded) {
        Player loser = (winner == player1) ? player2 : player1;
        if (loser == player1 && player1DeathSound != null) {
          player1DeathSound.play();
        } else if (loser == player2 && player2DeathSound != null) {
          player2DeathSound.play();
        }
      }

      if (musicLoaded && menuMusic != null && !menuMusic.isPlaying()) {
        try { menuMusic.amp(0.3); } catch (Exception e) {}
        menuMusic.loop();
      }
    }
    
    float spriteSize = 400;
    float screenX = width/2;
    float screenY = height/2 + 50;
    PImage winnerSprite = (winner == player1) ? player1Sprite : player2Sprite;
    
    if (winnerSprite != null) {
      imageMode(CENTER);
      image(winnerSprite, screenX, screenY, spriteSize, spriteSize);
      imageMode(CORNER);
    } else {
      fill(winner.teamColor);
      rectMode(CENTER);
      rect(screenX, screenY, spriteSize * 0.6, spriteSize);
      rectMode(CORNER);
    }
    
    int gunfireFrameTime = 150;
    if (timeSinceEnd >= gunfireTime && timeSinceEnd < gunfireTime + gunfireFrameTime && muzzleFlash != null) {
      float flashProgress = (timeSinceEnd - gunfireTime) / float(gunfireFrameTime);
      float flashAlpha = (1 - flashProgress) * 255;
      float flashSize = spriteSize * 0.3;
      if (winner == player1) {
        float flashX = screenX - spriteSize * 0.25;
        float flashY = screenY - spriteSize * 0.2;
        pushStyle();
        tint(255, flashAlpha);
        imageMode(CENTER);
        image(muzzleFlash, flashX, flashY, flashSize, flashSize);
        noTint();
        imageMode(CORNER);
        popStyle();
      } else {
        float flashOffset = spriteSize * 0.35;
        float flashY = screenY + spriteSize * 0.05;
        pushStyle();
        tint(255, flashAlpha);
        imageMode(CENTER);
        image(muzzleFlash, screenX - flashOffset, flashY, flashSize, flashSize);
        image(muzzleFlash, screenX + flashOffset, flashY, flashSize, flashSize);
        noTint();
        imageMode(CORNER);
        popStyle();
      }
    }
    
    if (bloodOverlay != null) {
      pushStyle();
      tint(255, 200);
      imageMode(CORNER);
      image(bloodOverlay, 0, 0, width, height);
      noTint();
      popStyle();
    }
    
    fill(255, 255, 0);
    textAlign(CENTER, CENTER);
    textSize(80);
    text(winner.name + " WINS!", width/2, height/2 - 100);
    fill(255, 255, 255);
    textSize(40);
    text("Final Score:", width/2, height/2);
    textSize(35);
    Player loser = (winner == player1) ? player2 : player1;
    fill(winner.teamColor);
    text(winner.name + ": " + winner.kills + " kills", width/2, height/2 + 60);
    fill(loser.teamColor);
    text(loser.name + ": " + loser.kills + " kills", width/2, height/2 + 110);
    
    if (timeSinceEnd >= gunfireTime + 3000) {
      fill(255, 255, 0, 150 + sin(frameCount * 0.1) * 105);
      textSize(30);
      text("PRESS ANY KEY TO PLAY AGAIN", width/2, 3*height/4);
    }
  }
}

void triggerEndScreen(Player winningPlayer) {
  gameEnded = true;
  winner = winningPlayer;
  endScreenStartTime = millis();
  gunfireDelay = int(random(2000, 6000));

  // Stop all in-game music immediately
  if (musicLoaded) {
    // Stop standard game tracks
    if (currentTrack != -1 && gameMusic[currentTrack] != null) {
      try { gameMusic[currentTrack].stop(); } catch (Exception e) {}
    }

    // Stop map-specific music tracks
    if (cargoMusic != null && cargoMusic.isPlaying()) {
      try { cargoMusic.stop(); } catch (Exception e) {}
    }
    if (forestMusic != null && forestMusic.isPlaying()) {
      try { forestMusic.stop(); } catch (Exception e) {}
    }
    if (beachMusic != null && beachMusic.isPlaying()) {
      try { beachMusic.stop(); } catch (Exception e) {}
    }
    if (desertMusic != null && desertMusic.isPlaying()) {
      try { desertMusic.stop(); } catch (Exception e) {}
    }
  }
}

void drawTitleScreen() {
  background(20, 10, 10);
  for (int i = 0; i < 50; i++) {
    float x = (frameCount * 0.5 + i * 50) % width;
    stroke(80, 20, 20, 100);
    line(x, 0, x, height);
  }
  fill(255, 50, 50, titleAlpha);
  textAlign(CENTER, CENTER);
  textSize(90);
  text("DUEL WARFARE", width/2, height/3);
  fill(200, 200, 200, titleAlpha);
  textSize(30);
  text("Split-Screen FPS Combat", width/2, height/3 + 80);
  
  float bpm = 64.0;
  float beatsPerSecond = bpm / 60.0;
  float beatPeriodMs = 1000.0 / beatsPerSecond;
  float bobAmount = 30;
  float bobOffset = sin((millis() / beatPeriodMs) * TWO_PI) * bobAmount;
  
  float p1X = width/4;
  float p1Y = height/2 - 20 + bobOffset;
  float spriteSize = 200;
  
  if (player1Sprite != null) {
    pushMatrix();
    translate(p1X, p1Y);
    imageMode(CENTER);
    tint(255, titleAlpha);
    image(player1Sprite, 0, 0, spriteSize, spriteSize);
    noTint();
    imageMode(CORNER);
    popMatrix();
  } else {
    fill(100, 200, 255, titleAlpha);
    rectMode(CENTER);
    rect(p1X, p1Y, spriteSize * 0.6, spriteSize);
    rectMode(CORNER);
  }
  
  float p2X = 3 * width/4;
  float p2Y = height/2 - 20 - bobOffset;
  
  if (player2Sprite != null) {
    pushMatrix();
    translate(p2X, p2Y);
    imageMode(CENTER);
    tint(255, titleAlpha);
    image(player2Sprite, 0, 0, spriteSize, spriteSize);
    noTint();
    imageMode(CORNER);
    popMatrix();
  } else {
    fill(255, 100, 100, titleAlpha);
    rectMode(CENTER);
    rect(p2X, p2Y, spriteSize * 0.6, spriteSize);
    rectMode(CORNER);
  }
  
  fill(255, 255, 255, titleAlpha);
  textSize(20);
  text("PLAYER 1: WASD + SPACE to shoot + Q to reload", width/4, height/2 + 130);
  text("PLAYER 2: ARROWS + ENTER to shoot + / to reload", 3*width/4, height/2 + 130);
  fill(255, 255, 0, 150 + sin(frameCount * 0.1) * 105);
  textSize(35);
  text("PRESS ANY KEY TO START", width/2, 2*height/3 + 60);
  fill(150, 150, 150, titleAlpha);
  textSize(16);
  text("", width/2, height - 60);
  text("A Game By Chili James Potmesil", width/2, height - 30);
}

void drawInputSelectScreen() {
  background(20, 20, 40);

  // Title
  fill(100, 200, 255);
  textAlign(CENTER, CENTER);
  textSize(60);
  text("SELECT INPUT METHOD", width/2, height/4);

  // Keyboard option
  fill(200, 200, 200);
  textSize(40);
  text("Press 'K' for KEYBOARD", width/2, height/2 - 60);

  fill(150, 150, 150);
  textSize(20);
  text("Player 1: WASD + SPACE + Q", width/2, height/2 - 20);
  text("Player 2: ARROWS + ENTER + /", width/2, height/2 + 10);

  // Controller option
  fill(200, 200, 200);
  textSize(40);
  text("Press 'C' for CONTROLLER", width/2, height/2 + 100);

  fill(150, 150, 150);
  textSize(20);
  text("Two Arduino controllers with joysticks and buttons", width/2, height/2 + 140);
  text("Make sure controllers are connected before selecting", width/2, height/2 + 170);

  // Instruction
  fill(255, 255, 0, 150 + sin(frameCount * 0.1) * 105);
  textSize(30);
  text("CHOOSE YOUR INPUT METHOD", width/2, 3*height/4 + 40);
}

void loadSounds() {
  println("=== LOADING SOUND EFFECTS ===");
  try {
    shootSound = loadSoundSafe("shoot.wav");
    player1HitSound1 = loadSoundSafe("player1_hit1.wav");
    player1HitSound2 = loadSoundSafe("player1_hit2.wav");
    player2HitSound1 = loadSoundSafe("player2_hit1.wav");
    player2HitSound2 = loadSoundSafe("player2_hit2.wav");
    player1DeathSound = loadSoundSafe("player1_death.wav");
    player2DeathSound = loadSoundSafe("player2_death.wav");
    shotgunSound = loadSoundSafe("shotgun.wav");
    rifleSound = loadSoundSafe("rifle.wav");
    shotgunPickupSound = loadSoundSafe("shotgun_pickup.wav");
    riflePickupSound = loadSoundSafe("rifle_pickup.wav");
    healthPickupSound = loadSoundSafe("health_pickup.wav");
    emptyGunSound = loadSoundSafe("empty_gun.wav");
    reloadSound = loadSoundSafe("reload.wav");
    atomicDetonationSound = loadSoundSafe("Atomic_detonation.wav");
    if (shootSound != null || player1HitSound1 != null || player1HitSound2 != null ||
        player2HitSound1 != null || player2HitSound2 != null ||
        player1DeathSound != null || player2DeathSound != null ||
        shotgunSound != null || rifleSound != null ||
        shotgunPickupSound != null || riflePickupSound != null ||
        healthPickupSound != null || emptyGunSound != null || reloadSound != null) {
      soundsLoaded = true;
      println("Sound effects loaded successfully");
    } else {
      println("No sound files found - continuing without audio");
    }
  } catch (Exception e) {
    println("Error loading sounds: " + e.getMessage());
    soundsLoaded = false;
  }
  println("=== SOUND LOADING COMPLETE ===");
}

void loadMusic() {
  println("=== LOADING MUSIC ===");
  try {
    menuMusic = loadSoundSafe("menu_music.wav");
    if (menuMusic == null) menuMusic = loadSoundSafe("menu_music.mp3");
    int loadedTracks = 0;
    for (int i = 0; i < 5; i++) {
      try {
        gameMusic[i] = loadSoundSafe("game_music_" + (i + 1) + ".wav");
        if (gameMusic[i] == null) gameMusic[i] = loadSoundSafe("game_music_" + (i + 1) + ".mp3");
        if (gameMusic[i] != null) loadedTracks++;
      } catch (Exception e) {
        gameMusic[i] = null;
      }
    }
    // Load map-specific music
    cargoMusic = loadSoundSafe("cargo_music.wav");
    if (cargoMusic == null) cargoMusic = loadSoundSafe("cargo_music.mp3");
    if (cargoMusic != null) {
      println("Cargo music loaded");
      loadedTracks++;
    }

    forestMusic = loadSoundSafe("forest_music.wav");
    if (forestMusic == null) forestMusic = loadSoundSafe("forest_music.mp3");
    if (forestMusic != null) {
      println("Forest music loaded");
      loadedTracks++;
    }

    beachMusic = loadSoundSafe("beach_music.wav");
    if (beachMusic == null) beachMusic = loadSoundSafe("beach_music.mp3");
    if (beachMusic != null) {
      println("Beach music loaded");
      loadedTracks++;
    }

    desertMusic = loadSoundSafe("desert_music.wav");
    if (desertMusic == null) desertMusic = loadSoundSafe("desert_music.mp3");
    if (desertMusic != null) {
      println("Desert music loaded");
      loadedTracks++;
    }
    if (menuMusic != null || loadedTracks > 0) {
      musicLoaded = true;
      println("Music system loaded successfully (" + loadedTracks + " game tracks)");
    } else {
      println("No music files found - continuing without music");
      musicLoaded = false;
    }
  } catch (Exception e) {
    println("Error loading music: " + e.getMessage());
    musicLoaded = false;
  }
  println("=== MUSIC LOADING COMPLETE ===");
}

void playRandomGameTrack() {
  // Stop current music
  if (currentTrack != -1 && gameMusic[currentTrack] != null) {
    try { gameMusic[currentTrack].stop(); } catch (Exception e) {}
  }
  if (cargoMusic != null && cargoMusic.isPlaying()) {
    try { cargoMusic.stop(); } catch (Exception e) {}
  }
  if (forestMusic != null && forestMusic.isPlaying()) {
    try { forestMusic.stop(); } catch (Exception e) {}
  }
  if (beachMusic != null && beachMusic.isPlaying()) {
    try { beachMusic.stop(); } catch (Exception e) {}
  }
  if (desertMusic != null && desertMusic.isPlaying()) {
    try { desertMusic.stop(); } catch (Exception e) {}
  }

  // Play map-specific music if available
  // Cargo map (index 0)
  if (currentMapIndex == 0 && cargoMusic != null) {
    try {
      cargoMusic.amp(0.3);
      cargoMusic.loop();
      println("Now playing: Cargo Music");
      currentTrack = -1; // Not using standard track
      return;
    } catch (Exception e) {
      println("Error playing cargo music");
    }
  }

  // Forest map (index 1)
  if (currentMapIndex == 1 && forestMusic != null) {
    try {
      forestMusic.amp(0.3);
      forestMusic.loop();
      println("Now playing: Forest Music");
      currentTrack = -1; // Not using standard track
      return;
    } catch (Exception e) {
      println("Error playing forest music");
    }
  }

  // Beach map (index 2)
  if (currentMapIndex == 2 && beachMusic != null) {
    try {
      beachMusic.amp(0.3);
      beachMusic.loop();
      println("Now playing: Beach Music");
      currentTrack = -1; // Not using standard track
      return;
    } catch (Exception e) {
      println("Error playing beach music");
    }
  }

  // Desert map (index 3)
  if (currentMapIndex == 3 && desertMusic != null) {
    try {
      desertMusic.amp(0.3);
      desertMusic.loop();
      println("Now playing: Desert Music");
      currentTrack = -1; // Not using standard track
      return;
    } catch (Exception e) {
      println("Error playing desert music");
    }
  }

  // Otherwise play random game track
  ArrayList<Integer> availableTracks = new ArrayList<Integer>();
  for (int i = 0; i < 5; i++) {
    if (gameMusic[i] != null) availableTracks.add(i);
  }
  if (availableTracks.size() == 0) {
    println("No game music tracks available");
    return;
  }
  int randomIndex = int(random(availableTracks.size()));
  currentTrack = availableTracks.get(randomIndex);
  try {
    gameMusic[currentTrack].amp(0.3);
    gameMusic[currentTrack].play();
    println("Now playing: Game Track " + (currentTrack + 1));
  } catch (Exception e) {
    println("Error playing game track " + (currentTrack + 1));
    gameMusic[currentTrack] = null;
    if (availableTracks.size() > 1) playRandomGameTrack();
  }
}

SoundFile loadSoundSafe(String filename) {
  SoundFile sound = null;
  String[] paths = {filename, "sounds/" + filename, "data/" + filename, "data/sounds/" + filename};
  for (String path : paths) {
    try {
      sound = new SoundFile(this, path);
      if (sound != null) {
        println("Loaded " + filename + " from " + path);
        return sound;
      }
    } catch (Exception e) {}
  }
  return null;
}

void initializeControllers() {
  println("=== INITIALIZING ARDUINO CONTROLLERS ===");
  try {
    // List available serial ports
    println("Available serial ports:");
    String[] ports = Serial.list();
    for (int i = 0; i < ports.length; i++) {
      println("[" + i + "] " + ports[i]);
    }

    if (ports.length < 2) {
      println("ERROR: Need at least 2 serial ports for controllers");
      println("Falling back to keyboard mode");
      useController = false;
      return;
    }

    // Initialize serial ports (adjust port indices as needed)
    // You may need to change these indices to match your Arduino connections
    port1 = new Serial(this, ports[0], 9600);
    port2 = new Serial(this, ports[1], 9600);

    port1.bufferUntil('\n');
    port2.bufferUntil('\n');

    println("Controller 1 connected on " + ports[0]);
    println("Controller 2 connected on " + ports[1]);
    println("=== CONTROLLERS INITIALIZED ===");
  } catch (Exception e) {
    println("ERROR initializing controllers: " + e.getMessage());
    println("Falling back to keyboard mode");
    useController = false;
  }
}

void serialEvent(Serial port) {
  if (!useController) return;

  try {
    String data = port.readStringUntil('\n');
    if (data != null) {
      data = trim(data);
      parseControllerData(data, port);
    }
  } catch (Exception e) {
    println("Error reading serial data: " + e.getMessage());
  }
}

void parseControllerData(String data, Serial port) {
  // Expected format: "joyX,joyY,fireBtn,reloadBtn"
  // Example: "512,480,0,1" means joystick at (512, 480), fire not pressed, reload pressed

  String[] values = split(data, ',');
  if (values.length != 4) return;

  try {
    int joyX = int(values[0]);
    int joyY = int(values[1]);
    int fire = int(values[2]);
    int reload = int(values[3]);

    // Determine which player this data is for
    if (port == port1) {
      p1JoyX = joyX;
      p1JoyY = joyY;
      p1FireBtn = (fire == 1);
      p1ReloadBtn = (reload == 1);
    } else if (port == port2) {
      p2JoyX = joyX;
      p2JoyY = joyY;
      p2FireBtn = (fire == 1);
      p2ReloadBtn = (reload == 1);
    }
  } catch (Exception e) {
    println("Error parsing controller data: " + e.getMessage());
  }
}

void updateControllerInput() {
  if (!useController) return;

  // Update Player 1 from controller 1
  updatePlayerFromController(player1, p1JoyX, p1JoyY, p1FireBtn, p1ReloadBtn);

  // Update Player 2 from controller 2
  updatePlayerFromController(player2, p2JoyX, p2JoyY, p2FireBtn, p2ReloadBtn);
}

void updatePlayerFromController(Player p, int joyX, int joyY, boolean fireBtn, boolean reloadBtn) {
  // Handle joystick X-axis for turning (left/right)
  int deltaX = joyX - joyCenterX;
  if (abs(deltaX) > joyDeadZone) {
    // Map joystick to turning speed
    // Positive = turn right, Negative = turn left
    float turnAmount = map(abs(deltaX), joyDeadZone, 512, 0, p.turnSpeed);
    if (deltaX > 0) {
      p.dKey = true;
      p.aKey = false;
    } else {
      p.aKey = true;
      p.dKey = false;
    }
  } else {
    p.aKey = false;
    p.dKey = false;
  }

  // Handle joystick Y-axis for movement (forward/backward)
  int deltaY = joyY - joyCenterY;
  if (abs(deltaY) > joyDeadZone) {
    // Map joystick to movement
    // Note: Y-axis might be inverted depending on joystick orientation
    // Adjust the comparison if needed
    if (deltaY < 0) { // Forward
      p.wKey = true;
      p.sKey = false;
    } else { // Backward
      p.sKey = true;
      p.wKey = false;
    }
  } else {
    p.wKey = false;
    p.sKey = false;
  }

  // Handle fire button
  if (fireBtn && !p.fireKeyHeld) {
    p.fireKeyHeld = true;
    p.shoot();
  } else if (!fireBtn) {
    p.fireKeyHeld = false;
  }

  // Handle reload button (only trigger on button press, not hold)
  if (reloadBtn && !p.reloadBtnPressed) {
    p.reloadBtnPressed = true;
    p.startReload();
  } else if (!reloadBtn) {
    p.reloadBtnPressed = false;
  }
}

void resetGame() {
  // Reset game state
  gameEnded = false;
  winner = null;
  gameStarted = false;
  showInputSelect = false;
  showMapSelect = false;
  showKillSelect = false;
  gameTrackStarted = false;
  gunfireDelay = 0;

  // Reset player 1
  player1.kills = 0;
  player1.health = 100;
  player1.x = 75;
  player1.y = 75;
  player1.angle = 0;
  player1.currentWeapon = "pistol";
  player1.weaponAmmo = 0;
  player1.lastHitMarker = 0;
  player1.pistolAmmo = player1.pistolMaxAmmo;
  player1.reloading = false;
  player1.fireKeyHeld = false;
  player1.reloadBtnPressed = false;
  player1.wKey = false;
  player1.aKey = false;
  player1.sKey = false;
  player1.dKey = false;

  // Reset player 2
  player2.kills = 0;
  player2.health = 100;
  player2.x = 725;
  player2.y = 725;
  player2.angle = PI;
  player2.currentWeapon = "pistol";
  player2.weaponAmmo = 0;
  player2.lastHitMarker = 0;
  player2.pistolAmmo = player2.pistolMaxAmmo;
  player2.reloading = false;
  player2.fireKeyHeld = false;
  player2.reloadBtnPressed = false;
  player2.wKey = false;
  player2.aKey = false;
  player2.sKey = false;
  player2.dKey = false;

  // Reset controller button states
  p1FireBtn = false;
  p1ReloadBtn = false;
  p2FireBtn = false;
  p2ReloadBtn = false;
  p1PrevFireBtn = false;
  p1PrevJoyLeft = false;
  p1PrevJoyRight = false;

  // Reset atomic bomb state (desert map)
  atomicBombTriggered = false;
  atomicBombDetonated = false;
  atomicBombFlashAlpha = 0;
  atomicBombTriggerTime = 0;

  // Reset skybox to normal for desert map
  if (currentMapIndex == 3) {
    skyboxTexture = skyboxTextureDesert;
  }

  // Clear game objects
  bullets.clear();
  weaponPickups.clear();
  healthKits.clear();
  bloodParticles.clear();
  bloodPools.clear();
  nextWeaponSpawn = millis() + 10000;
  nextHealthKitSpawn = millis() + 15000;
}

void loadTextures() {
  int texSize = 64;
  println("=== LOADING TEXTURES ===");
  
  // Load Classic Cargo textures
  println("Loading Classic Cargo textures...");
  wallTexturesClassic = new PImage[6];
  for (int i = 1; i <= 4; i++) wallTexturesClassic[i] = loadImageSafe("wall" + i + ".png");
  if (wallTexturesClassic[1] == null) wallTexturesClassic[1] = createStoneBrickTexture(texSize);
  if (wallTexturesClassic[2] == null) wallTexturesClassic[2] = createRedBrickTexture(texSize);
  if (wallTexturesClassic[3] == null) wallTexturesClassic[3] = createBlueTechTexture(texSize);
  if (wallTexturesClassic[4] == null) wallTexturesClassic[4] = createMetalTexture(texSize);
  floorTextureClassic = loadImageSafe("floor.png");
  if (floorTextureClassic == null) floorTextureClassic = createFloorTexture(texSize);
  skyboxTextureClassic = loadImageSafe("skybox.png");
  if (skyboxTextureClassic == null) skyboxTextureClassic = createSkyboxTexture();
  
  // Load Forest Clearing textures
  println("Loading Forest Clearing textures...");
  wallTexturesForest = new PImage[6];
  wallTexturesForest[1] = loadImageSafe("forest_rock.png");
  if (wallTexturesForest[1] == null) wallTexturesForest[1] = createRockTexture(texSize);
  wallTexturesForest[2] = loadImageSafe("forest_pine.png");
  if (wallTexturesForest[2] == null) wallTexturesForest[2] = createPineTreeTexture(texSize);
  wallTexturesForest[3] = loadImageSafe("forest_pine2.png");
  if (wallTexturesForest[3] == null) wallTexturesForest[3] = createPineTreeTexture2(texSize);
  wallTexturesForest[4] = loadImageSafe("forest_log.png");
  if (wallTexturesForest[4] == null) wallTexturesForest[4] = createLogTexture(texSize);
  wallTexturesForest[5] = loadImageSafe("forest_creek.png");
  if (wallTexturesForest[5] == null) wallTexturesForest[5] = createCreekTexture(texSize);
  floorTextureForest = loadImageSafe("forest_floor.png");
  if (floorTextureForest == null) floorTextureForest = createGrassTexture(texSize);
  skyboxTextureForest = loadImageSafe("forest_skybox.png");
  if (skyboxTextureForest == null) skyboxTextureForest = createForestSkyboxTexture();
  creekTexture = loadImageSafe("creek.png");
  if (creekTexture == null) creekTexture = createCreekFloorTexture(texSize);

  // Load Sunset Beach textures
  println("Loading Sunset Beach textures...");
  wallTexturesBeach = new PImage[9];
  wallTexturesBeach[1] = loadImageSafe("beach_rock.png");
  if (wallTexturesBeach[1] == null) wallTexturesBeach[1] = createBeachRockTexture(texSize);
  wallTexturesBeach[2] = loadImageSafe("beach_palm.png");
  if (wallTexturesBeach[2] == null) wallTexturesBeach[2] = createPalmTreeTexture(texSize);
  wallTexturesBeach[3] = loadImageSafe("beach_palm2.png");
  if (wallTexturesBeach[3] == null) wallTexturesBeach[3] = createPalmTreeTexture2(texSize);
  wallTexturesBeach[4] = loadImageSafe("beach_hut.png");
  if (wallTexturesBeach[4] == null) wallTexturesBeach[4] = createBeachHutTexture(texSize);
  wallTexturesBeach[6] = loadImageSafe("beach_umbrella.png");
  if (wallTexturesBeach[6] == null) wallTexturesBeach[6] = createBeachUmbrellaTexture(texSize);
  wallTexturesBeach[7] = loadImageSafe("beach_shoreline_wall.png");
  if (wallTexturesBeach[7] == null) wallTexturesBeach[7] = createShorelineWallTexture(texSize);
  wallTexturesBeach[8] = loadImageSafe("beach_coral.png");
  if (wallTexturesBeach[8] == null) wallTexturesBeach[8] = createCoralTexture(texSize);
  floorTextureBeach = loadImageSafe("beach_sand.png");
  if (floorTextureBeach == null) floorTextureBeach = createSandTexture(texSize);
  skyboxTextureBeach = loadImageSafe("beach_sunset.png");
  if (skyboxTextureBeach == null) skyboxTextureBeach = createSunsetSkyboxTexture();
  shorelineTexture = loadImageSafe("beach_water.png");
  if (shorelineTexture == null) shorelineTexture = createOceanTexture(texSize);

  // Beach obstacle sprites
  palmTreeSprite = loadImageSafe("palm_tree_sprite.png");
  if (palmTreeSprite == null) palmTreeSprite = createPalmTreeSprite();
  palmTreeSprite2 = loadImageSafe("palm_tree_sprite2.png");
  if (palmTreeSprite2 == null) palmTreeSprite2 = createPalmTreeSprite2();
  beachUmbrellaSprite = loadImageSafe("beach_umbrella_sprite.png");
  if (beachUmbrellaSprite == null) beachUmbrellaSprite = createBeachUmbrellaSprite();
  sailboatSprite = loadImageSafe("sailboat.png");
  if (sailboatSprite == null) sailboatSprite = createSailboatSprite();

  // Load Desert Wasteland textures
  println("Loading Desert Wasteland textures...");
  wallTexturesDesert = new PImage[10];
  // Index 1 is required for out-of-bounds raycasts (even though map has no walls)
  wallTexturesDesert[1] = loadImageSafe("desert_rock.png");
  if (wallTexturesDesert[1] == null) wallTexturesDesert[1] = createDesertRockTexture(texSize);
  wallTexturesDesert[8] = loadImageSafe("desert_border.png");
  if (wallTexturesDesert[8] == null) wallTexturesDesert[8] = createDesertBorderTexture(texSize);
  floorTextureDesert = loadImageSafe("desert_sand.png");
  if (floorTextureDesert == null) floorTextureDesert = createDesertSandTexture(texSize);
  skyboxTextureDesert = loadImageSafe("desert_skybox.png");
  if (skyboxTextureDesert == null) skyboxTextureDesert = createDesertSkyboxTexture();
  skyboxTextureFallout = loadImageSafe("fallout_skybox.png");
  if (skyboxTextureFallout == null) skyboxTextureFallout = createFalloutSkyboxTexture();
  desertBorderTexture = loadImageSafe("desert_border_floor.png");
  if (desertBorderTexture == null) desertBorderTexture = createDesertBorderFloorTexture(texSize);
  mountainsSprite = loadImageSafe("mountains.png");
  if (mountainsSprite == null) mountainsSprite = createMountainsSprite();

  // Desert obstacle sprites
  desertObstacle1Sprite = loadImageSafe("desert_obstacle1.png");
  if (desertObstacle1Sprite == null) desertObstacle1Sprite = createDesertObstacle1Sprite();
  desertObstacle2Sprite = loadImageSafe("desert_obstacle2.png");
  if (desertObstacle2Sprite == null) desertObstacle2Sprite = createDesertObstacle2Sprite();
  desertObstacle3Sprite = loadImageSafe("desert_obstacle3.png");
  if (desertObstacle3Sprite == null) desertObstacle3Sprite = createDesertObstacle3Sprite();
  mushroomCloudSprite = loadImageSafe("mushroom_cloud.png");
  if (mushroomCloudSprite == null) mushroomCloudSprite = createMushroomCloudSprite();

  // Ceiling texture (shared)
  ceilingTexture = loadImageSafe("ceiling.png");
  if (ceilingTexture == null) ceilingTexture = createCeilingTexture(texSize);
  
  // Sprites (shared across maps)
  gunSprite = loadImageSafe("gun.png");
  if (gunSprite == null) gunSprite = createDefaultGunSprite();
  shotgunSprite = loadImageSafe("shotgun.png");
  if (shotgunSprite == null) shotgunSprite = createShotgunSprite();
  shotgunPickupSprite = loadImageSafe("shotgun_pickup.png");
  if (shotgunPickupSprite == null) shotgunPickupSprite = createShotgunPickupSprite();
  rifleSprite = loadImageSafe("rifle.png");
  if (rifleSprite == null) rifleSprite = createRifleSprite();
  riflePickupSprite = loadImageSafe("rifle_pickup.png");
  if (riflePickupSprite == null) riflePickupSprite = createRiflePickupSprite();
  player1Sprite = loadImageSafe("player1.png");
  player2Sprite = loadImageSafe("player2.png");
  bloodOverlay = loadImageSafe("blood_overlay.png");
  if (bloodOverlay == null) bloodOverlay = createBloodOverlay();
  muzzleFlash = loadImageSafe("muzzle_flash.png");
  if (muzzleFlash == null) muzzleFlash = createMuzzleFlash();
  bloodParticleTexture = loadImageSafe("blood_particle.png");
  if (bloodParticleTexture == null) bloodParticleTexture = createBloodParticleTexture();
  healthKitSprite = loadImageSafe("health_kit.png");
  if (healthKitSprite == null) healthKitSprite = createHealthKitSprite();
  
  println("=== TEXTURE LOADING COMPLETE ===");
}

PImage loadImageSafe(String filename) {
  PImage img = null;
  String[] paths = {filename, "textures/" + filename, "data/" + filename, "data/textures/" + filename};
  for (String path : paths) {
    try {
      img = loadImage(path);
      if (img != null && img.width > 0) return img;
    } catch (Exception e) {}
  }
  return null;
}

PImage createDefaultGunSprite() {
  PImage gun = createImage(200, 150, ARGB);
  gun.loadPixels();
  for (int y = 0; y < gun.height; y++) {
    for (int x = 0; x < gun.width; x++) {
      boolean isGun = false;
      if (x > 80 && x < 120 && y < 60) isGun = true;
      if (x > 60 && x < 140 && y > 50 && y < 110) isGun = true;
      if (x > 90 && x < 120 && y > 100 && y < 140) isGun = true;
      if (isGun) {
        float noise = random(0.9, 1.1);
        gun.pixels[y * gun.width + x] = color(80 * noise, 80 * noise, 80 * noise);
      } else {
        gun.pixels[y * gun.width + x] = color(0, 0, 0, 0);
      }
    }
  }
  gun.updatePixels();
  return gun;
}

PImage createShotgunSprite() {
  PImage shotgun = createImage(250, 150, ARGB);
  shotgun.loadPixels();
  for (int y = 0; y < shotgun.height; y++) {
    for (int x = 0; x < shotgun.width; x++) {
      boolean isGun = false;
      if (x > 70 && x < 100 && y > 50 && y < 70) isGun = true;
      if (x > 70 && x < 100 && y > 80 && y < 100) isGun = true;
      if (x > 90 && x < 180 && y > 60 && y < 90) isGun = true;
      if (x > 120 && x < 140 && y > 85 && y < 110) isGun = true;
      if (isGun) {
        float noise = random(0.85, 1.15);
        shotgun.pixels[y * shotgun.width + x] = color(60 * noise, 40 * noise, 20 * noise);
      } else {
        shotgun.pixels[y * shotgun.width + x] = color(0, 0, 0, 0);
      }
    }
  }
  shotgun.updatePixels();
  return shotgun;
}

PImage createShotgunPickupSprite() {
  PImage pickup = createImage(40, 40, ARGB);
  pickup.loadPixels();
  for (int y = 0; y < pickup.height; y++) {
    for (int x = 0; x < pickup.width; x++) {
      boolean isGun = (x > 10 && x < 30 && y > 15 && y < 25) || (x > 5 && x < 15 && y > 17 && y < 23);
      pickup.pixels[y * pickup.width + x] = isGun ? color(139, 69, 19) : color(0, 0, 0, 0);
    }
  }
  pickup.updatePixels();
  return pickup;
}

PImage createMuzzleFlash() {
  PImage flash = createImage(120, 120, ARGB);
  flash.loadPixels();
  int centerX = flash.width / 2;
  int centerY = flash.height / 2;
  for (int y = 0; y < flash.height; y++) {
    for (int x = 0; x < flash.width; x++) {
      float d = dist(x, y, centerX, centerY);
      float maxDist = 60;
      if (d < maxDist) {
        float brightness = map(d, 0, maxDist, 1.0, 0.0);
        brightness = pow(brightness, 0.5);
        float angle = atan2(y - centerY, x - centerX);
        float spikes = (sin(angle * 6) + 1) * 0.5;
        brightness *= (0.7 + spikes * 0.3);
        int alpha = int(brightness * 255);
        flash.pixels[y * flash.width + x] = color(255 * brightness, 240 * brightness, 100 * brightness, alpha);
      } else {
        flash.pixels[y * flash.width + x] = color(0, 0, 0, 0);
      }
    }
  }
  flash.updatePixels();
  return flash;
}

PImage createRifleSprite() {
  PImage rifle = createImage(280, 150, ARGB);
  rifle.loadPixels();
  for (int y = 0; y < rifle.height; y++) {
    for (int x = 0; x < rifle.width; x++) {
      boolean isGun = false;
      if (x > 50 && x < 90 && y > 65 && y < 85) isGun = true;
      if (x > 85 && x < 180 && y > 60 && y < 90) isGun = true;
      if (x > 170 && x < 220 && y > 65 && y < 85) isGun = true;
      if (x > 120 && x < 140 && y > 85 && y < 115) isGun = true;
      if (isGun) {
        float noise = random(0.9, 1.1);
        rifle.pixels[y * rifle.width + x] = color(40 * noise, 40 * noise, 40 * noise);
      } else {
        rifle.pixels[y * rifle.width + x] = color(0, 0, 0, 0);
      }
    }
  }
  rifle.updatePixels();
  return rifle;
}

PImage createRiflePickupSprite() {
  PImage pickup = createImage(40, 40, ARGB);
  pickup.loadPixels();
  for (int y = 0; y < pickup.height; y++) {
    for (int x = 0; x < pickup.width; x++) {
      boolean isGun = (x > 5 && x < 35 && y > 18 && y < 22) || (x > 15 && x < 25 && y > 20 && y < 28);
      pickup.pixels[y * pickup.width + x] = isGun ? color(50, 50, 50) : color(0, 0, 0, 0);
    }
  }
  pickup.updatePixels();
  return pickup;
}

PImage createHealthKitSprite() {
  PImage kit = createImage(40, 40, ARGB);
  kit.loadPixels();
  for (int y = 0; y < kit.height; y++) {
    for (int x = 0; x < kit.width; x++) {
      // White box background
      boolean isBox = (x > 5 && x < 35 && y > 5 && y < 35);
      // Red cross
      boolean isCrossH = (x > 12 && x < 28 && y > 17 && y < 23); // Horizontal bar
      boolean isCrossV = (x > 17 && x < 23 && y > 12 && y < 28); // Vertical bar
      
      if (isCrossH || isCrossV) {
        kit.pixels[y * kit.width + x] = color(220, 20, 20); // Red cross
      } else if (isBox) {
        kit.pixels[y * kit.width + x] = color(240, 240, 240); // White background
      } else {
        kit.pixels[y * kit.width + x] = color(0, 0, 0, 0); // Transparent
      }
    }
  }
  kit.updatePixels();
  return kit;
}

PImage createSkyboxTexture() {
  // Create a wide panoramic skybox texture (wraps around 360 degrees)
  int skyWidth = 1024;
  int skyHeight = 256;
  PImage sky = createImage(skyWidth, skyHeight, RGB);
  sky.loadPixels();
  
  // Create base sky gradient
  for (int y = 0; y < skyHeight; y++) {
    for (int x = 0; x < skyWidth; x++) {
      // Gradient from light blue at top to deeper blue at horizon
      float gradientT = (float)y / skyHeight;
      int r = int(lerp(135, 100, gradientT)); // Light to medium
      int g = int(lerp(180, 140, gradientT));
      int b = int(lerp(255, 200, gradientT));
      sky.pixels[y * skyWidth + x] = color(r, g, b);
    }
  }
  
  // Add procedural clouds using layered noise
  for (int y = 0; y < skyHeight; y++) {
    for (int x = 0; x < skyWidth; x++) {
      float cloudDensity = 0;
      
      // Multiple octaves of noise for more natural clouds
      float scale1 = 0.008;
      float scale2 = 0.015;
      float scale3 = 0.03;
      
      // Use sin for x to make it seamlessly tileable horizontally
      float nx = x;
      float ny = y;
      
      // Layer 1: Large cloud formations
      float n1 = noise(nx * scale1, ny * scale1);
      // Layer 2: Medium detail
      float n2 = noise(nx * scale2 + 100, ny * scale2 + 100);
      // Layer 3: Fine detail
      float n3 = noise(nx * scale3 + 200, ny * scale3 + 200);
      
      // Combine layers
      cloudDensity = n1 * 0.6 + n2 * 0.3 + n3 * 0.1;
      
      // Clouds are more likely in upper portion of sky
      float heightFactor = 1.0 - ((float)y / skyHeight);
      heightFactor = pow(heightFactor, 0.5); // Bias toward top
      
      // Threshold for cloud visibility
      float threshold = 0.45;
      if (cloudDensity > threshold && heightFactor > 0.2) {
        float cloudIntensity = map(cloudDensity, threshold, 1.0, 0, 1);
        cloudIntensity *= heightFactor;
        cloudIntensity = constrain(cloudIntensity, 0, 1);
        
        // Get current sky color
        color currentColor = sky.pixels[y * skyWidth + x];
        float cr = red(currentColor);
        float cg = green(currentColor);
        float cb = blue(currentColor);
        
        // Cloud color (white with slight variation)
        float cloudR = 255;
        float cloudG = 255;
        float cloudB = 255;
        
        // Add some gray variation to clouds for depth
        float grayVar = noise(nx * 0.02, ny * 0.02) * 30;
        cloudR -= grayVar * 0.5;
        cloudG -= grayVar * 0.5;
        cloudB -= grayVar * 0.3;
        
        // Blend cloud with sky
        float blendAmount = cloudIntensity * 0.85;
        int finalR = int(lerp(cr, cloudR, blendAmount));
        int finalG = int(lerp(cg, cloudG, blendAmount));
        int finalB = int(lerp(cb, cloudB, blendAmount));
        
        sky.pixels[y * skyWidth + x] = color(finalR, finalG, finalB);
      }
    }
  }
  
  sky.updatePixels();
  println("Created skybox texture: " + skyWidth + "x" + skyHeight);
  return sky;
}

// ========== FOREST MAP TEXTURES ==========

PImage createRockTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.15, y * 0.15);
      float n2 = noise(x * 0.05 + 50, y * 0.05 + 50);
      int base = int(80 + n * 40 + n2 * 20);
      int r = int(base * random(0.9, 1.1));
      int g = int(base * 0.9 * random(0.9, 1.1));
      int b = int(base * 0.85 * random(0.9, 1.1));
      tex.pixels[y * texSize + x] = color(r, g, b);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createPineTreeTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  int trunkWidth = texSize / 4;
  int trunkStart = (texSize - trunkWidth) / 2;
  
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      boolean isTrunk = (x >= trunkStart && x < trunkStart + trunkWidth && y > texSize * 0.6);
      
      if (isTrunk) {
        // Brown bark
        float n = noise(x * 0.3, y * 0.1);
        int base = int(60 + n * 30);
        tex.pixels[y * texSize + x] = color(base, base * 0.5, base * 0.3);
      } else {
        // Green pine needles
        float n = noise(x * 0.2, y * 0.2);
        int g = int(50 + n * 60 + random(-10, 10));
        int r = int(g * 0.4);
        int b = int(g * 0.3);
        tex.pixels[y * texSize + x] = color(r, g, b);
      }
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createPineTreeTexture2(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  int trunkWidth = texSize / 5;
  int trunkStart = (texSize - trunkWidth) / 2;
  
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      boolean isTrunk = (x >= trunkStart && x < trunkStart + trunkWidth && y > texSize * 0.65);
      
      if (isTrunk) {
        // Darker brown bark
        float n = noise(x * 0.25, y * 0.15);
        int base = int(50 + n * 25);
        tex.pixels[y * texSize + x] = color(base, base * 0.45, base * 0.25);
      } else {
        // Darker green pine needles
        float n = noise(x * 0.25, y * 0.25);
        int g = int(40 + n * 50 + random(-10, 10));
        int r = int(g * 0.35);
        int b = int(g * 0.25);
        tex.pixels[y * texSize + x] = color(r, g, b);
      }
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createLogTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      // Wood grain pattern
      float grain = sin(y * 0.5 + noise(x * 0.1, y * 0.1) * 5) * 0.5 + 0.5;
      float n = noise(x * 0.1, y * 0.1);
      int base = int(70 + grain * 30 + n * 20);
      int r = int(base * random(0.95, 1.05));
      int g = int(base * 0.55 * random(0.95, 1.05));
      int b = int(base * 0.35 * random(0.95, 1.05));
      tex.pixels[y * texSize + x] = color(r, g, b);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createCreekTexture(int texSize) {
  // This is for creek as a wall (shouldn't really be used)
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.1 + frameCount * 0.01, y * 0.1);
      int r = int(30 + n * 20);
      int g = int(60 + n * 40);
      int b = int(100 + n * 50);
      tex.pixels[y * texSize + x] = color(r, g, b);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createGrassTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.2, y * 0.2);
      float n2 = noise(x * 0.5 + 100, y * 0.5 + 100);
      int g = int(55 + n * 35 + n2 * 15);
      int r = int(g * 0.6 + random(-5, 5));
      int b = int(g * 0.3 + random(-5, 5));
      tex.pixels[y * texSize + x] = color(r, g, b);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createCreekFloorTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.15, y * 0.15);
      float wave = sin(x * 0.3 + y * 0.1) * 0.2 + 0.8;
      int r = int((35 + n * 25) * wave);
      int g = int((70 + n * 40) * wave);
      int b = int((110 + n * 50) * wave);
      tex.pixels[y * texSize + x] = color(r, g, b);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createForestSkyboxTexture() {
  // Forest skybox with mountains in the distance
  int skyWidth = 1024;
  int skyHeight = 256;
  PImage sky = createImage(skyWidth, skyHeight, RGB);
  sky.loadPixels();
  
  // Create base sky gradient (morning forest sky)
  for (int y = 0; y < skyHeight; y++) {
    for (int x = 0; x < skyWidth; x++) {
      float gradientT = (float)y / skyHeight;
      // Lighter, slightly warmer sky for forest
      int r = int(lerp(160, 140, gradientT));
      int g = int(lerp(190, 160, gradientT));
      int b = int(lerp(230, 190, gradientT));
      sky.pixels[y * skyWidth + x] = color(r, g, b);
    }
  }
  
  // Add distant mountains
  for (int x = 0; x < skyWidth; x++) {
    // Create mountain silhouette using layered noise
    float mountainHeight = 0;
    
    // Large mountain shapes
    mountainHeight += noise(x * 0.003) * 120;
    // Medium details
    mountainHeight += noise(x * 0.01 + 50) * 40;
    // Small peaks
    mountainHeight += noise(x * 0.03 + 100) * 15;
    
    int mountainTop = skyHeight - int(mountainHeight) - 20;
    
    for (int y = mountainTop; y < skyHeight; y++) {
      // Gradient from lighter (distant) to darker at base
      float depth = (float)(y - mountainTop) / (skyHeight - mountainTop);
      float n = noise(x * 0.02, y * 0.02);
      
      // Blue-gray mountains (atmospheric perspective)
      int r = int(lerp(120, 60, depth) + n * 15);
      int g = int(lerp(130, 70, depth) + n * 15);
      int b = int(lerp(150, 90, depth) + n * 20);
      
      sky.pixels[y * skyWidth + x] = color(r, g, b);
    }
  }
  
  // Add some pine tree silhouettes in front of mountains
  for (int i = 0; i < 80; i++) {
    int treeX = int(random(skyWidth));
    int treeHeight = int(random(30, 70));
    int treeWidth = int(treeHeight * 0.4);
    int treeBase = skyHeight - 5;
    
    for (int ty = 0; ty < treeHeight; ty++) {
      // Triangle shape for pine
      float widthAtHeight = treeWidth * (1 - (float)ty / treeHeight);
      int startX = treeX - int(widthAtHeight / 2);
      int endX = treeX + int(widthAtHeight / 2);
      
      for (int tx = startX; tx <= endX; tx++) {
        int px = (tx + skyWidth) % skyWidth;
        int py = treeBase - ty;
        if (py >= 0 && py < skyHeight) {
          // Dark green silhouette
          float n = noise(tx * 0.1, ty * 0.1);
          int g = int(25 + n * 15);
          sky.pixels[py * skyWidth + px] = color(g * 0.4, g, g * 0.3);
        }
      }
    }
  }
  
  // Add wispy clouds
  for (int y = 0; y < skyHeight / 2; y++) {
    for (int x = 0; x < skyWidth; x++) {
      float cloudNoise = noise(x * 0.008, y * 0.015);
      float cloudNoise2 = noise(x * 0.02 + 200, y * 0.03 + 200);
      float cloudDensity = cloudNoise * 0.7 + cloudNoise2 * 0.3;
      
      if (cloudDensity > 0.55) {
        float intensity = map(cloudDensity, 0.55, 1.0, 0, 0.6);
        color currentColor = sky.pixels[y * skyWidth + x];
        float cr = red(currentColor);
        float cg = green(currentColor);
        float cb = blue(currentColor);
        
        int finalR = int(lerp(cr, 255, intensity));
        int finalG = int(lerp(cg, 255, intensity));
        int finalB = int(lerp(cb, 255, intensity));
        
        sky.pixels[y * skyWidth + x] = color(finalR, finalG, finalB);
      }
    }
  }
  
  sky.updatePixels();
  println("Created forest skybox texture: " + skyWidth + "x" + skyHeight);
  return sky;
}

// ========== CLASSIC MAP TEXTURES ==========

PImage createStoneBrickTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      int brick = ((x/16) + (y/16)) % 2;
      float noise = random(0.8, 1.2);
      int c = int(120 * noise * (brick == 0 ? 1 : 0.9));
      tex.pixels[y * texSize + x] = color(c, c, c);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createRedBrickTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      int brick = ((x/16) + (y/8)) % 2;
      float noise = random(0.8, 1.2);
      int c = int(150 * noise * (brick == 0 ? 1 : 0.85));
      tex.pixels[y * texSize + x] = color(c, c*0.3, c*0.2);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createBlueTechTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float noise = random(0.9, 1.1);
      int grid = (x % 8 == 0 || y % 8 == 0) ? 200 : 80;
      int c = int(grid * noise);
      tex.pixels[y * texSize + x] = color(c*0.3, c*0.4, c);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createMetalTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float noise = random(0.85, 1.15);
      int panel = (x/16) % 2;
      int rivet = (x % 16 < 2 && y % 16 < 2) ? 50 : 0;
      int c = int((100 + rivet) * noise * (panel == 0 ? 1 : 0.9));
      tex.pixels[y * texSize + x] = color(c*0.8, c*0.8, c);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createFloorTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float noise = random(0.9, 1.1);
      int c = int(60 * noise);
      tex.pixels[y * texSize + x] = color(c*0.6, c*0.6, c*0.5);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createCeilingTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float noise = random(0.9, 1.1);
      int c = int(40 * noise);
      tex.pixels[y * texSize + x] = color(c*0.5, c*0.5, c*0.6);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createBloodOverlay() {
  PImage overlay = createImage(400, 300, ARGB);
  overlay.loadPixels();
  int centerX = overlay.width / 2;
  int centerY = overlay.height / 2;
  float maxDist = dist(0, 0, centerX, centerY);
  for (int y = 0; y < overlay.height; y++) {
    for (int x = 0; x < overlay.width; x++) {
      float d = dist(x, y, centerX, centerY);
      float vignette = map(d, 0, maxDist, 0.3, 1.0);
      vignette = pow(vignette, 1.2);
      int alpha = int(vignette * 200);
      overlay.pixels[y * overlay.width + x] = color(255, 0, 0, alpha);
    }
  }
  overlay.updatePixels();
  return overlay;
}

PImage createBloodParticleTexture() {
  // Create a nice blood droplet/splat texture
  int size = 32;
  PImage tex = createImage(size, size, ARGB);
  tex.loadPixels();
  int centerX = size / 2;
  int centerY = size / 2;
  float maxRadius = size / 2.0;
  
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      float d = dist(x, y, centerX, centerY);
      
      if (d < maxRadius) {
        // Create a soft circular gradient with some noise for organic look
        float normalizedDist = d / maxRadius;
        float alpha = (1 - normalizedDist) * 255;
        alpha = pow(alpha / 255.0, 0.7) * 255; // Make it softer at edges
        
        // Add some noise for organic texture
        float noiseVal = random(0.8, 1.2);
        
        // Vary the red color for depth
        int r = int(constrain(180 * noiseVal, 100, 220));
        int g = int(random(0, 25));
        int b = int(random(0, 20));
        
        tex.pixels[y * size + x] = color(r, g, b, alpha * noiseVal);
      } else {
        tex.pixels[y * size + x] = color(0, 0, 0, 0);
      }
    }
  }
  tex.updatePixels();
  println("Created blood particle texture: " + size + "x" + size);
  return tex;
}

// ====== BEACH MAP TEXTURE GENERATION ======

PImage createSandTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.15, y * 0.15);
      float n2 = noise(x * 0.05 + 100, y * 0.05 + 100);
      int r = int(220 + n * 30 + n2 * 10);
      int g = int(200 + n * 25 + n2 * 10);
      int b = int(160 + n * 15 + n2 * 10);
      tex.pixels[y * texSize + x] = color(r, g, b);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createOceanTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.12, y * 0.12);
      float wave = sin(x * 0.4 + y * 0.2) * 0.15 + 0.85;
      float wave2 = sin(x * 0.25 - y * 0.15) * 0.1 + 0.9;
      int r = int((25 + n * 30) * wave * wave2);
      int g = int((100 + n * 40) * wave * wave2);
      int b = int((160 + n * 60) * wave * wave2);
      tex.pixels[y * texSize + x] = color(r, g, b);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createPalmTreeTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.2, y * 0.3);
      // Coconut fronds - green at top, trunk at bottom
      if (y < texSize * 0.4) {
        // Palm fronds - vibrant green
        int r = int(60 + n * 30);
        int g = int(140 + n * 40);
        int b = int(40 + n * 20);
        tex.pixels[y * texSize + x] = color(r, g, b);
      } else {
        // Trunk - brown with texture
        int r = int(120 + n * 50);
        int g = int(90 + n * 30);
        int b = int(50 + n * 20);
        tex.pixels[y * texSize + x] = color(r, g, b);
      }
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createPalmTreeTexture2(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.25, y * 0.25);
      if (y < texSize * 0.35) {
        // Slightly different shade of green for variety
        int r = int(50 + n * 35);
        int g = int(130 + n * 45);
        int b = int(35 + n * 25);
        tex.pixels[y * texSize + x] = color(r, g, b);
      } else {
        // Darker trunk
        int r = int(100 + n * 40);
        int g = int(75 + n * 25);
        int b = int(45 + n * 15);
        tex.pixels[y * texSize + x] = color(r, g, b);
      }
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createBeachHutTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.3, y * 0.3);
      if (y < texSize * 0.3) {
        // Thatched roof
        int r = int(180 + n * 40);
        int g = int(160 + n * 30);
        int b = int(90 + n * 20);
        tex.pixels[y * texSize + x] = color(r, g, b);
      } else {
        // Bamboo walls
        int r = int(200 + n * 30);
        int g = int(180 + n * 30);
        int b = int(120 + n * 25);
        tex.pixels[y * texSize + x] = color(r, g, b);
      }
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createBeachUmbrellaTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.2, y * 0.2);
      if (y < texSize * 0.5) {
        // Colorful umbrella top - bright stripes
        float stripe = sin(x * 0.5) > 0 ? 1.0 : 0.7;
        int r = int((200 + n * 40) * stripe);
        int g = int((80 + n * 30) * stripe);
        int b = int((120 + n * 40) * stripe);
        tex.pixels[y * texSize + x] = color(r, g, b);
      } else {
        // Pole - white/cream
        int r = int(230 + n * 20);
        int g = int(230 + n * 20);
        int b = int(220 + n * 15);
        tex.pixels[y * texSize + x] = color(r, g, b);
      }
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createBeachRockTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.15, y * 0.15);
      float n2 = noise(x * 0.05 + 50, y * 0.05 + 50);
      // Weathered beach rock - lighter than normal rock
      int r = int(180 + n * 40 + n2 * 20);
      int g = int(170 + n * 35 + n2 * 20);
      int b = int(160 + n * 30 + n2 * 15);
      tex.pixels[y * texSize + x] = color(r, g, b);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createCoralTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.25, y * 0.25);
      float n2 = noise(x * 0.1 + 200, y * 0.1 + 200);
      // Coral-like texture - pinkish/orange tones
      int r = int(150 + n * 60 + n2 * 30);
      int g = int(110 + n * 40 + n2 * 20);
      int b = int(100 + n * 30 + n2 * 15);
      tex.pixels[y * texSize + x] = color(r, g, b);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createShorelineWallTexture(int texSize) {
  // For when shoreline is treated as a wall (shouldn't happen often)
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float n = noise(x * 0.15, y * 0.15);
      int r = int(40 + n * 30);
      int g = int(110 + n * 40);
      int b = int(170 + n * 50);
      tex.pixels[y * texSize + x] = color(r, g, b);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createSunsetSkyboxTexture() {
  // Beautiful sunset skybox for beach map
  int skyWidth = 1024;
  int skyHeight = 256;
  PImage sky = createImage(skyWidth, skyHeight, RGB);
  sky.loadPixels();

  // Create stunning sunset gradient
  for (int y = 0; y < skyHeight; y++) {
    for (int x = 0; x < skyWidth; x++) {
      float gradientT = (float)y / skyHeight;
      float horizontalT = (float)x / skyWidth;

      // Multi-color sunset gradient
      int r, g, b;
      if (gradientT < 0.3) {
        // Top of sky - deep purple to orange
        float t = gradientT / 0.3;
        r = int(lerp(255, 120, t));
        g = int(lerp(180, 80, t));
        b = int(lerp(100, 130, t));
      } else if (gradientT < 0.6) {
        // Middle - vibrant oranges and pinks
        float t = (gradientT - 0.3) / 0.3;
        r = int(lerp(255, 255, t));
        g = int(lerp(150, 100, t));
        b = int(lerp(80, 50, t));
      } else {
        // Horizon - warm yellows
        float t = (gradientT - 0.6) / 0.4;
        r = int(lerp(255, 255, t));
        g = int(lerp(200, 160, t));
        b = int(lerp(100, 80, t));
      }

      // Add atmospheric haze near horizon
      if (gradientT > 0.7) {
        float haze = (gradientT - 0.7) / 0.3;
        r = int(lerp(r, 255, haze * 0.3));
        g = int(lerp(g, 220, haze * 0.3));
        b = int(lerp(b, 180, haze * 0.3));
      }

      sky.pixels[y * skyWidth + x] = color(r, g, b);
    }
  }

  // Add sun near horizon
  int sunX = skyWidth / 2;
  int sunY = int(skyHeight * 0.75);
  int sunRadius = 40;
  for (int y = sunY - sunRadius; y < sunY + sunRadius; y++) {
    for (int x = sunX - sunRadius; x < sunX + sunRadius; x++) {
      if (y >= 0 && y < skyHeight && x >= 0 && x < skyWidth) {
        float d = dist(x, y, sunX, sunY);
        if (d < sunRadius) {
          float intensity = 1 - (d / sunRadius);
          intensity = pow(intensity, 0.5); // Softer falloff
          color currentColor = sky.pixels[y * skyWidth + x];
          int r = int(lerp(red(currentColor), 255, intensity));
          int g = int(lerp(green(currentColor), 240, intensity * 0.8));
          int b = int(lerp(blue(currentColor), 150, intensity * 0.4));
          sky.pixels[y * skyWidth + x] = color(r, g, b);
        }
      }
    }
  }

  // Add a few wispy clouds
  for (int y = 0; y < skyHeight / 2; y++) {
    for (int x = 0; x < skyWidth; x++) {
      float cloudNoise = noise(x * 0.006, y * 0.02);
      float cloudNoise2 = noise(x * 0.015 + 300, y * 0.04 + 300);
      float cloudDensity = cloudNoise * 0.6 + cloudNoise2 * 0.4;

      if (cloudDensity > 0.6) {
        float intensity = map(cloudDensity, 0.6, 1.0, 0, 0.4);
        color currentColor = sky.pixels[y * skyWidth + x];
        int r = int(lerp(red(currentColor), 255, intensity));
        int g = int(lerp(green(currentColor), 200, intensity * 0.8));
        int b = int(lerp(blue(currentColor), 150, intensity * 0.6));
        sky.pixels[y * skyWidth + x] = color(r, g, b);
      }
    }
  }

  sky.updatePixels();
  return sky;
}

PImage createPalmTreeSprite() {
  // Create a palm tree sprite (flat, billboard-style) - slightly taller than player
  int w = 50;
  int h = 60;
  PImage sprite = createImage(w, h, ARGB);
  sprite.loadPixels();

  int centerX = w / 2;

  // Draw trunk
  for (int y = h/3; y < h; y++) {
    for (int x = centerX - 3; x < centerX + 3; x++) {
      if (x >= 0 && x < w) {
        float n = noise(x * 0.2, y * 0.1);
        int r = int(120 + n * 50);
        int g = int(90 + n * 30);
        int b = int(50 + n * 20);
        sprite.pixels[y * w + x] = color(r, g, b, 255);
      }
    }
  }

  // Draw palm fronds radiating from top
  int frondCount = 6;
  for (int i = 0; i < frondCount; i++) {
    float angle = (TWO_PI / frondCount) * i;
    int frondLength = 20;
    for (int d = 0; d < frondLength; d++) {
      int fx = centerX + int(cos(angle) * d);
      int fy = h/3 - int(sin(angle) * d * 0.2);
      int width = int(map(d, 0, frondLength, 4, 1));
      for (int wx = -width; wx <= width; wx++) {
        int px = fx + wx;
        int py = fy;
        if (px >= 0 && px < w && py >= 0 && py < h) {
          float n = noise(px * 0.1, py * 0.1);
          int r = int(60 + n * 30);
          int g = int(140 + n * 40);
          int b = int(40 + n * 20);
          sprite.pixels[py * w + px] = color(r, g, b, 255);
        }
      }
    }
  }

  sprite.updatePixels();
  return sprite;
}

PImage createPalmTreeSprite2() {
  // Variant with slightly different look - slightly taller than player
  int w = 45;
  int h = 55;
  PImage sprite = createImage(w, h, ARGB);
  sprite.loadPixels();

  int centerX = w / 2;

  // Slightly thinner trunk
  for (int y = h/3; y < h; y++) {
    for (int x = centerX - 2; x < centerX + 2; x++) {
      if (x >= 0 && x < w) {
        float n = noise(x * 0.25, y * 0.12);
        int r = int(100 + n * 40);
        int g = int(75 + n * 25);
        int b = int(45 + n * 15);
        sprite.pixels[y * w + x] = color(r, g, b, 255);
      }
    }
  }

  // Fewer, larger fronds
  int frondCount = 5;
  for (int i = 0; i < frondCount; i++) {
    float angle = (TWO_PI / frondCount) * i;
    int frondLength = 18;
    for (int d = 0; d < frondLength; d++) {
      int fx = centerX + int(cos(angle) * d);
      int fy = h/3 - int(sin(angle) * d * 0.2);
      int width = int(map(d, 0, frondLength, 4, 1));
      for (int wx = -width; wx <= width; wx++) {
        int px = fx + wx;
        int py = fy;
        if (px >= 0 && px < w && py >= 0 && py < h) {
          float n = noise(px * 0.15, py * 0.15);
          int r = int(50 + n * 35);
          int g = int(130 + n * 45);
          int b = int(35 + n * 25);
          sprite.pixels[py * w + px] = color(r, g, b, 255);
        }
      }
    }
  }

  sprite.updatePixels();
  return sprite;
}

PImage createBeachUmbrellaSprite() {
  // Beach umbrella sprite - similar height to player
  int w = 40;
  int h = 45;
  PImage sprite = createImage(w, h, ARGB);
  sprite.loadPixels();

  int centerX = w / 2;

  // Draw pole
  for (int y = h/2; y < h; y++) {
    for (int x = centerX - 1; x < centerX + 1; x++) {
      if (x >= 0 && x < w) {
        sprite.pixels[y * w + x] = color(230, 230, 220, 255);
      }
    }
  }

  // Draw umbrella canopy (semicircle with stripes)
  int canopyRadius = 18;
  int canopyTop = h/2 - 8;
  for (int y = canopyTop; y < canopyTop + canopyRadius; y++) {
    for (int x = 0; x < w; x++) {
      float dx = x - centerX;
      float dy = y - canopyTop;
      float d = sqrt(dx*dx + dy*dy);
      if (d < canopyRadius && dy >= 0) {
        // Create striped pattern
        boolean stripe = (int(atan2(dy, dx) * 3 / PI) % 2) == 0;
        if (stripe) {
          sprite.pixels[y * w + x] = color(200, 80, 120, 255);
        } else {
          sprite.pixels[y * w + x] = color(140, 60, 90, 255);
        }
      }
    }
  }

  sprite.updatePixels();
  return sprite;
}

PImage createSailboatSprite() {
  // Distant sailboat silhouette
  int w = 150;
  int h = 180;
  PImage sprite = createImage(w, h, ARGB);
  sprite.loadPixels();

  int centerX = w / 2;

  // Draw hull (boat body)
  for (int y = h - 30; y < h; y++) {
    int hullWidth = int(map(y, h - 30, h, 50, 70));
    for (int x = centerX - hullWidth/2; x < centerX + hullWidth/2; x++) {
      if (x >= 0 && x < w) {
        sprite.pixels[y * w + x] = color(180, 160, 140, 255);
      }
    }
  }

  // Draw mast (vertical pole)
  for (int y = 20; y < h - 30; y++) {
    for (int x = centerX - 3; x < centerX + 3; x++) {
      if (x >= 0 && x < w) {
        sprite.pixels[y * w + x] = color(120, 100, 80, 255);
      }
    }
  }

  // Draw sail (triangle)
  for (int y = 20; y < h - 40; y++) {
    int sailWidth = int(map(y, 20, h - 40, 5, 50));
    for (int x = centerX; x < centerX + sailWidth; x++) {
      if (x >= 0 && x < w) {
        sprite.pixels[y * w + x] = color(240, 240, 230, 255);
      }
    }
  }

  sprite.updatePixels();
  return sprite;
}

// Desert texture creation functions
PImage createDesertSandTexture(int texSize) {
  PImage tex = createImage(texSize, texSize, RGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float noise = random(0.9, 1.1);
      int r = int(210 * noise);
      int g = int(180 * noise);
      int b = int(120 * noise);
      tex.pixels[y * texSize + x] = color(r, g, b);
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createDesertRockTexture(int texSize) {
  // Sandy rock/sandstone texture for out-of-bounds walls (transparent)
  PImage tex = createImage(texSize, texSize, ARGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float noise = random(0.85, 1.15);
      int r = int(180 * noise);
      int g = int(150 * noise);
      int b = int(110 * noise);
      tex.pixels[y * texSize + x] = color(r, g, b, 0); // Alpha = 0 (fully transparent)
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createDesertBorderTexture(int texSize) {
  // Slightly darker sand for distant border (transparent)
  PImage tex = createImage(texSize, texSize, ARGB);
  tex.loadPixels();
  for (int y = 0; y < texSize; y++) {
    for (int x = 0; x < texSize; x++) {
      float noise = random(0.85, 1.05);
      int r = int(190 * noise);
      int g = int(160 * noise);
      int b = int(100 * noise);
      tex.pixels[y * texSize + x] = color(r, g, b, 0); // Alpha = 0 (fully transparent)
    }
  }
  tex.updatePixels();
  return tex;
}

PImage createDesertBorderFloorTexture(int texSize) {
  return createDesertBorderTexture(texSize);
}

PImage createDesertSkyboxTexture() {
  int w = 2048;
  int h = 512;
  PImage sky = createImage(w, h, RGB);
  sky.loadPixels();

  // Create base sky gradient - blend from blue at top to sandy desert color at bottom
  for (int y = 0; y < h; y++) {
    float t = (float)y / h;
    int topR = 135, topG = 206, topB = 235; // Sky blue at top
    int botR = 210, botG = 180, botB = 120; // Sandy desert color at bottom (matches floor)
    int r = int(lerp(topR, botR, t));
    int g = int(lerp(topG, botG, t));
    int b = int(lerp(topB, botB, t));
    for (int x = 0; x < w; x++) {
      sky.pixels[y * w + x] = color(r, g, b);
    }
  }

  // Add distant mountains on horizon (like forest map)
  for (int x = 0; x < w; x++) {
    // Create mountain silhouette using layered noise
    float mountainHeight = 0;

    // Large mountain shapes
    mountainHeight += noise(x * 0.002) * 100;
    // Medium details
    mountainHeight += noise(x * 0.008 + 50) * 35;
    // Small peaks
    mountainHeight += noise(x * 0.025 + 100) * 12;

    int mountainTop = h - int(mountainHeight) - 30;

    for (int y = mountainTop; y < h; y++) {
      // Gradient from slightly lighter to sandy desert floor color at base
      float depth = (float)(y - mountainTop) / max(1, (h - mountainTop));
      float n = noise(x * 0.015, y * 0.015);

      // Sandy desert mountains blending to desert floor color (210, 180, 120)
      int r = int(lerp(190, 210, depth) + n * 15);
      int g = int(lerp(165, 180, depth) + n * 12);
      int b = int(lerp(115, 120, depth) + n * 8);

      sky.pixels[y * w + x] = color(r, g, b);
    }
  }

  // Add some clouds
  for (int i = 0; i < 30; i++) {
    int cx = int(random(w));
    int cy = int(random(h * 0.2, h * 0.5));
    int cw = int(random(60, 120));
    int ch = int(random(20, 40));
    for (int y = max(0, cy - ch/2); y < min(h, cy + ch/2); y++) {
      for (int x = max(0, cx - cw/2); x < min(w, cx + cw/2); x++) {
        float dx = x - cx;
        float dy = y - cy;
        float dist = sqrt(dx*dx + dy*dy);
        if (dist < cw/2) {
          float alpha = map(dist, 0, cw/2, 0.6, 0);
          color current = sky.pixels[y * w + x];
          int r = int(lerp(red(current), 255, alpha));
          int g = int(lerp(green(current), 255, alpha));
          int b = int(lerp(blue(current), 255, alpha));
          sky.pixels[y * w + x] = color(r, g, b);
        }
      }
    }
  }

  sky.updatePixels();
  return sky;
}

PImage createFalloutSkyboxTexture() {
  int w = 2048;
  int h = 512;
  PImage sky = createImage(w, h, RGB);
  sky.loadPixels();

  // Create base grey sky gradient
  for (int y = 0; y < h; y++) {
    float t = (float)y / h;
    int topR = 100, topG = 100, topB = 100; // Grey
    int botR = 120, botG = 120, botB = 120; // Lighter grey
    int r = int(lerp(topR, botR, t));
    int g = int(lerp(topG, botG, t));
    int b = int(lerp(topB, botB, t));
    for (int x = 0; x < w; x++) {
      sky.pixels[y * w + x] = color(r, g, b);
    }
  }

  // Add same mountains but darker for fallout atmosphere
  for (int x = 0; x < w; x++) {
    float mountainHeight = 0;
    mountainHeight += noise(x * 0.002) * 100;
    mountainHeight += noise(x * 0.008 + 50) * 35;
    mountainHeight += noise(x * 0.025 + 100) * 12;

    int mountainTop = h - int(mountainHeight) - 30;

    for (int y = mountainTop; y < h; y++) {
      float depth = (float)(y - mountainTop) / (h - mountainTop);
      float n = noise(x * 0.015, y * 0.015);

      // Darker grey mountains for fallout
      int r = int(lerp(70, 50, depth) + n * 10);
      int g = int(lerp(70, 50, depth) + n * 10);
      int b = int(lerp(70, 50, depth) + n * 10);

      sky.pixels[y * w + x] = color(r, g, b);
    }
  }

  sky.updatePixels();
  return sky;
}

PImage createMountainsSprite() {
  int w = 1200;
  int h = 300;
  PImage sprite = createImage(w, h, ARGB);
  sprite.loadPixels();
  // Create mountain silhouette
  for (int x = 0; x < w; x++) {
    float peakHeight = h * 0.6 * (0.5 + 0.5 * sin(x * 0.01)) * (0.7 + 0.3 * sin(x * 0.03));
    int mountainTop = int(h - peakHeight);
    for (int y = 0; y < h; y++) {
      if (y >= mountainTop) {
        sprite.pixels[y * w + x] = color(60, 50, 40, 200);
      } else {
        sprite.pixels[y * w + x] = color(0, 0, 0, 0);
      }
    }
  }
  sprite.updatePixels();
  return sprite;
}

PImage createDesertObstacle1Sprite() {
  // Rock/boulder
  int w = 100;
  int h = 120;
  PImage sprite = createImage(w, h, ARGB);
  sprite.loadPixels();

  // Initialize all pixels to transparent
  for (int i = 0; i < sprite.pixels.length; i++) {
    sprite.pixels[i] = color(0, 0, 0, 0);
  }

  int centerX = w / 2;
  int centerY = h - 30;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      float dx = x - centerX;
      float dy = y - centerY;
      float dist = sqrt(dx*dx + dy*dy);
      if (dist < 40) {
        float noise = random(0.8, 1.1);
        int r = int(130 * noise);
        int g = int(110 * noise);
        int b = int(90 * noise);
        sprite.pixels[y * w + x] = color(r, g, b, 255);
      }
    }
  }
  sprite.updatePixels();
  return sprite;
}

PImage createDesertObstacle2Sprite() {
  // Cactus
  int w = 80;
  int h = 150;
  PImage sprite = createImage(w, h, ARGB);
  sprite.loadPixels();

  // Initialize all pixels to transparent
  for (int i = 0; i < sprite.pixels.length; i++) {
    sprite.pixels[i] = color(0, 0, 0, 0);
  }

  int centerX = w / 2;
  // Main trunk
  for (int y = h - 100; y < h; y++) {
    for (int x = centerX - 10; x < centerX + 10; x++) {
      if (x >= 0 && x < w) {
        sprite.pixels[y * w + x] = color(80, 120, 60, 255);
      }
    }
  }
  // Left arm
  for (int y = h - 70; y < h - 40; y++) {
    for (int x = centerX - 30; x < centerX - 10; x++) {
      if (x >= 0 && x < w) {
        sprite.pixels[y * w + x] = color(80, 120, 60, 255);
      }
    }
  }
  // Right arm
  for (int y = h - 60; y < h - 30; y++) {
    for (int x = centerX + 10; x < centerX + 30; x++) {
      if (x >= 0 && x < w) {
        sprite.pixels[y * w + x] = color(80, 120, 60, 255);
      }
    }
  }
  sprite.updatePixels();
  return sprite;
}

PImage createDesertObstacle3Sprite() {
  // Dead tree/shrub
  int w = 90;
  int h = 130;
  PImage sprite = createImage(w, h, ARGB);
  sprite.loadPixels();

  // Initialize all pixels to transparent
  for (int i = 0; i < sprite.pixels.length; i++) {
    sprite.pixels[i] = color(0, 0, 0, 0);
  }

  int centerX = w / 2;
  // Trunk
  for (int y = h - 80; y < h; y++) {
    for (int x = centerX - 8; x < centerX + 8; x++) {
      if (x >= 0 && x < w) {
        sprite.pixels[y * w + x] = color(90, 70, 50, 255);
      }
    }
  }
  // Branches
  for (int i = 0; i < 5; i++) {
    int branchY = int(random(h - 70, h - 20));
    int branchLength = int(random(15, 30));
    int direction = random(1) > 0.5 ? 1 : -1;
    for (int j = 0; j < branchLength; j++) {
      int bx = centerX + direction * j;
      int by = branchY - j / 3;
      if (bx >= 0 && bx < w && by >= 0 && by < h) {
        sprite.pixels[by * w + bx] = color(90, 70, 50, 255);
      }
    }
  }
  sprite.updatePixels();
  return sprite;
}

PImage createMushroomCloudSprite() {
  int w = 400;
  int h = 500;
  PImage sprite = createImage(w, h, ARGB);
  sprite.loadPixels();

  // Initialize all pixels to transparent
  for (int i = 0; i < sprite.pixels.length; i++) {
    sprite.pixels[i] = color(0, 0, 0, 0);
  }

  int centerX = w / 2;
  // Mushroom cap (top)
  int capCenterY = int(h * 0.25);
  int capRadius = 150;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      float dx = x - centerX;
      float dy = y - capCenterY;
      float dist = sqrt(dx*dx + dy*dy);
      if (dist < capRadius) {
        float alpha = map(dist, 0, capRadius, 255, 0);
        sprite.pixels[y * w + x] = color(80, 60, 50, int(alpha));
      }
    }
  }
  // Stem
  int stemWidth = 80;
  for (int y = int(h * 0.25); y < int(h * 0.8); y++) {
    int stemW = int(map(y, h * 0.25, h * 0.8, stemWidth, stemWidth * 1.5));
    for (int x = centerX - stemW/2; x < centerX + stemW/2; x++) {
      if (x >= 0 && x < w && y >= 0 && y < h) {
        sprite.pixels[y * w + x] = color(70, 55, 45, 220);
      }
    }
  }
  sprite.updatePixels();
  return sprite;
}

// Blood effect spawning functions
void spawnBloodSpray(float x, float y, float bulletAngle, int count) {
  for (int i = 0; i < count; i++) {
    float spreadAngle = bulletAngle + random(-0.5, 0.5);
    float speed = random(2, 6);
    float vx = cos(spreadAngle) * speed;
    float vy = sin(spreadAngle) * speed;
    int r = int(random(120, 200));
    int g = int(random(0, 30));
    int b = int(random(0, 20));
    color bloodColor = color(r, g, b);
    bloodParticles.add(new BloodParticle(x, y, vx, vy, bloodColor));
  }
}

void spawnBloodPool(float x, float y) {
  bloodPools.add(new BloodPool(x, y));
}

void spawnRandomWeapon() {
  int attempts = 0;
  float wx = 0, wy = 0;

  // Get current map dimensions
  int currentMapWidth = map[0].length;
  int currentMapHeight = map.length;

  while (attempts < 100) {
    int gx = int(random(2, currentMapWidth - 2));
    int gy = int(random(2, currentMapHeight - 2));
    if (map[gy][gx] == 0) {
      wx = gx * tileSize + tileSize/2;
      wy = gy * tileSize + tileSize/2;
      if (dist(wx, wy, player1.x, player1.y) > 150 && dist(wx, wy, player2.x, player2.y) > 150) break;
    }
    attempts++;
  }
  if (attempts < 100) {
    String type = random(1) > 0.5 ? "shotgun" : "rifle";
    weaponPickups.add(new WeaponPickup(wx, wy, type));
  }
}

void spawnRandomHealthKit() {
  int attempts = 0;
  float hx = 0, hy = 0;

  // Get current map dimensions
  int currentMapWidth = map[0].length;
  int currentMapHeight = map.length;

  while (attempts < 100) {
    int gx = int(random(2, currentMapWidth - 2));
    int gy = int(random(2, currentMapHeight - 2));
    if (map[gy][gx] == 0) {
      hx = gx * tileSize + tileSize/2;
      hy = gy * tileSize + tileSize/2;
      // Make sure it's not too close to players or existing pickups
      if (dist(hx, hy, player1.x, player1.y) > 100 &&
          dist(hx, hy, player2.x, player2.y) > 100) {
        // Also check it's not on top of a weapon
        boolean tooClose = false;
        for (WeaponPickup wp : weaponPickups) {
          if (dist(hx, hy, wp.x, wp.y) < 50) {
            tooClose = true;
            break;
          }
        }
        if (!tooClose) break;
      }
    }
    attempts++;
  }
  if (attempts < 100) {
    healthKits.add(new HealthKit(hx, hy));
    println("Spawned health kit at (" + hx + ", " + hy + ")");
  }
}

void drawSkybox(Player p, int w, int h) {
  // Map player's viewing angle to skybox texture position
  // The skybox wraps around 360 degrees (TWO_PI)
  
  int skyW = skyboxTexture.width;
  int skyH = skyboxTexture.height;
  int skyViewH = h / 2; // Sky takes up top half of screen
  
  // Calculate the starting position in the skybox based on player angle
  // Normalize angle to 0-TWO_PI range
  float normalizedAngle = p.angle;
  while (normalizedAngle < 0) normalizedAngle += TWO_PI;
  while (normalizedAngle >= TWO_PI) normalizedAngle -= TWO_PI;
  
  // Map the player's FOV to a portion of the skybox
  float fovRatio = fov / TWO_PI; // What fraction of 360 degrees we can see
  int viewWidthInSky = int(skyW * fovRatio); // How many pixels of skybox we see
  
  // Starting X position in skybox texture
  float startRatio = normalizedAngle / TWO_PI;
  int startX = int(startRatio * skyW);
  
  // Check if we need to wrap around
  int endX = startX + viewWidthInSky;
  
  if (endX <= skyW) {
    // No wrapping needed - draw single image section
    PImage section = skyboxTexture.get(startX, 0, viewWidthInSky, skyH);
    image(section, 0, 0, w, skyViewH);
  } else {
    // Need to wrap - draw two sections
    int firstWidth = skyW - startX;
    int secondWidth = viewWidthInSky - firstWidth;
    
    // First section (from startX to end of texture)
    PImage section1 = skyboxTexture.get(startX, 0, firstWidth, skyH);
    float screenWidth1 = w * ((float)firstWidth / viewWidthInSky);
    image(section1, 0, 0, screenWidth1, skyViewH);
    
    // Second section (from start of texture)
    PImage section2 = skyboxTexture.get(0, 0, secondWidth, skyH);
    image(section2, screenWidth1, 0, w - screenWidth1, skyViewH);
  }
}

void renderPlayer(Player p, int startX, int startY, int w, int h) {
  pushMatrix();

  // Set clipping region in screen coordinates to prevent viewport bleeding
  clip(startX, startY, w, h);

  translate(startX, startY);

  // Draw skybox
  if (skyboxTexture != null) {
    drawSkybox(p, w, h);
  } else {
    fill(100, 120, 150);
    rect(0, 0, w, h/2);
  }

  // Fill bottom half with base color (ocean for beach, sand for desert, will be covered by floor textures)
  if (currentMapIndex == 2) {
    fill(30, 120, 180); // Ocean blue for beach map
    noStroke();
    rect(0, h/2, w, h/2);
  } else if (currentMapIndex == 3) {
    fill(120 * 0.5, 100 * 0.5, 60 * 0.5); // Desert sand (darkened)
    noStroke();
    rect(0, h/2, w, h/2);
  }

  // Draw floor with textures
  drawFloorWithTextures(p, w, h);
  
  float rayAngle = p.angle - fov/2;
  float rayStep = fov / numRays;
  
  for (int i = 0; i < numRays; i++) {
    RayHit hit = castRay(p.x, p.y, rayAngle);
    if (hit != null && hit.wallType != 9) { // Skip rendering invisible barriers (tile 9)
      float distance = hit.distance * cos(rayAngle - p.angle);
      float wallHeight = (tileSize * h) / distance;

      // Safety check: ensure texture exists for this wall type
      if (hit.wallType >= wallTextures.length || wallTextures[hit.wallType] == null) {
        rayAngle += rayStep;
        continue;
      }

      PImage tex = wallTextures[hit.wallType];
      int texSize = tex.width;
      int texX = int(hit.textureX * texSize) % texSize;
      float x = map(i, 0, numRays, 0, w);
      float sliceWidth = w / float(numRays) + 1;
      float brightness = map(distance, 0, maxDepth, 1.0, 0.2);
      brightness = constrain(brightness, 0.2, 1.0);
      if (hit.horizontal) brightness *= 0.7;

      for (int y = 0; y < wallHeight; y++) {
        int texY = int(map(y, 0, wallHeight, 0, texSize)) % texSize;
        color c = tex.pixels[texY * texSize + texX];

        // Skip rendering if pixel is transparent (alpha < 10)
        if (alpha(c) < 10) continue;

        fill(red(c) * brightness, green(c) * brightness, blue(c) * brightness);
        noStroke();
        rect(x, h/2 - wallHeight/2 + y, sliceWidth, 2);
      }
    }
    rayAngle += rayStep;
  }
  
  // Draw blood pools (on ground, always behind sprites)
  for (BloodPool pool : bloodPools) {
    drawBloodPool(p, pool, w, h);
  }

  // Collect all sprites with distances for depth sorting
  ArrayList<SpriteDepth> spritesToRender = new ArrayList<SpriteDepth>();

  // Add beach obstacles
  if (currentMapIndex == 2) {
    for (BeachObstacle obs : beachObstacles) {
      float dx = obs.x - p.x;
      float dy = obs.y - p.y;
      float distance = sqrt(dx*dx + dy*dy);
      spritesToRender.add(new SpriteDepth(distance, "obstacle", obs));
    }
  }

  // Add desert obstacles
  if (currentMapIndex == 3) {
    for (BeachObstacle obs : desertObstacles) {
      float dx = obs.x - p.x;
      float dy = obs.y - p.y;
      float distance = sqrt(dx*dx + dy*dy);
      spritesToRender.add(new SpriteDepth(distance, "obstacle", obs));
    }
  }

  // Add other player
  Player other = (p == player1) ? player2 : player1;
  float otherDx = other.x - p.x;
  float otherDy = other.y - p.y;
  float otherDistance = sqrt(otherDx*otherDx + otherDy*otherDy);
  spritesToRender.add(new SpriteDepth(otherDistance, "player", other));

  // Add weapon pickups
  for (WeaponPickup wp : weaponPickups) {
    float dx = wp.x - p.x;
    float dy = wp.y - p.y;
    float distance = sqrt(dx*dx + dy*dy);
    spritesToRender.add(new SpriteDepth(distance, "weapon", wp));
  }

  // Add health kits
  for (HealthKit hk : healthKits) {
    float dx = hk.x - p.x;
    float dy = hk.y - p.y;
    float distance = sqrt(dx*dx + dy*dy);
    spritesToRender.add(new SpriteDepth(distance, "health", hk));
  }

  // Add blood particles
  for (BloodParticle bp : bloodParticles) {
    float dx = bp.x - p.x;
    float dy = bp.y - p.y;
    float distance = sqrt(dx*dx + dy*dy);
    spritesToRender.add(new SpriteDepth(distance, "blood", bp));
  }

  // Add bullets (all bullets visible to both players)
  for (Bullet b : bullets) {
    float dx = b.x - p.x;
    float dy = b.y - p.y;
    float distance = sqrt(dx*dx + dy*dy);
    spritesToRender.add(new SpriteDepth(distance, "bullet", b));
  }

  // Add sailboat (beach map only) - use very large distance so it renders behind everything
  if (currentMapIndex == 2) {
    spritesToRender.add(new SpriteDepth(maxDepth * 10, "sailboat", p));
  }

  // Add mushroom cloud (desert map only, after detonation) - render far behind walls like sailboat
  if (currentMapIndex == 3 && atomicBombDetonated) {
    spritesToRender.add(new SpriteDepth(maxDepth * 10, "mushroomcloud", p));
  }

  // Sort sprites by distance (farthest first) and render
  Collections.sort(spritesToRender);

  for (SpriteDepth sd : spritesToRender) {
    if (sd.type.equals("obstacle")) {
      drawBeachObstacle(p, (BeachObstacle)sd.data, w, h);
    } else if (sd.type.equals("player")) {
      drawOtherPlayer(p, (Player)sd.data, w, h);
    } else if (sd.type.equals("weapon")) {
      drawWeaponPickup(p, (WeaponPickup)sd.data, w, h);
    } else if (sd.type.equals("health")) {
      drawHealthKit(p, (HealthKit)sd.data, w, h);
    } else if (sd.type.equals("blood")) {
      drawBloodParticle(p, (BloodParticle)sd.data, w, h);
    } else if (sd.type.equals("bullet")) {
      Bullet b = (Bullet)sd.data;
      float dx = b.x - p.x;
      float dy = b.y - p.y;
      float distance = sqrt(dx*dx + dy*dy);
      float angle = atan2(dy, dx);
      float angleDiff = angle - p.angle;
      while (angleDiff > PI) angleDiff -= TWO_PI;
      while (angleDiff < -PI) angleDiff += TWO_PI;
      if (abs(angleDiff) < fov/2 + 0.5 && distance < maxDepth) {
        RayHit hit = castRay(p.x, p.y, angle);
        if (hit == null || hit.distance > distance) {
          float screenX = w/2 + (angleDiff / (fov/2)) * (w/2);
          float size = map(distance, 0, 300, 8, 2);

          // Check if bullet is within viewport bounds (prevent bleed to other player's screen)
          if (screenX + size/2 >= 0 && screenX - size/2 <= w) {
            fill(255, 255, 0, 200);
            noStroke();
            ellipse(screenX, h/2, size, size);
          }
        }
      }
    } else if (sd.type.equals("sailboat")) {
      drawSailboat((Player)sd.data, w, h);
    } else if (sd.type.equals("mushroomcloud")) {
      drawMushroomCloud((Player)sd.data, w, h);
    }
  }
  
  drawBloodOverlay(p, w, h);
  drawHUD(p, w, h);

  // Restore clipping to default
  noClip();

  popMatrix();
}

void drawFloorWithTextures(Player p, int w, int h) {
  // Draw textured floor using raycasting for each column
  float rayAngle = p.angle - fov/2;
  float rayStep = fov / numRays;

  for (int i = 0; i < numRays; i++) {
    float x = map(i, 0, numRays, 0, w);
    float sliceWidth = w / float(numRays) + 1;

    // For each vertical slice, draw floor texture from horizon down
    // Sample at intervals to balance performance and quality
    int stepSize = 2; // Sample every 2 pixels for performance

    for (int y = h/2; y < h; y += stepSize) {
      // Calculate distance to floor point at this screen y coordinate
      float screenDistance = float(y - h/2);
      if (screenDistance < 1) continue;

      // Calculate world distance to floor using perspective projection
      // The further from horizon, the closer the floor point
      float floorDistance = (h * tileSize) / (2.0 * screenDistance);

      if (floorDistance > maxDepth || floorDistance < 0.1) continue;

      // Calculate world position of floor point
      float worldX = p.x + cos(rayAngle) * floorDistance;
      float worldY = p.y + sin(rayAngle) * floorDistance;

      // Determine which tile this floor point is on
      int tileX = int(worldX / tileSize);
      int tileY = int(worldY / tileSize);

      // Check if tile is within map bounds
      if (tileX >= 0 && tileX < map[0].length && tileY >= 0 && tileY < map.length) {
        int tileType = map[tileY][tileX];

        // Select appropriate texture based on tile type
        PImage tex;
        if (tileType == 5 && creekTexture != null) {
          // Creek tile - use creek texture
          tex = creekTexture;
        } else if (tileType == 7 && shorelineTexture != null) {
          // Shoreline tile - use shoreline texture
          tex = shorelineTexture;
        } else if (tileType == 8 && desertBorderTexture != null) {
          // Desert border - distant sand texture
          tex = desertBorderTexture;
        } else if (tileType == 9 && currentMapIndex == 2) {
          // Beach map - ocean/invisible barrier shows as ocean water
          tex = shorelineTexture;
        } else if (tileType == 0 && floorTexture != null) {
          // Empty floor tile - use regular floor texture
          tex = floorTexture;
        } else {
          // Wall tile or missing texture - skip rendering (will show solid color)
          continue;
        }

        // Calculate texture coordinates
        int texSize = tex.width;
        int texX = int(worldX % tileSize / tileSize * texSize) % texSize;
        int texY = int(worldY % tileSize / tileSize * texSize) % texSize;

        if (texX < 0) texX += texSize;
        if (texY < 0) texY += texSize;

        // Sample texture
        color c = tex.pixels[texY * texSize + texX];

        // Apply distance-based brightness/fog
        float brightness = map(floorDistance, 0, maxDepth, 0.8, 0.2);
        brightness = constrain(brightness, 0.2, 0.8);

        // Draw the textured floor pixel
        fill(red(c) * brightness, green(c) * brightness, blue(c) * brightness);
        noStroke();
        rect(x, y, sliceWidth, stepSize);
      } else {
        // Out of bounds - draw solid color based on map theme
        if (currentMapIndex == 0) {
          fill(60 * 0.5, 50 * 0.5, 40 * 0.5); // Warehouse concrete (darkened)
        } else if (currentMapIndex == 2) {
          // Beach map - extend ocean infinitely in all directions
          fill(30 * 0.5, 120 * 0.5, 180 * 0.5); // Ocean blue (darkened)
        } else if (currentMapIndex == 3) {
          // Desert map - extend desert sand infinitely in all directions
          fill(120 * 0.5, 100 * 0.5, 60 * 0.5); // Desert sand (darkened)
        } else {
          fill(45 * 0.5, 65 * 0.5, 35 * 0.5); // Forest grass (darkened)
        }
        noStroke();
        rect(x, y, sliceWidth, stepSize);
      }
    }

    rayAngle += rayStep;
  }
}

void drawBloodParticle(Player viewer, BloodParticle bp, int w, int h) {
  float dx = bp.x - viewer.x;
  float dy = bp.y - viewer.y;
  float distance = sqrt(dx*dx + dy*dy);
  float angle = atan2(dy, dx);
  float angleDiff = angle - viewer.angle;
  while (angleDiff > PI) angleDiff -= TWO_PI;
  while (angleDiff < -PI) angleDiff += TWO_PI;
  if (abs(angleDiff) < fov/2 + 0.3 && distance < maxDepth && distance > 5) {
    RayHit hit = castRay(viewer.x, viewer.y, angle);
    if (hit == null || hit.distance > distance) {
      float screenX = w/2 + (angleDiff / (fov/2)) * (w/2);
      float baseY = h/2;
      float heightOffset = (bp.z * h) / distance;
      float screenY = baseY - heightOffset;
      float size = map(distance, 0, 300, 16, 4) * bp.size;

      // Check if sprite is within viewport bounds (prevent bleed to other player's screen)
      if (screenX - size/2 < 0 || screenX + size/2 > w) {
        return; // Sprite would extend outside viewport
      }

      float brightness = map(distance, 0, maxDepth, 1, 0.3);
      brightness = constrain(brightness, 0.3, 1);

      // Use texture if available, otherwise fall back to ellipse
      if (bloodParticleTexture != null) {
        pushStyle();
        imageMode(CENTER);
        tint(red(bp.bloodColor) * brightness, green(bp.bloodColor) * brightness, blue(bp.bloodColor) * brightness, bp.alpha);
        image(bloodParticleTexture, screenX, screenY, size, size);
        noTint();
        imageMode(CORNER);
        popStyle();
      } else {
        fill(red(bp.bloodColor) * brightness, green(bp.bloodColor) * brightness, blue(bp.bloodColor) * brightness, bp.alpha);
        noStroke();
        ellipse(screenX, screenY, size, size);
      }
    }
  }
}

void drawBloodPool(Player viewer, BloodPool pool, int w, int h) {
  float dx = pool.x - viewer.x;
  float dy = pool.y - viewer.y;
  float distance = sqrt(dx*dx + dy*dy);
  float angle = atan2(dy, dx);
  float angleDiff = angle - viewer.angle;
  while (angleDiff > PI) angleDiff -= TWO_PI;
  while (angleDiff < -PI) angleDiff += TWO_PI;
  if (abs(angleDiff) < fov/2 + 0.3 && distance < maxDepth && distance > 20) {
    RayHit hit = castRay(viewer.x, viewer.y, angle);
    if (hit == null || hit.distance > distance) {
      float screenX = w/2 + (angleDiff / (fov/2)) * (w/2);
      float floorY = h/2 + (30 * h) / distance;
      float poolWidth = (pool.currentSize * h) / distance;
      float poolHeight = poolWidth * 0.3; // Foreshortened for floor perspective
      
      // Skip if pool would draw outside viewport bounds
      if (screenX - poolWidth/2 < -poolWidth || screenX + poolWidth/2 > w + poolWidth) return;
      if (floorY < 0 || floorY > h) return;
      
      float brightness = map(distance, 0, maxDepth, 1, 0.3);
      brightness = constrain(brightness, 0.3, 1);
      
      // Use texture for blood pool if available
      if (bloodParticleTexture != null) {
        pushStyle();
        imageMode(CENTER);
        tint(140 * brightness, 15 * brightness, 15 * brightness, pool.alpha);
        // Draw multiple overlapping textures for pool effect
        image(bloodParticleTexture, screenX, floorY, poolWidth, poolHeight);
        image(bloodParticleTexture, screenX - poolWidth * 0.2, floorY, poolWidth * 0.7, poolHeight * 0.7);
        image(bloodParticleTexture, screenX + poolWidth * 0.15, floorY + poolHeight * 0.1, poolWidth * 0.6, poolHeight * 0.6);
        noTint();
        imageMode(CORNER);
        popStyle();
      } else {
        fill(120 * brightness, 10 * brightness, 10 * brightness, pool.alpha);
        noStroke();
        ellipse(screenX, floorY, poolWidth, poolHeight);
      }
    }
  }
}

void drawWeaponPickup(Player viewer, WeaponPickup wp, int w, int h) {
  float dx = wp.x - viewer.x;
  float dy = wp.y - viewer.y;
  float distance = sqrt(dx*dx + dy*dy);
  float angle = atan2(dy, dx);
  float angleDiff = angle - viewer.angle;
  while (angleDiff > PI) angleDiff -= TWO_PI;
  while (angleDiff < -PI) angleDiff += TWO_PI;
  if (abs(angleDiff) < fov/2 + 0.5 && distance < maxDepth) {
    RayHit hit = castRay(viewer.x, viewer.y, angle);
    if (hit == null || hit.distance > distance) {
      float screenX = w/2 + (angleDiff / (fov/2)) * (w/2);
      float spriteSize = (30 * h) / distance;
      if (screenX - spriteSize/2 < 0 || screenX + spriteSize/2 > w) return;
      float brightness = map(distance, 0, maxDepth, 1, 0.4);
      brightness = constrain(brightness, 0.4, 1);
      float bobHeight = sin(millis() * 0.003 + wp.x) * 8;
      PImage sprite = wp.type.equals("shotgun") ? shotgunPickupSprite : riflePickupSprite;
      pushMatrix();
      translate(screenX, h/2 + bobHeight);
      tint(255 * brightness);
      imageMode(CENTER);
      image(sprite, 0, 0, spriteSize, spriteSize);
      noTint();
      imageMode(CORNER);
      popMatrix();
      fill(255, 255, 0, 200 * brightness);
      textAlign(CENTER);
      textSize(12);
      text(wp.type.equals("shotgun") ? "SHOTGUN" : "RIFLE", screenX, h/2 + bobHeight - spriteSize/2 - 10);
    }
  }
}

void drawHealthKit(Player viewer, HealthKit hk, int w, int h) {
  float dx = hk.x - viewer.x;
  float dy = hk.y - viewer.y;
  float distance = sqrt(dx*dx + dy*dy);
  float angle = atan2(dy, dx);
  float angleDiff = angle - viewer.angle;
  while (angleDiff > PI) angleDiff -= TWO_PI;
  while (angleDiff < -PI) angleDiff += TWO_PI;
  if (abs(angleDiff) < fov/2 + 0.5 && distance < maxDepth) {
    RayHit hit = castRay(viewer.x, viewer.y, angle);
    if (hit == null || hit.distance > distance) {
      float screenX = w/2 + (angleDiff / (fov/2)) * (w/2);
      float spriteSize = (30 * h) / distance;
      if (screenX - spriteSize/2 < 0 || screenX + spriteSize/2 > w) return;
      float brightness = map(distance, 0, maxDepth, 1, 0.4);
      brightness = constrain(brightness, 0.4, 1);
      float bobHeight = sin(millis() * 0.004 + hk.x) * 10; // Slightly different bob
      pushMatrix();
      translate(screenX, h/2 + bobHeight);
      tint(255 * brightness);
      imageMode(CENTER);
      image(healthKitSprite, 0, 0, spriteSize, spriteSize);
      noTint();
      imageMode(CORNER);
      popMatrix();
      // Green text for health
      fill(0, 255, 0, 200 * brightness);
      textAlign(CENTER);
      textSize(12);
      text("HEALTH", screenX, h/2 + bobHeight - spriteSize/2 - 10);
    }
  }
}

void drawOtherPlayer(Player viewer, Player target, int w, int h) {
  float dx = target.x - viewer.x;
  float dy = target.y - viewer.y;
  float distance = sqrt(dx*dx + dy*dy);
  float angle = atan2(dy, dx);
  float angleDiff = angle - viewer.angle;
  while (angleDiff > PI) angleDiff -= TWO_PI;
  while (angleDiff < -PI) angleDiff += TWO_PI;
  if (abs(angleDiff) < fov/2 + 0.5 && distance < maxDepth) {
    RayHit hit = castRay(viewer.x, viewer.y, angle);
    if (hit == null || hit.distance > distance) {
      float screenX = w/2 + (angleDiff / (fov/2)) * (w/2);
      float playerHeight = (40 * h) / distance;
      float spriteWidth = playerHeight * 0.8;
      if (screenX - spriteWidth/2 < 0 || screenX + spriteWidth/2 > w) return;
      float brightness = map(distance, 0, maxDepth, 1, 0.3);
      brightness = constrain(brightness, 0.3, 1);
      
      boolean isDead = target.health <= 0;
      
      PImage playerSprite = (target == player1) ? player1Sprite : player2Sprite;
      if (playerSprite != null) {
        pushMatrix();
        translate(screenX, h/2);
        
        if (isDead) {
          // Dead player - rotate 90 degrees and position on ground
          translate(0, playerHeight * 0.3); // Move down to ground level
          rotate(HALF_PI); // Rotate 90 degrees
          tint(255 * brightness * 0.6); // Darken dead player
        } else {
          tint(255 * brightness);
        }
        
        imageMode(CENTER);
        image(playerSprite, 0, 0, playerHeight * 0.8, playerHeight);
        noTint();
        imageMode(CORNER);
        popMatrix();
      } else {
        pushMatrix();
        translate(screenX, h/2);
        
        if (isDead) {
          translate(0, playerHeight * 0.3);
          rotate(HALF_PI);
        }
        
        fill(red(target.teamColor) * brightness * (isDead ? 0.6 : 1), 
             green(target.teamColor) * brightness * (isDead ? 0.6 : 1), 
             blue(target.teamColor) * brightness * (isDead ? 0.6 : 1));
        noStroke();
        rectMode(CENTER);
        rect(0, 0, playerHeight * 0.5, playerHeight);
        rectMode(CORNER);
        popMatrix();
      }
      
      // Only show muzzle flash and health bar for alive players
      if (!isDead) {
        int timeSinceShot = millis() - target.lastActualShot;
        if (timeSinceShot < 100 && muzzleFlash != null) {
          float flashProgress = timeSinceShot / 100.0;
          float flashAlpha = (1 - flashProgress) * 255 * brightness;
          float flashSize = (playerHeight * 0.3) * (1 + flashProgress * 0.3);
          if (target == player1) {
            float flashX = screenX - playerHeight * 0.25;
            float flashY = h/2 - playerHeight * 0.2;
            pushStyle();
            tint(255, flashAlpha);
            imageMode(CENTER);
            image(muzzleFlash, flashX, flashY, flashSize, flashSize);
            noTint();
            imageMode(CORNER);
            popStyle();
          } else {
            float flashOffset = playerHeight * 0.35;
            float flashY = h/2 + playerHeight * 0.05;
            pushStyle();
            tint(255, flashAlpha);
            imageMode(CENTER);
            image(muzzleFlash, screenX - flashOffset, flashY, flashSize, flashSize);
            image(muzzleFlash, screenX + flashOffset, flashY, flashSize, flashSize);
            noTint();
            imageMode(CORNER);
            popStyle();
          }
        }
        float barWidth = playerHeight * 0.6;
        float barHeight = 5;
        fill(255, 0, 0);
        rect(screenX - barWidth/2, h/2 - playerHeight/2 - 15, barWidth, barHeight);
        fill(0, 255, 0);
        rect(screenX - barWidth/2, h/2 - playerHeight/2 - 15, barWidth * (target.health/100.0), barHeight);
      }
    }
  }
}

void drawHUD(Player p, int w, int h) {
  // Draw crosshair
  stroke(p.teamColor);
  strokeWeight(2);
  line(w/2 - 10, h/2, w/2 + 10, h/2);
  line(w/2, h/2 - 10, w/2, h/2 + 10);
  
  // Draw red cross hit marker if player recently hit someone
  int timeSinceHit = millis() - p.lastHitMarker;
  if (timeSinceHit < 300) {
    float hitAlpha = map(timeSinceHit, 0, 300, 255, 0);
    float hitSize = map(timeSinceHit, 0, 300, 12, 18);
    stroke(255, 0, 0, hitAlpha);
    strokeWeight(3);
    float offset = hitSize / 2;
    line(w/2 - offset, h/2 - offset, w/2 + offset, h/2 + offset);
    line(w/2 + offset, h/2 - offset, w/2 - offset, h/2 + offset);
    strokeWeight(2);
  }
  
  if (p.health > 0) {
    PImage currentGunSprite = gunSprite;
    float weaponSizeMultiplier = 1.0;
    if (p.currentWeapon.equals("shotgun")) {
      currentGunSprite = shotgunSprite;
      weaponSizeMultiplier = 1.4;
    } else if (p.currentWeapon.equals("rifle")) {
      currentGunSprite = rifleSprite;
      weaponSizeMultiplier = 1.35;
    }
    imageMode(CENTER);
    float gunY = h - 100;
    float gunScale = 1.0;
    float gunX = w/2;
    boolean isFiring = false;
    if (millis() - p.lastActualShot < 100) {
      isFiring = true;
      float recoilProgress = (millis() - p.lastActualShot) / 100.0;
      gunY -= 15 * (1 - recoilProgress);
      gunScale = 0.9 + 0.1 * recoilProgress;
    }
    float finalScale = gunScale * weaponSizeMultiplier;
    if (p.isMoving()) {
      float wobbleSpeed = 3.0;
      float wobbleAmount = 6.0;
      float wobbleX = sin(millis() * 0.01 * wobbleSpeed) * wobbleAmount;
      float wobbleY = abs(sin(millis() * 0.02 * wobbleSpeed)) * wobbleAmount * 0.5;
      gunX += wobbleX;
      gunY += wobbleY;
    }
    if (isFiring && muzzleFlash != null) {
      float flashProgress = (millis() - p.lastActualShot) / 100.0;
      float flashAlpha = (1 - flashProgress) * 255;
      float flashScale = (0.8 + flashProgress * 0.4) * weaponSizeMultiplier;
      float flashX = gunX - currentGunSprite.width * finalScale * 0.15;
      float flashY = gunY - currentGunSprite.height * finalScale * 0.35;
      pushStyle();
      tint(255, flashAlpha);
      image(muzzleFlash, flashX, flashY, muzzleFlash.width * flashScale, muzzleFlash.height * flashScale);
      noTint();
      popStyle();
    }
    image(currentGunSprite, gunX, gunY, currentGunSprite.width * finalScale, currentGunSprite.height * finalScale);
    imageMode(CORNER);
  }
  
  fill(255, 0, 0);
  rect(10, h - 40, 200, 20);
  fill(0, 255, 0);
  rect(10, h - 40, 200 * (p.health/100.0), 20);
  fill(255);
  textSize(20);
  textAlign(LEFT);
  text(p.name, 10, h - 50);
  text("HP: " + int(p.health), 10, h - 15);
  text("Kills: " + p.kills, 220, h - 15);
  
  // Display weapon and ammo
  if (p.currentWeapon.equals("pistol")) {
    // Show pistol ammo or reloading status
    if (p.reloading) {
      float reloadProgress = (millis() - p.reloadStartTime) / float(p.reloadTime);
      fill(255, 200, 0);
      text("RELOADING...", w - 220, h - 15);
      // Reload progress bar
      fill(100, 100, 100);
      rect(w - 220, h - 40, 100, 10);
      fill(255, 200, 0);
      rect(w - 220, h - 40, 100 * reloadProgress, 10);
    } else if (p.pistolAmmo <= 0) {
      // EMPTY - show flashing RELOAD! text
      fill(255, 255, 255);
      text("AMMO: 0/" + p.pistolMaxAmmo, w - 220, h - 15);
      
      // Big flashing RELOAD! text at bottom center
      float flashRate = 8.0; // Fast flashing
      float flash = (sin(millis() * 0.001 * flashRate * TWO_PI) + 1) / 2; // 0 to 1
      
      // Alternate between red and yellow
      if (flash > 0.5) {
        fill(255, 0, 0); // Red
      } else {
        fill(255, 255, 0); // Yellow
      }
      
      textAlign(CENTER);
      textSize(50);
      text("RELOAD!", w/2, h - 80);
      
      // Also add a smaller hint about the key
      textSize(16);
      fill(255, 255, 255, 150);
      String reloadKey = (p == player1) ? "[Q]" : "[/]";
      text("Press " + reloadKey + " to reload", w/2, h - 50);
      
      textAlign(LEFT);
      textSize(20);
    } else {
      fill(255, 255, 255);
      text("AMMO: " + p.pistolAmmo + "/" + p.pistolMaxAmmo, w - 220, h - 15);
    }
  } else {
    fill(255, 255, 0);
    text(p.currentWeapon.toUpperCase() + ": " + p.weaponAmmo, w - 220, h - 15);
  }
  if (p.health <= 0) {
    fill(255, 0, 0);
    textSize(40);
    textAlign(CENTER);
    text("RESPAWNING...", w/2, h/2 - 50);
  }
}

void drawBloodOverlay(Player p, int w, int h) {
  if (bloodOverlay == null) return;
  float alpha;
  if (p.health <= 0) alpha = 255;
  else if (p.health >= 100) alpha = 0;
  else if (p.health > 70) alpha = map(p.health, 100, 70, 0, 120);
  else alpha = map(p.health, 70, 0, 120, 255);
  if (alpha > 5) {
    pushStyle();
    tint(255, alpha);
    imageMode(CORNER);
    image(bloodOverlay, 0, 0, w, h);
    noTint();
    popStyle();
  }
}

void drawBeachObstacle(Player viewer, BeachObstacle obs, int w, int h) {
  // Safety check - skip if sprite is null
  if (obs == null || obs.sprite == null) return;

  float dx = obs.x - viewer.x;
  float dy = obs.y - viewer.y;
  float distance = sqrt(dx*dx + dy*dy);
  float angle = atan2(dy, dx);
  float angleDiff = angle - viewer.angle;
  while (angleDiff > PI) angleDiff -= TWO_PI;
  while (angleDiff < -PI) angleDiff += TWO_PI;

  if (abs(angleDiff) < fov/2 + 0.5 && distance < maxDepth) {
    RayHit hit = castRay(viewer.x, viewer.y, angle);
    if (hit == null || hit.distance > distance) {
      float screenX = w/2 + (angleDiff / (fov/2)) * (w/2);

      // Scale sprite based on distance - same scaling as player sprites
      float spriteHeight = (obs.sprite.height * h) / distance;
      float spriteWidth = (obs.sprite.width * spriteHeight) / obs.sprite.height;

      // Allow partial rendering - only skip if sprite center is far outside viewport
      if (screenX < -spriteWidth || screenX > w + spriteWidth) {
        return; // Sprite is completely off-screen
      }

      // Position sprite at eye level, then move up by quarter sprite height
      float screenY = h/2 - (spriteHeight / 4);

      float brightness = map(distance, 0, maxDepth, 1, 0.3);
      brightness = constrain(brightness, 0.3, 1);

      pushMatrix();
      translate(screenX, screenY);
      tint(255 * brightness);
      imageMode(CENTER);
      image(obs.sprite, 0, 0, spriteWidth, spriteHeight);
      noTint();
      imageMode(CORNER);
      popMatrix();
    }
  }
}

void drawSailboat(Player viewer, int w, int h) {
  // Sailboat appears when looking toward the ocean (south direction)
  // Ocean is at bottom of map (high Y), so south is PI/2
  if (sailboatSprite == null) return;

  // Safety check for sprite dimensions
  if (sailboatSprite.width <= 0 || sailboatSprite.height <= 0) return;

  float sailboatDirection = PI / 2; // 90 degrees (south, toward ocean)

  float angleDiff = sailboatDirection - viewer.angle;
  while (angleDiff > PI) angleDiff -= TWO_PI;
  while (angleDiff < -PI) angleDiff += TWO_PI;

  if (abs(angleDiff) < fov/2 + 0.3) {
    float screenX = w/2 + (angleDiff / (fov/2)) * (w/2);

    // Small sailboat on distant horizon
    float spriteHeight = h * 0.08; // Fixed small size (8% of screen height)
    float spriteWidth = (sailboatSprite.width * spriteHeight) / sailboatSprite.height;

    // Check if sprite is within viewport bounds (prevent bleed to other player's screen)
    if (screenX - spriteWidth/2 < 0 || screenX + spriteWidth/2 > w) {
      return; // Sprite would extend outside viewport
    }

    // Position sailboat above the horizon line (moved up by 1 sprite height)
    float horizonY = h / 2 - spriteHeight / 2;

    // Faded atmospheric appearance
    float brightness = 0.7;
    float alpha = 180;

    pushMatrix();
    translate(screenX, horizonY);
    tint(255 * brightness, alpha);
    imageMode(CENTER);
    image(sailboatSprite, 0, 0, spriteWidth, spriteHeight);
    noTint();
    imageMode(CORNER);
    popMatrix();
  }
}

void drawMountains(Player viewer, int w, int h) {
  // Mountains appear on the horizon in the desert map
  if (mountainsSprite == null) return;

  // Safety check for sprite dimensions
  if (mountainsSprite.width <= 0 || mountainsSprite.height <= 0) return;

  // Draw mountains as a repeating/tiled panoramic background on the horizon
  // Fixed height as percentage of screen
  float spriteHeight = h * 0.20; // Mountains are 20% of screen height
  float spriteWidth = (mountainsSprite.width * spriteHeight) / mountainsSprite.height;

  // Position mountains at horizon line
  float horizonY = h / 2 - spriteHeight / 2;

  // Faded atmospheric appearance
  float brightness = 0.5;
  float alpha = 120;

  pushMatrix();
  pushStyle();
  tint(255 * brightness, alpha);
  imageMode(CORNER);

  // Tile the mountains across the width if needed
  float x = -(frameCount * 0.1) % spriteWidth; // Slow pan effect
  while (x < w) {
    image(mountainsSprite, x, horizonY, spriteWidth, spriteHeight);
    x += spriteWidth;
  }

  noTint();
  imageMode(CORNER);
  popStyle();
  popMatrix();
}

void drawMushroomCloud(Player viewer, int w, int h) {
  // Mushroom cloud appears on the horizon after atomic bomb detonation
  // Positioned like sailboat - in a fixed direction on the horizon
  if (mushroomCloudSprite == null) return;

  // Safety check for sprite dimensions
  if (mushroomCloudSprite.width <= 0 || mushroomCloudSprite.height <= 0) return;

  // Position cloud in a fixed direction (south, same as sailboat)
  float cloudDirection = PI / 2; // 90 degrees (south, toward map edge)

  float angleDiff = cloudDirection - viewer.angle;
  while (angleDiff > PI) angleDiff -= TWO_PI;
  while (angleDiff < -PI) angleDiff += TWO_PI;

  // Only render if cloud is in view (slightly wider FOV than normal)
  if (abs(angleDiff) < fov/2 + 0.3) {
    float screenX = w/2 + (angleDiff / (fov/2)) * (w/2);

    // Large mushroom cloud on distant horizon - fixed size
    float spriteHeight = h * 0.35; // 35% of screen height
    float spriteWidth = (mushroomCloudSprite.width * spriteHeight) / mushroomCloudSprite.height;

    // Check if sprite is within viewport bounds (prevent bleed to other player's screen)
    if (screenX - spriteWidth/2 < 0 || screenX + spriteWidth/2 > w) {
      return; // Sprite would extend outside viewport
    }

    // Position mushroom cloud on horizon at crosshair level (at h/2)
    float horizonY = h / 2 - spriteHeight * 0.50;

    // Slightly faded atmospheric appearance
    float brightness = 0.75;
    float alpha = 200;

    pushMatrix();
    translate(screenX, horizonY);
    tint(255 * brightness, alpha);
    imageMode(CENTER);
    image(mushroomCloudSprite, 0, 0, spriteWidth, spriteHeight);
    noTint();
    imageMode(CORNER);
    popMatrix();
  }
}

RayHit castRay(float x, float y, float angle) {
  float rayDirX = cos(angle);
  float rayDirY = sin(angle);
  float dist = 0;
  float rayX = x;
  float rayY = y;

  // Get current map dimensions
  int currentMapWidth = map[0].length;
  int currentMapHeight = map.length;

  while (dist < maxDepth) {
    rayX += rayDirX * 2;
    rayY += rayDirY * 2;
    dist += 2;
    int gridX = int(rayX / tileSize);
    int gridY = int(rayY / tileSize);
    if (gridX < 0 || gridX >= currentMapWidth || gridY < 0 || gridY >= currentMapHeight) {
      return new RayHit(dist, 1, false, 0);
    }
    int tile = map[gridY][gridX];
    // Creek (5), shoreline (7), and desert border (8) are passable
    if (tile != 0 && tile != 5 && tile != 7 && tile != 8) {
      boolean horizontal = abs((rayY % tileSize) - tileSize/2) < abs((rayX % tileSize) - tileSize/2);
      float textureX = horizontal ? (rayX % tileSize) / tileSize : (rayY % tileSize) / tileSize;
      return new RayHit(dist, tile, horizontal, textureX);
    }
  }
  return null;
}

void checkPlayerHits() {
  for (Bullet b : bullets) {
    Player target = (b.owner == player1) ? player2 : player1;
    if (target.health > 0) {
      float d = dist(b.x, b.y, target.x, target.y);
      if (d < 20) {
        target.hit(b.damage);
        b.dead = true;
        spawnBloodSpray(target.x, target.y, b.angle, int(random(8, 15)));
        b.owner.lastHitMarker = millis();

        // Play random player-specific hit sound
        if (soundsLoaded) {
          if (target == player1) {
            if (random(1) < 0.5 && player1HitSound1 != null) {
              player1HitSound1.play();
            } else if (player1HitSound2 != null) {
              player1HitSound2.play();
            }
          } else {
            if (random(1) < 0.5 && player2HitSound1 != null) {
              player2HitSound1.play();
            } else if (player2HitSound2 != null) {
              player2HitSound2.play();
            }
          }
        }

        if (target.health <= 0) {
          b.owner.kills++;
          spawnBloodPool(target.x, target.y);

          // Check for atomic bomb trigger (desert map only)
          if (atomicBombEnabled && !atomicBombTriggered && currentMapIndex == 3) {
            int totalKills = player1.kills + player2.kills;
            if (totalKills >= atomicBombTriggerKills) {
              atomicBombTriggered = true;
              atomicBombTriggerTime = millis();
            }
          }

          // Play player-specific death sound
          if (soundsLoaded) {
            if (target == player1 && player1DeathSound != null) {
              player1DeathSound.play();
            } else if (target == player2 && player2DeathSound != null) {
              player2DeathSound.play();
            }
          }
        }
      }
    }
  }
}

boolean checkCollision(float x, float y) {
  int gridX = int(x / tileSize);
  int gridY = int(y / tileSize);

  // Get current map dimensions
  int currentMapWidth = map[0].length;
  int currentMapHeight = map.length;

  if (gridX < 0 || gridX >= currentMapWidth || gridY < 0 || gridY >= currentMapHeight) return true;
  int tile = map[gridY][gridX];
  // Creek (5) and shoreline (7) are passable, ocean (9) is not
  return tile != 0 && tile != 5 && tile != 7;
}

boolean checkCollisionWithRadius(float x, float y, float radius) {
  int gridX = int(x / tileSize);
  int gridY = int(y / tileSize);

  // Get current map dimensions
  int currentMapWidth = map[0].length;
  int currentMapHeight = map.length;

  if (gridX < 0 || gridX >= currentMapWidth || gridY < 0 || gridY >= currentMapHeight) return true;
  int tile = map[gridY][gridX];
  // Creek (5), shoreline (7), and desert border (8) are passable
  if (tile != 0 && tile != 5 && tile != 7 && tile != 8) return true;
  float[][] testPoints = {{x + radius, y}, {x - radius, y}, {x, y + radius}, {x, y - radius}};
  for (float[] point : testPoints) {
    int gx = int(point[0] / tileSize);
    int gy = int(point[1] / tileSize);
    if (gx < 0 || gx >= currentMapWidth || gy < 0 || gy >= currentMapHeight) return true;
    int t = map[gy][gx];
    // Creek (5), shoreline (7), and desert border (8) are passable
    if (t != 0 && t != 5 && t != 7 && t != 8) return true;
  }

  // Check beach obstacle collisions
  if (currentMapIndex == 2) {
    for (BeachObstacle obs : beachObstacles) {
      if (obs.collidesWith(x, y, radius)) {
        return true;
      }
    }
  }

  // Check desert obstacle collisions
  if (currentMapIndex == 3) {
    for (BeachObstacle obs : desertObstacles) {
      if (obs.collidesWith(x, y, radius)) {
        return true;
      }
    }
  }

  return false;
}

void keyPressed() {
  if (!gameStarted) {
    gameStarted = true;
    showInputSelect = true; // Show input selection menu first
    return;
  }
  if (showInputSelect) {
    if (key == 'k' || key == 'K') {
      useController = false;
      showInputSelect = false;
      showMapSelect = true;
    }
    if (key == 'c' || key == 'C') {
      useController = true;
      initializeControllers();
      showInputSelect = false;
      showMapSelect = true;
    }
    return;
  }
  if (showMapSelect) {
    if (key == 'a' || key == 'A' || keyCode == LEFT) {
      currentMapIndex = (currentMapIndex - 1 + numMaps) % numMaps;
      selectMap(currentMapIndex);
    }
    if (key == 'd' || key == 'D' || keyCode == RIGHT) {
      currentMapIndex = (currentMapIndex + 1) % numMaps;
      selectMap(currentMapIndex);
    }
    if (key == ' ' || keyCode == ENTER) {
      showMapSelect = false;
      showKillSelect = true;
    }
    return;
  }
  if (showKillSelect) {
    if (key == 'a' || key == 'A' || keyCode == LEFT) killsToWin = max(1, killsToWin - 1);
    if (key == 'd' || key == 'D' || keyCode == RIGHT) killsToWin = min(20, killsToWin + 1);
    if (key == ' ' || keyCode == ENTER) {
      showKillSelect = false;
      gameTrackStarted = false;
    }
    return;
  }
  if (gameEnded) {
    int timeSinceEnd = millis() - endScreenStartTime;
    int gunfireTime = 4000 + gunfireDelay;
    int restartAvailableTime = gunfireTime + 3000;
    if (timeSinceEnd >= restartAvailableTime) {
      resetGame();
    }
    return;
  }
  player1.keyPressed(key, keyCode, true);
  player2.keyPressed(key, keyCode, false);
}

void keyReleased() {
  player1.keyReleased(key, keyCode, true);
  player2.keyReleased(key, keyCode, false);
}

class RayHit {
  float distance;
  int wallType;
  boolean horizontal;
  float textureX;
  RayHit(float d, int w, boolean h, float tx) {
    distance = d;
    wallType = w;
    horizontal = h;
    textureX = tx;
  }
}

class Player {
  float x, y, angle;
  float speed = 5.5;
  float turnSpeed = 0.08;
  float health = 100;
  int kills = 0;
  color teamColor;
  String name;
  boolean wKey, aKey, sKey, dKey;
  boolean fireKeyHeld = false;
  boolean reloadBtnPressed = false; // For controller reload button tracking
  int lastShot = 0;
  int lastActualShot = 0; // Tracks when an actual bullet was fired (not empty click)
  int shotCooldown = 300;
  int respawnTime = 0;
  int lastHitMarker = 0;
  String currentWeapon = "pistol";
  int weaponAmmo = 0;
  
  // Pistol ammo and reload
  int pistolAmmo = 10;
  int pistolMaxAmmo = 10;
  boolean reloading = false;
  int reloadStartTime = 0;
  int reloadTime = 1500; // 1.5 seconds to reload
  
  Player(float x, float y, float angle, color c, String name) {
    this.x = x;
    this.y = y;
    this.angle = angle;
    this.teamColor = c;
    this.name = name;
  }
  
  void handleKeyboard(boolean isP1) {}
  
  boolean isMoving() { return wKey || sKey; }
  
  void keyPressed(char k, int kc, boolean isP1) {
    if (isP1) {
      if (k == 'w' || k == 'W') wKey = true;
      if (k == 'a' || k == 'A') aKey = true;
      if (k == 's' || k == 'S') sKey = true;
      if (k == 'd' || k == 'D') dKey = true;
      if (k == ' ') { fireKeyHeld = true; shoot(); }
      if (k == 'q' || k == 'Q') startReload(); // Reload key for P1
    } else {
      if (kc == UP) wKey = true;
      if (kc == LEFT) aKey = true;
      if (kc == DOWN) sKey = true;
      if (kc == RIGHT) dKey = true;
      if (kc == ENTER) { fireKeyHeld = true; shoot(); }
      if (k == '/' || k == '?') startReload(); // Reload key for P2
    }
  }
  
  void keyReleased(char k, int kc, boolean isP1) {
    if (isP1) {
      if (k == 'w' || k == 'W') wKey = false;
      if (k == 'a' || k == 'A') aKey = false;
      if (k == 's' || k == 'S') sKey = false;
      if (k == 'd' || k == 'D') dKey = false;
      if (k == ' ') fireKeyHeld = false;
    } else {
      if (kc == UP) wKey = false;
      if (kc == LEFT) aKey = false;
      if (kc == DOWN) sKey = false;
      if (kc == RIGHT) dKey = false;
      if (kc == ENTER) fireKeyHeld = false;
    }
  }
  
  void startReload() {
    // Only reload pistol when not already reloading and not full
    if (currentWeapon.equals("pistol") && !reloading && pistolAmmo < pistolMaxAmmo) {
      reloading = true;
      reloadStartTime = millis();
      if (soundsLoaded && reloadSound != null) reloadSound.play();
    }
  }
  
  void update() {
    if (health <= 0) {
      if (millis() - respawnTime > 3000) respawn();
      return;
    }
    
    // Check if reload is complete
    if (reloading && millis() - reloadStartTime >= reloadTime) {
      reloading = false;
      pistolAmmo = pistolMaxAmmo;
    }
    
    if (aKey) angle -= turnSpeed;
    if (dKey) angle += turnSpeed;
    float moveX = 0, moveY = 0;
    if (wKey) { moveX += cos(angle) * speed; moveY += sin(angle) * speed; }
    if (sKey) { moveX -= cos(angle) * speed; moveY -= sin(angle) * speed; }
    
    // Try full movement first
    float newX = x + moveX;
    float newY = y + moveY;
    
    // Check X and Y separately for sliding along walls
    if (!checkCollisionWithRadius(newX, y, 12)) {
      x = newX;
    } else if (moveX != 0) {
      // Try smaller step for X
      float smallX = x + moveX * 0.5;
      if (!checkCollisionWithRadius(smallX, y, 12)) x = smallX;
    }
    
    if (!checkCollisionWithRadius(x, newY, 12)) {
      y = newY;
    } else if (moveY != 0) {
      // Try smaller step for Y
      float smallY = y + moveY * 0.5;
      if (!checkCollisionWithRadius(x, smallY, 12)) y = smallY;
    }
    
    // Push player out if somehow stuck in a wall
    if (checkCollisionWithRadius(x, y, 10)) {
      // Find nearest open space
      for (float pushDist = 5; pushDist <= 30; pushDist += 5) {
        for (float pushAngle = 0; pushAngle < TWO_PI; pushAngle += PI/4) {
          float testX = x + cos(pushAngle) * pushDist;
          float testY = y + sin(pushAngle) * pushDist;
          if (!checkCollisionWithRadius(testX, testY, 12)) {
            x = testX;
            y = testY;
            break;
          }
        }
        if (!checkCollisionWithRadius(x, y, 10)) break;
      }
    }
    
    if (fireKeyHeld && currentWeapon.equals("rifle") && weaponAmmo > 0) shoot();
  }
  
  void pickupWeapon(String type) {
    currentWeapon = type;
    reloading = false; // Cancel any reload
    if (type.equals("shotgun")) { weaponAmmo = 4; shotCooldown = 800; }
    else if (type.equals("rifle")) { weaponAmmo = 30; shotCooldown = 100; }
  }
  
  void shoot() {
    if (health <= 0) return;
    if (reloading) return; // Can't shoot while reloading
    
    if (!currentWeapon.equals("pistol") && weaponAmmo <= 0) {
      currentWeapon = "pistol";
      shotCooldown = 300;
      weaponAmmo = 0;
    }
    
    // Check pistol ammo - play empty click sound, no auto-reload
    if (currentWeapon.equals("pistol") && pistolAmmo <= 0) {
      if (millis() - lastShot > shotCooldown) {
        if (soundsLoaded && emptyGunSound != null) emptyGunSound.play();
        lastShot = millis(); // Prevent sound spam
      }
      return;
    }
    
    if (millis() - lastShot > shotCooldown) {
      if (currentWeapon.equals("shotgun")) {
        for (int i = 0; i < 8; i++) {
          float spreadAngle = angle + random(-0.15, 0.15);
          bullets.add(new Bullet(x, y, spreadAngle, this, 12));
        }
        weaponAmmo--;
        if (soundsLoaded && shotgunSound != null) shotgunSound.play();
      } else if (currentWeapon.equals("rifle")) {
        bullets.add(new Bullet(x, y, angle, this, 25));
        weaponAmmo--;
        if (soundsLoaded && rifleSound != null) rifleSound.play();
      } else {
        // Pistol
        bullets.add(new Bullet(x, y, angle, this, 34));
        pistolAmmo--;
        if (soundsLoaded && shootSound != null) shootSound.play();
      }
      lastShot = millis();
      lastActualShot = millis(); // Track that a real shot happened
    }
  }
  
  void hit(float damage) {
    health -= damage;
    if (health <= 0) { health = 0; respawnTime = millis(); }
  }
  
  void respawn() {
    health = 100;
    currentWeapon = "pistol";
    weaponAmmo = 0;
    shotCooldown = 300;
    pistolAmmo = pistolMaxAmmo;
    reloading = false;
    
    // Find a random spawn point away from the other player
    Player other = (this == player1) ? player2 : player1;
    
    // Shuffle through spawn points to find one far from opponent
    int bestSpawn = 0;
    float bestDist = 0;
    
    for (int i = 0; i < spawnPoints.length; i++) {
      float spawnX = spawnPoints[i][0] * tileSize + tileSize/2;
      float spawnY = spawnPoints[i][1] * tileSize + tileSize/2;
      float d = dist(spawnX, spawnY, other.x, other.y);
      
      // Add some randomness so it's not always the farthest point
      d += random(-100, 100);
      
      if (d > bestDist) {
        bestDist = d;
        bestSpawn = i;
      }
    }
    
    x = spawnPoints[bestSpawn][0] * tileSize + tileSize/2;
    y = spawnPoints[bestSpawn][1] * tileSize + tileSize/2;

    // Face toward center of map
    float centerX = map[0].length * tileSize / 2;
    float centerY = map.length * tileSize / 2;
    angle = atan2(centerY - y, centerX - x);
  }
}

class Bullet {
  float x, y, angle;
  float speed = 18.75; // Increased by 25% (was 15)
  float maxDist = 500;
  float traveled = 0;
  boolean dead = false;
  float damage = 34;
  Player owner;
  
  Bullet(float x, float y, float angle, Player owner, float damage) {
    this.x = x;
    this.y = y;
    this.angle = angle;
    this.owner = owner;
    this.damage = damage;
  }
  
  void update() {
    x += cos(angle) * speed;
    y += sin(angle) * speed;
    traveled += speed;
    if (checkCollision(x, y)) {
      dead = true;
    }
    // Check collision with beach obstacles
    if (currentMapIndex == 2) {
      for (BeachObstacle obs : beachObstacles) {
        float dx = x - obs.x;
        float dy = y - obs.y;
        float distance = sqrt(dx*dx + dy*dy);
        if (distance < obs.radius) {
          dead = true;
          break;
        }
      }
    }
    // Check collision with desert obstacles
    if (currentMapIndex == 3) {
      for (BeachObstacle obs : desertObstacles) {
        float dx = x - obs.x;
        float dy = y - obs.y;
        float distance = sqrt(dx*dx + dy*dy);
        if (distance < obs.radius) {
          dead = true;
          break;
        }
      }
    }
    if (traveled > maxDist) dead = true;
  }
}

class WeaponPickup {
  float x, y;
  String type;
  WeaponPickup(float x, float y, String type) {
    this.x = x;
    this.y = y;
    this.type = type;
  }
}

class BloodParticle {
  float x, y, z;
  float vx, vy, vz;
  float gravity = 0.15;
  float size;
  color bloodColor;
  float alpha = 255;
  float fadeRate;
  boolean dead = false;
  
  BloodParticle(float x, float y, float vx, float vy, color bloodColor) {
    this.x = x;
    this.y = y;
    this.z = random(10, 30);
    this.vx = vx;
    this.vy = vy;
    this.vz = random(1, 4);
    this.bloodColor = bloodColor;
    this.size = random(0.5, 1.5);
    this.fadeRate = random(2, 5);
  }
  
  void update() {
    x += vx;
    y += vy;
    z += vz;
    vz -= gravity;
    vx *= 0.98;
    vy *= 0.98;
    alpha -= fadeRate;
    if (z <= 0 || alpha <= 0) dead = true;
    if (checkCollision(x, y)) dead = true;
  }
}

class BloodPool {
  float x, y;
  float maxSize = 40;
  float currentSize = 5;
  float growRate = 0.5;
  float alpha = 200;
  boolean dead = false;
  int createTime;
  int lifetime = 10000;
  boolean growing = true;
  
  BloodPool(float x, float y) {
    this.x = x;
    this.y = y;
    this.createTime = millis();
  }
  
  void update() {
    int age = millis() - createTime;
    if (growing && currentSize < maxSize) {
      currentSize += growRate;
      if (currentSize >= maxSize) growing = false;
    }
    if (age > lifetime) alpha -= 1.5;
    if (alpha <= 0) dead = true;
  }
}

class HealthKit {
  float x, y;

  HealthKit(float x, float y) {
    this.x = x;
    this.y = y;
  }
}

class BeachObstacle {
  float x, y;
  float radius; // Collision radius
  PImage sprite;
  String type; // "palm1", "palm2", "umbrella"

  BeachObstacle(float x, float y, float radius, PImage sprite, String type) {
    this.x = x;
    this.y = y;
    this.radius = radius;
    this.sprite = sprite;
    this.type = type;
  }

  boolean collidesWith(float px, float py, float playerRadius) {
    float dx = px - this.x;
    float dy = py - this.y;
    float distance = sqrt(dx*dx + dy*dy);
    return distance < (this.radius + playerRadius);
  }
}

// Helper class for depth-sorted sprite rendering
class SpriteDepth implements Comparable<SpriteDepth> {
  float distance;
  String type; // "obstacle", "player", "weapon", "health", "blood", "bullet"
  Object data; // Store the actual object to render

  SpriteDepth(float distance, String type, Object data) {
    this.distance = distance;
    this.type = type;
    this.data = data;
  }

  int compareTo(SpriteDepth other) {
    // Sort by distance descending (farthest first)
    return Float.compare(other.distance, this.distance);
  }
}

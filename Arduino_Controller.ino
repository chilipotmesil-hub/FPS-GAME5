/*
 * FPS GAME CONTROLLER - Arduino Code
 *
 * Hardware Requirements:
 * - 1x 5-pin Analog Joystick (VCC, GND, X, Y, SW)
 * - 1x Push Button (Fire button)
 * - (Optional) 2x 10kΩ resistors for pull-up if not using INPUT_PULLUP
 *
 * Controls:
 * - Joystick X/Y axes: Player movement and turning
 * - Joystick button (press down): RELOAD
 * - External button: FIRE
 *
 * Wiring:
 * - Joystick VCC -> 5V
 * - Joystick GND -> GND
 * - Joystick VRx -> A0
 * - Joystick VRy -> A1
 * - Joystick SW -> Pin 2 (with internal pull-up)
 * - Fire Button -> Pin 3 (with internal pull-up)
 *
 * Data Format Sent:
 * "joyX,joyY,fire,reload\n"
 * Example: "512,480,1,0" = joystick centered, fire pressed, reload not pressed
 */

// Pin definitions
const int JOY_X = A0;        // Joystick X-axis (analog)
const int JOY_Y = A1;        // Joystick Y-axis (analog)
const int JOY_SW = 2;        // Joystick button (digital) - press down on stick to reload
const int BTN_FIRE = 3;      // Fire button (digital) - press to fire

// Variables to store current state
int joyXValue = 0;
int joyYValue = 0;
int fireButtonState = 0;
int reloadButtonState = 0;

void setup() {
  // Initialize serial communication at 9600 baud
  Serial.begin(9600);

  // Set up digital pins with internal pull-up resistors
  // Pull-up means the pin reads HIGH when button is not pressed
  // and LOW when button is pressed
  pinMode(JOY_SW, INPUT_PULLUP);
  pinMode(BTN_FIRE, INPUT_PULLUP);

  // Optional: Add a small delay to let the serial connection stabilize
  delay(100);
}

void loop() {
  // Read analog joystick values (0-1023 range)
  joyXValue = analogRead(JOY_X);
  joyYValue = analogRead(JOY_Y);

  // Read digital button states
  // Using INPUT_PULLUP, so we need to invert:
  // digitalRead returns LOW (0) when pressed, HIGH (1) when not pressed
  // We want: 1 when pressed, 0 when not pressed
  fireButtonState = !digitalRead(BTN_FIRE);      // 1 = pressed, 0 = not pressed
  reloadButtonState = !digitalRead(JOY_SW);      // 1 = pressed, 0 = not pressed

  // Send data in CSV format: "joyX,joyY,fire,reload"
  Serial.print(joyXValue);
  Serial.print(",");
  Serial.print(joyYValue);
  Serial.print(",");
  Serial.print(fireButtonState);
  Serial.print(",");
  Serial.println(reloadButtonState);  // println adds newline character

  // Small delay to prevent overwhelming the serial buffer
  // 50ms = 20 updates per second, which is plenty for game controls
  delay(50);
}

#include <Wire.h>
#include <Adafruit_Protomatter.h>
#include <Adafruit_GFX.h>

// Macros varied frequently in testing: 
#define DIMENSION 64 // Number of LED blocks in each ROW/COL of transmission 
#define NUM_FRAMES 21
#define FRAME_DELAY 0

// Static macros:
#define WIDTH  64
#define HEIGHT 64
#define CELL_SIZE (64/DIMENSION)
#define NUM_COLUMNS DIMENSION
#define NUM_ROWS DIMENSION
#define BLOCKS_PER_FRAME (DIMENSION * DIMENSION - 2) 
#define CLOCK_BLOCK NUM_COLUMNS*(NUM_ROWS-1)+(NUM_COLUMNS/2)
#define BITS_PER_CHANNEL 1
#define BITS_PER_BLOCK 3*(BITS_PER_CHANNEL)
#define FRAME_BITS (BLOCKS_PER_FRAME * BITS_PER_BLOCK)
#define TOTAL_BITS (FRAME_BITS * NUM_FRAMES)

#if defined(_VARIANT_MATRIXPORTAL_M4_)
uint8_t rgbPins[]  = {7, 8, 9, 10, 11, 12};
uint8_t addrPins[] = {17, 18, 19, 20, 21};
uint8_t clockPin   = 14;
uint8_t latchPin   = 15;
uint8_t oePin      = 16;
#else
uint8_t rgbPins[]  = {42, 41, 40, 38, 39, 37};
uint8_t addrPins[] = {45, 36, 48, 35, 21};
uint8_t clockPin   = 2;
uint8_t latchPin   = 47;
uint8_t oePin      = 14;
#endif

#if HEIGHT == 16
#define NUM_ADDR_PINS 3
#elif HEIGHT == 32
#define NUM_ADDR_PINS 4
#elif HEIGHT == 64
#define NUM_ADDR_PINS 5
#endif

Adafruit_Protomatter matrix(
  WIDTH, 4, 1, rgbPins, NUM_ADDR_PINS, addrPins,
  clockPin, latchPin, oePin, true);

uint16_t colorLUT[8];

void setupColors() {
  colorLUT[0] = matrix.color565(0, 0, 0);
  colorLUT[1] = matrix.color565(0, 0, 255);
  colorLUT[2] = matrix.color565(0, 255, 0);
  colorLUT[3] = matrix.color565(0, 255, 255);
  colorLUT[4] = matrix.color565(255, 0, 0);
  colorLUT[5] = matrix.color565(255, 0, 255);
  colorLUT[6] = matrix.color565(255, 255, 0);
  colorLUT[7] = matrix.color565(255, 255, 255);
}

uint8_t bitsToIndex(const char* stream, int start) {
  return ((stream[start]   - '0') << 2) |
         ((stream[start+1] - '0') << 1) |
         ((stream[start+2] - '0') << 0);
}

void setup() {
  Serial.begin(9600);
  delay(2000);

  if (matrix.begin() != PROTOMATTER_OK) {
    while (1);
  }

  setupColors();

  const char* bitStream = "10101010...";              // Insert bitstream generated from message_to_bits_RS.py
  
  matrix.fillRect(0, 0, WIDTH, HEIGHT, colorLUT[7]);  // Start with white
  matrix.show();
  delay(2000);

  Serial.print("Beginning ");
  Serial.print(NUM_FRAMES);
  Serial.println("-frame transmission...\n");

  for (int frame = 0; frame < NUM_FRAMES; frame++) {
    Serial.print("Frame ");
    Serial.println(frame + 1);

    int frameStart = frame * FRAME_BITS;

    for (int i = 0; i < BLOCKS_PER_FRAME; i++) {
      if (i==CLOCK_BLOCK){
        break;
      }
      int bitStart = frameStart + i * 3;
      uint8_t index = bitsToIndex(bitStream, bitStart);
      uint16_t color = colorLUT[index];

      int gridX = i % (WIDTH / CELL_SIZE);
      int gridY = i / (WIDTH / CELL_SIZE);

      int x = (HEIGHT / CELL_SIZE - 1 - gridY) * CELL_SIZE;
      int y = gridX * CELL_SIZE;

      matrix.fillRect(x, y, CELL_SIZE, CELL_SIZE, color);
    }
    for (int j = CLOCK_BLOCK; j < BLOCKS_PER_FRAME+1; j++) {
      int bitStart = frameStart + (j-1) * 3;
      uint8_t index = bitsToIndex(bitStream, bitStart);
      uint16_t color = colorLUT[index];

      int gridX = j % (WIDTH / CELL_SIZE); 
      int gridY = j / (WIDTH / CELL_SIZE); 

      int x = (HEIGHT / CELL_SIZE - 1 - gridY) * CELL_SIZE;
      int y = gridX * CELL_SIZE;

      matrix.fillRect(x, y, CELL_SIZE, CELL_SIZE, color);
    }

    uint16_t clockColor = ((frame+1) % 2 == 0) ? matrix.color565(255, 255, 255) : matrix.color565(0, 0, 0);
    matrix.fillRect(0, WIDTH/2, CELL_SIZE, CELL_SIZE, clockColor);  // bottom center
    matrix.fillRect(0, WIDTH*(NUM_COLUMNS-1)/NUM_COLUMNS, CELL_SIZE, CELL_SIZE, clockColor);   // bottom right

    matrix.show();
    delay(FRAME_DELAY);
  }

  Serial.println("\nTransmission complete.");
}

void loop() {
  matrix.fillScreen(colorLUT[(NUM_FRAMES % 2 == 0) ? 0 : 7 ]); 
  matrix.show();
}

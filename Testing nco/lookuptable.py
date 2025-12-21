import math

# Settings
depth = 256       # How many lines in your table (2^8)
width = 8         # Width of output data (8-bit audio)

for i in range(depth):
    # Calculate 0 to 2*PI
    angle = (i / depth) * 2 * math.pi
    
    # Calculate Sine (-1 to +1) -> Scale to (0 to 255)
    val = (math.sin(angle) + 1) * (2**width - 1) / 2
    
    # Print as Hex
    print(f'x"{int(round(val)):02X}",', end=" ")
    if (i + 1) % 8 == 0: print("") # Newline every 8 values
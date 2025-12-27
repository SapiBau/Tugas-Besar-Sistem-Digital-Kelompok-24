import scipy.io.wavfile as wav
import numpy as np

# CONFIGURATION
INPUT_WAV = 'fm_signal.wav'
OUTPUT_TXT = 'simulation_input.txt'

def convert_wav_to_hex():
    print(f"Reading {INPUT_WAV}...")
    try:
        fs, data = wav.read(INPUT_WAV)
        
        # Ensure data is 8-bit unsigned (0-255)
        if data.dtype != np.uint8:
            print("Converting to 8-bit Unsigned...")
            # Normalize to 0-255 if it isn't already
            data = ((data - data.min()) / (data.max() - data.min()) * 255).astype(np.uint8)

        print(f"Writing {len(data)} samples to {OUTPUT_TXT}...")
        
        with open(OUTPUT_TXT, 'w') as f:
            for sample in data:
                # Write as 2-digit Hex (e.g., "A5", "03", "FF")
                f.write(f"{sample:02X}\n")
                
        print("Done! You can now load 'simulation_input.txt' into Questa.")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    convert_wav_to_hex()
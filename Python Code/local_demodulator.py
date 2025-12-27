import numpy as np
import scipy.io.wavfile as wav
import scipy.signal as signal

# CONFIGURATION
INPUT_FILE = 'fm_signal.wav'
OUTPUT_FILE = 'verified_software_demod.wav'

def verify_modulation():
    print(f"Analyzing {INPUT_FILE}...")
    
    try:
        # 1. Read the FM Signal
        fs, data = wav.read(INPUT_FILE)
        
        # Convert 8-bit (0-255) back to float (-1.0 to 1.0)
        # This reverses the conversion we did in the modulator
        signal_float = (data.astype(np.float32) - 127.5) / 127.5

        # 2. Demodulate (The Math)
        # We use the Hilbert Transform to find the instantaneous angle (phase)
        print("Calculating instantaneous frequency...")
        analytic_signal = signal.hilbert(signal_float)
        instantaneous_phase = np.unwrap(np.angle(analytic_signal))
        
        # Frequency is the rate of change (derivative) of Phase
        instantaneous_freq = np.diff(instantaneous_phase)

        # 3. Filter the Result
        # Remove the DC Offset (which represents the Carrier Frequency)
        # The remaining signal is the audio deviations.
        audio_signal = instantaneous_freq - np.mean(instantaneous_freq)

        # 4. Check Signal Strength
        max_val = np.max(np.abs(audio_signal))
        print(f"Detected Max Deviation: {max_val:.6f}")
        
        if max_val < 0.01:
            print("WARNING: The modulation is extremely weak!")
            print("The FPGA probably can't detect these tiny changes.")
            print("Solution: Increase MODULATION_INDEX in your modulator script.")
        else:
            print("Signal strength looks good.")

        # 5. Normalize and Save
        # Boost volume to max so you can hear it clearly
        audio_signal = audio_signal / max_val
        
        # Convert to 16-bit PCM for standard media players
        audio_int16 = (audio_signal * 32767).astype(np.int16)
        
        wav.write(OUTPUT_FILE, fs, audio_int16)
        print(f"Success! Listen to '{OUTPUT_FILE}' to hear what the file contains.")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    verify_modulation()
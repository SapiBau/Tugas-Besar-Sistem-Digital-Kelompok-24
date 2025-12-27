import numpy as np
import scipy.io.wavfile as wav
import scipy.signal as signal

INPUT_WAV   = 'input.wav'        # Put your song here!
OUTPUT_FM   = 'fm_signal.wav'    
SAMPLE_RATE = 10000              # 10 kHz Sample Rate
CARRIER_FREQ_NORMALIZED = 0.25
MODULATION_INDEX        = 2.0 

def generate_fm_signal():
    try:
        fs, data = wav.read(INPUT_WAV)
        if len(data.shape) > 1: data = data[:, 0] # Mono
        
        # Resample
        num_samples = int(len(data) * SAMPLE_RATE / fs)
        data = signal.resample(data, num_samples)
        
        # Modulate
        # Normalize to +/- 1.0
        data = data.astype(np.float32) / np.max(np.abs(data))
        
        # Integrate for Phase
        phase_deviation = np.cumsum(data)
        t = np.arange(len(data))
        
        # FM Equation
        phase = 2 * np.pi * (CARRIER_FREQ_NORMALIZED * t + MODULATION_INDEX * phase_deviation)
        fm_signal = np.sin(phase)
        
        # Convert to 0-255
        fm_unsigned = ((fm_signal + 1.0) * 127.5).astype(np.uint8)
        
        wav.write(OUTPUT_FM, SAMPLE_RATE, fm_unsigned)
        print(f"Generated {OUTPUT_FM} successfully.")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    generate_fm_signal()
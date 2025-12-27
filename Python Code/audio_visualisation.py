import numpy as np
import scipy.io.wavfile as wav
import matplotlib.pyplot as plt
import sys
import os

# CONFIGURATION
# You can change this to 'fm_signal.wav' or 'input.wav' too
FILENAME = 'demodulated_audio.wav' 

def plot_waveform():
    if not os.path.exists(FILENAME):
        print(f"Error: {FILENAME} not found.")
        return

    print(f"Loading {FILENAME}...")
    try:
        fs, data = wav.read(FILENAME)
        
        # Diagnostics
        print(f"Sample Rate: {fs} Hz")
        print(f"Data Type:   {data.dtype}")
        print(f"Min Value:   {np.min(data)}")
        print(f"Max Value:   {np.max(data)}")
        print(f"Mean Value:  {np.mean(data):.2f}")
        
        # Calculate Activity
        unique_vals = np.unique(data)
        print(f"Unique Levels: {len(unique_vals)}")
        if len(unique_vals) < 10:
             print(f"Values found: {unique_vals}")
        
        if len(unique_vals) == 1 and unique_vals[0] == 128:
            print("\n[DIAGNOSIS]: The file is PERFECT SILENCE (Constant 128).")
            print("This usually means the FPGA logic is stuck in Reset or IDLE.")
        
        # Setup Plot
        plt.figure(figsize=(12, 6))
        
        # Plot 1: The Whole Wave
        plt.subplot(2, 1, 1)
        plt.plot(data, color='blue', linewidth=0.5)
        plt.title(f"Waveform: {FILENAME}")
        plt.ylabel("Amplitude (0-255)")
        plt.xlabel("Sample Number")
        plt.grid(True, alpha=0.3)
        plt.ylim(0, 255) # Fixed range for 8-bit audio
        
        # Plot 2: Zoomed in (First 1000 samples)
        plt.subplot(2, 1, 2)
        zoom_range = min(1000, len(data))
        plt.plot(data[:zoom_range], color='green', marker='.', markersize=2, linewidth=0.5)
        plt.title("Zoom: First 1000 Samples")
        plt.ylabel("Amplitude")
        plt.xlabel("Sample Number")
        plt.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.show()

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    plot_waveform()
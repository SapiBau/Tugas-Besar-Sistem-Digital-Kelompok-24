import serial
import time
import numpy as np
import matplotlib.pyplot as plt
from scipy.integrate import cumulative_trapezoid

# ==========================================
# 1. CONFIGURATION
# ==========================================
SERIAL_PORT = 'COM7'      # <--- CHANGE THIS to your actual port
BAUD_RATE   = 115200      # Matches g_BAUD_RATE in fpga_top.vhd
NUM_SAMPLES = 200000        # Total samples to send
 
# Virtual Sampling Parameters
# We treat the data stream as if it were sampled at this rate.
# To represent a 50 kHz carrier clearly, we need Nyquist > 100 kHz.
# Let's use 200 kHz virtual sampling rate.
F_SAMPLE_VIRTUAL = 200000.0 

# Signal Parameters
F_CARRIER = 50000.0       # 50 kHz Carrier
F_MESSAGE = 440.0          # 10 Hz Message
MODULATION_INDEX = 1.0   # Strength of FM modulation

# ==========================================
# 2. SIGNAL GENERATION (FM)
# ==========================================
print("Generating FM Signal...")

# Time array
t = np.arange(NUM_SAMPLES) / F_SAMPLE_VIRTUAL

# 1. Original Message (10 Hz Sine)
msg_signal = np.sin(2 * np.pi * F_MESSAGE * t)

# 2. Modulated Carrier (FM)
# FM equation: y(t) = A * sin(2*pi*Fc*t + I * integral(m(t)))
integral_msg = cumulative_trapezoid(msg_signal, t, initial=0)
phase_mod = 2 * np.pi * F_CARRIER * t + (MODULATION_INDEX * integral_msg)
modulated_signal_raw = np.sin(phase_mod)

# 3. Format for FPGA (Offset Binary 8-bit)
# Map -1.0..1.0 to 0..255 (Center at 128)
# We multiply by 127 to fill the range, then add 128.
tx_data_float = (modulated_signal_raw * 127.0) + 128.0
tx_data_bytes = np.clip(tx_data_float, 0, 255).astype(np.uint8)

# ==========================================
# 3. UART TRANSMISSION LOOP
# ==========================================
rx_data_buffer = []

try:
    print(f"Opening Serial Port {SERIAL_PORT} at {BAUD_RATE} baud...")
    with serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1) as ser:
        # Reset FPGA buffers if needed (optional)
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(1) # Wait for connection to stabilize

        print(f"Sending {NUM_SAMPLES} samples...")
        
        # Send data in chunks to avoid overflowing buffers
        # but read immediately to capture the stream.
        chunk_size = 100 
        for i in range(0, NUM_SAMPLES, chunk_size):
            # Slice current chunk
            chunk = tx_data_bytes[i : i + chunk_size]
            
            # Write to FPGA
            ser.write(chunk.tobytes())
            
            # Read response from FPGA
            # We expect exactly 1 byte back for every 1 byte sent
            response = ser.read(len(chunk))
            
            # Store response
            for byte in response:
                rx_data_buffer.append(byte)
            
            # Simple progress bar
            if i % 500 == 0:
                print(f"Progress: {i}/{NUM_SAMPLES}")

    print("Transmission Complete.")

except serial.SerialException as e:
    print(f"Error opening serial port: {e}")
    exit()

# ==========================================
# 4. DATA PROCESSING
# ==========================================
# Convert received bytes to numpy array
rx_data = np.array(rx_data_buffer, dtype=float)

# Optional: Remove DC offset from received data for better plotting
# The FPGA outputs 0-255, centered at 128.
rx_signal_centered = rx_data - 128.0

# ==========================================
# 5. VISUALIZATION
# ==========================================
plt.figure(figsize=(12, 10))

# Plot 1: Original Message Signal
plt.subplot(3, 1, 1)
plt.plot(t, msg_signal, 'g', linewidth=2)
plt.title(f'Original Message Signal ({F_MESSAGE} Hz Sine)')
plt.ylabel('Amplitude')
plt.grid(True)

# Plot 2: Sent Modulated Signal (Zoomed in to show Carrier)
plt.subplot(3, 1, 2)
# We plot only the first 200 samples to see the carrier wave visually
zoom_samples = 200
plt.plot(t[:zoom_samples], tx_data_bytes[:zoom_samples], 'b')
plt.title(f'Transmitted Modulated Signal (FM Carrier {F_CARRIER/1000} kHz) - Zoomed {zoom_samples} samples')
plt.ylabel('UART Value (0-255)')
plt.grid(True)

# Plot 3: Received Demodulated Signal (From FPGA)
plt.subplot(3, 1, 3)
plt.plot(t[:len(rx_signal_centered)], rx_signal_centered, 'r', linewidth=2)
plt.title('FPGA Output (Demodulated via PLL & Loop Filter)')
plt.ylabel('Filter Output')
plt.xlabel('Time (s)')
plt.grid(True)

plt.tight_layout()
plt.show()
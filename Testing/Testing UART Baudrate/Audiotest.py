import serial
import time
import numpy as np
import scipy.io.wavfile

# ==========================================
# CONFIGURATION
# ==========================================
# WINDOWS: 'COM3', 'COM4', etc.
# LINUX/MAC: '/dev/ttyUSB0', etc.
SERIAL_PORT = 'COM7'   
BAUD_RATE   = 9600   

# Audio Configuration
DURATION    = 3.0      # Seconds of audio to test
FREQ        = 440.0    # Hz (A4 Note - The standard "Beep")

# CRITICAL CALCULATION:
# UART sends 1 Start bit + 8 Data bits + 1 Stop bit = 10 bits per byte.
# Max Bytes per Second = Baud / 10
SAMPLE_RATE = int(BAUD_RATE / 10) 

def test_audio_loopback():
    print(f"--- UART AUDIO LOOPBACK TEST ---")
    print(f"Target Baud Rate: {BAUD_RATE}")
    print(f"Max Sample Rate:  {SAMPLE_RATE} Hz (Telephone Quality)")
    
    # -------------------------------------------------
    # 1. Generate the "beep" (Sine Wave)
    # -------------------------------------------------
    print("Generating audio data...")
    t = np.linspace(0, DURATION, int(SAMPLE_RATE * DURATION), endpoint=False)
    
    # Create sine wave, scale to 0-255 (Unsigned 8-bit audio)
    raw_signal = 127 + 127 * np.sin(2 * np.pi * FREQ * t)
    audio_data = raw_signal.astype(np.uint8)
    
    # Save what we are ABOUT to send (for comparison)
    scipy.io.wavfile.write("1_source_audio.wav", SAMPLE_RATE, audio_data)
    
    received_data = bytearray()
    
    # -------------------------------------------------
    # 2. Open Serial Port and Loopback
    # -------------------------------------------------
    try:
        with serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=2) as ser:
            print(f"Connected to {SERIAL_PORT}. Stabilizing line...")
            time.sleep(2) # Wait for USB-UART chip to reset
            
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            
            print(f"Sending {len(audio_data)} bytes...")
            start_time = time.time()
            
            # Send in small chunks to prevent overflowing the buffer
            chunk_size = 32 
            total_sent = 0
            
            while total_sent < len(audio_data):
                # Slice the data
                chunk = audio_data[total_sent : total_sent + chunk_size]
                
                # Write to FPGA
                ser.write(chunk.tobytes())
                
                # Read back immediately (Loopback)
                # We expect to get back exactly what we sent
                rx_chunk = ser.read(len(chunk))

                if rx_chunk:
                    received_data.extend(rx_chunk)
                    total_sent += len(chunk)
                else:
                    print("Failed")
                
                # Simple progress bar
                percent = (total_sent / len(audio_data)) * 100
                print(f"\rProgress: {percent:.1f}%", end="")

            duration = time.time() - start_time
            print(f"\nDone in {duration:.2f} seconds.")

            # -------------------------------------------------
            # 3. Analyze Results
            # -------------------------------------------------
            rx_array = np.frombuffer(received_data, dtype=np.uint8)
            
            # Save the received file
            scipy.io.wavfile.write("2_received_from_fpga.wav", SAMPLE_RATE, rx_array)
            
            print("-" * 30)
            print(f"Sent Bytes:     {len(audio_data)}")
            print(f"Received Bytes: {len(received_data)}")
            
            if len(audio_data) == len(received_data):
                # Check for bit errors
                errors = np.sum(audio_data != rx_array)
                if errors == 0:
                    print("SUCCESS: Perfect match! 0 bit errors.")
                else:
                    print(f"WARNING: Size matched, but {errors} bytes were corrupted.")
            else:
                print("FAILURE: Data lost. (Did you update the FPGA clock divisor?)")
                
            print("-" * 30)
            print("Check your folder for '2_received_from_fpga.wav' to listen.")

    except serial.SerialException as e:
        print(f"\nError opening port: {e}")
        print("Check: Is the port correct? Is another app using it?")
    except Exception as e:
        print(f"\nAn error occurred: {e}")

if __name__ == "__main__":
    test_audio_loopback()
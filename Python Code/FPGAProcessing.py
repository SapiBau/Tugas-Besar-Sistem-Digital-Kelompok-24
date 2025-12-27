import serial
import time
import os
import sys
import wave

# SETTINGS
SERIAL_PORT = 'COM7'   # CHANGE THIS to your port
BAUD_RATE   = 115200
INPUT_FILE  = 'fm_signal.wav'
OUTPUT_FILE = 'demodulated_audio.wav'
CHUNK_SIZE  = 16       # Small chunk size to prevent overflow

def run_fm_test():
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=2)
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        print(f"Connected to FPGA on {SERIAL_PORT}...")

        # Skip WAV header (44 bytes)
        with open(INPUT_FILE, 'rb') as f_in:
            f_in.seek(44)
            file_data = f_in.read()

        total_bytes = len(file_data)
        received_bytes = bytearray()
        bytes_sent = 0

        print("Streaming data...")

        # Loop through file in chunks
        for i in range(0, total_bytes, CHUNK_SIZE):
            chunk = file_data[i : i + CHUNK_SIZE]
            
            # 1. Send
            ser.write(chunk)
            
            # 2. Receive (Wait for exact echo)
            rx_chunk = ser.read(len(chunk))
            
            if len(rx_chunk) != len(chunk):
                print("\nTIMEOUT: FPGA didn't respond in time.")
                break
                
            received_bytes.extend(rx_chunk)
            
            # Progress Bar
            bytes_sent += len(chunk)
            if bytes_sent % 1024 == 0:
                sys.stdout.write(f"\rProgress: {bytes_sent/total_bytes*100:.1f}%")
                sys.stdout.flush()

        print("\nSaving audio...")
        
        # Save output
        with wave.open(OUTPUT_FILE, 'wb') as wav_out:
            wav_out.setnchannels(1)
            wav_out.setsampwidth(1) # 8-bit audio
            wav_out.setframerate(10000)
            wav_out.writeframes(received_bytes)

        print(f"Done! Listen to {OUTPUT_FILE}")
        ser.close()

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    run_fm_test()
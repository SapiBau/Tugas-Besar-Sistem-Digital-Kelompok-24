import serial
import time
import os
import sys

# ================= CONFIGURATION =================
# CHECK THESE SETTINGS BEFORE RUNNING!
SERIAL_PORT = 'COM7'       # Windows: 'COMx', Mac/Linux: '/dev/ttyUSB0'
BAUD_RATE   = 2000000       # Must match your FPGA c_CLKS_PER_BIT setting
INPUT_FILE  = 'input.wav'  # The song you want to send
OUTPUT_FILE = 'output_from_fpga.wav' # The file to save
CHUNK_SIZE  = 32           # Bytes to send at a time (Must be < FPGA FIFO depth)
# =================================================

def run_audio_loopback():
    # 1. Check if input file exists
    if not os.path.exists(INPUT_FILE):
        print(f"Error: '{INPUT_FILE}' not found. Please place a .wav file in this folder.")
        return

    try:
        # 2. Open Serial Port
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=2)
        print(f"Connected to {SERIAL_PORT} at {BAUD_RATE} baud.")
        
        # Clear any garbage currently in the buffer
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        file_size = os.path.getsize(INPUT_FILE)
        bytes_processed = 0
        start_time = time.time()

        print(f"Starting transfer of {INPUT_FILE} ({file_size} bytes)...")
        print("Sending data to FPGA and recording echo...")

        # 3. Open Files
        with open(INPUT_FILE, 'rb') as f_in, open(OUTPUT_FILE, 'wb') as f_out:
            while True:
                # Read a chunk from the original file
                data_chunk = f_in.read(CHUNK_SIZE)
                
                if not data_chunk:
                    break # End of file

                # SEND: Write chunk to FPGA
                ser.write(data_chunk)
                
                # RECEIVE: Read exact amount of bytes back
                # This ensures we don't overrun the FPGA buffer
                rx_chunk = ser.read(len(data_chunk))
                
                if len(rx_chunk) != len(data_chunk):
                    print(f"\nError: Data loss detected! Sent {len(data_chunk)} bytes, received {len(rx_chunk)}.")
                    print("Check your baud rate or connections.")
                    break

                # Write received data to new file
                f_out.write(rx_chunk)
                
                # Progress Bar Logic
                bytes_processed += len(data_chunk)
                if bytes_processed % 1024 == 0: # Update every 1KB
                    percent = (bytes_processed / file_size) * 100
                    sys.stdout.write(f"\rProgress: {percent:.1f}% ({bytes_processed}/{file_size} bytes)")
                    sys.stdout.flush()

        total_time = time.time() - start_time
        print(f"\n\nDone!")
        print(f"Time elapsed: {total_time:.2f} seconds")
        print(f"Average Speed: {file_size/total_time:.2f} bytes/sec")
        print(f"Saved received audio to: {OUTPUT_FILE}")
        
        ser.close()
        
        # 4. Verification
        print("\n--- Verification ---")
        if os.path.getsize(OUTPUT_FILE) == file_size:
            print("SUCCESS: Output file size matches input file size.")
            print("Try playing 'output_from_fpga.wav' to hear the audio!")
        else:
            print("WARNING: File sizes do not match. Some data was lost.")

    except serial.SerialException as e:
        print(f"Serial Error: {e}")
        print("Is the device connected? Is the COM port correct?")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    run_audio_loopback()
import serial
import time
import random

# CONFIGURATION
# Windows uses 'COMx', Linux/Mac uses '/dev/ttyUSBx'
SERIAL_PORT = 'COM7'  
BAUD_RATE = 115200

def test_uart_loopback():
    try:
        # Initialize Serial Connection
        ser = serial.Serial(
            port=SERIAL_PORT,
            baudrate=BAUD_RATE,
            timeout=1,            # 1 second read timeout
            stopbits=serial.STOPBITS_ONE,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE
        )
        
        print(f"Connected to {SERIAL_PORT} at {BAUD_RATE} baud.")
        
        # Clear buffers
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        success_count = 0
        error_count = 0
        total_tests = 1000  # Number of bytes to send

        print(f"Starting test with {total_tests} packets...")
        start_time = time.time()

        for i in range(total_tests):
            # 1. Generate a random byte (0-255)
            tx_byte = bytes([random.randint(0, 255)])
            
            # 2. Send the byte
            ser.write(tx_byte)
            
            # 3. Read the byte back
            rx_byte = ser.read(1)
            
            # 4. Verification
            if rx_byte == tx_byte:
                success_count += 1
            else:
                error_count += 1
                print(f"Mismatch at index {i}: Sent {tx_byte.hex()} | Recv {rx_byte.hex()}")

        end_time = time.time()
        duration = end_time - start_time
        
        print("-" * 30)
        print(f"Test Complete in {duration:.2f} seconds")
        print(f"Successful: {success_count}")
        print(f"Errors:     {error_count}")
        print(f"Throughput: {(total_tests * 8) / duration:.2f} bps (Effective)")
        
        ser.close()

    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    test_uart_loopback()
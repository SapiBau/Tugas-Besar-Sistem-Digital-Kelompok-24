import serial
import numpy as np
import matplotlib.pyplot as plt
import time

# ==============================================================================
# KONFIGURASI
# ==============================================================================
SERIAL_PORT  = 'COM7'      # Ganti sesuai port Anda
BAUD_RATE    = 2000000     
DURATION     = 0.05        # Durasi 50ms
CARRIER_FREQ = 50000       
DEV_FREQ     = 5000        
MSG_FREQ     = 440         
SAMPLE_RATE  = 200000      

def generate_fm_signal():
    """
    Membuat sinyal FM dan mengembalikan juga sinyal pesan aslinya untuk referensi.
    """
    t = np.arange(0, DURATION, 1/SAMPLE_RATE)
    
    # 1. Sinyal Audio Asli (Pesan) - Range -1.0 s.d +1.0
    msg = np.sin(2 * np.pi * MSG_FREQ * t)
    
    # 2. Modulasi FM
    phase_accum = np.cumsum(msg) / SAMPLE_RATE
    inst_phase = 2 * np.pi * CARRIER_FREQ * t + 2 * np.pi * DEV_FREQ * phase_accum
    
    # 3. FM Sinyal (Unsigned 0-255) untuk dikirim ke FPGA
    fm_signal = 127.5 + 127.5 * np.sin(inst_phase)
    
    return fm_signal.astype(np.uint8), t, msg

def main():
    print(f"Menghubungkan ke {SERIAL_PORT}...")
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=2)
    except Exception as e:
        print(f"Error: {e}")
        return

    # --- 1. GENERATE ---
    tx_data, time_axis, original_msg = generate_fm_signal()
    print(f"Mengirim {len(tx_data)} bytes...")

    # --- 2. KIRIM & TERIMA ---
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    rx_data = bytearray()
    CHUNK_SIZE = 2048 
    
    start_time = time.time()
    
    for i in range(0, len(tx_data), CHUNK_SIZE):
        ser.write(tx_data[i:i+CHUNK_SIZE].tobytes())
        time.sleep(0.002) 
        while ser.in_waiting > 0:
            rx_data.extend(ser.read(ser.in_waiting))

    # Timeout loop untuk sisa data
    timeout_counter = 0
    while len(rx_data) < len(tx_data) and timeout_counter < 50:
        if ser.in_waiting > 0:
            rx_data.extend(ser.read(ser.in_waiting))
            timeout_counter = 0
        else:
            time.sleep(0.01)
            timeout_counter += 1
            
    print(f"Selesai. Diterima: {len(rx_data)} bytes.")
    ser.close()

    if len(rx_data) == 0:
        return

    # --- 3. PROSES DATA ---
    rx_values = np.array(list(rx_data), dtype=np.uint8).astype(float)

    # Scalling Pesan Asli supaya bisa dibandingkan dengan Unsigned 0-255
    # Asli (-1..1) -> Geser jadi (0..255)
    original_msg_scaled = 127.5 + (original_msg * 127.5)

    # --- 4. PLOTTING PERBANDINGAN (HANYA 2 SUBPLOT) ---
    plt.figure(figsize=(12, 8))
    
    # Subplot 1: Sinyal FM (Yang dikirim)
    plt.subplot(2, 1, 1)
    zoom = 300
    plt.plot(time_axis[:zoom], tx_data[:zoom], color='blue', alpha=0.7)
    plt.title("1. Sinyal Input FM (Zoom Awal)")
    plt.ylabel("Byte (0-255)")
    plt.grid(True)

    # Subplot 2: Perbandingan Langsung (Overlay)
    plt.subplot(2, 1, 2)
    latency = 20 # Estimasi delay FPGA
    
    if len(rx_values) > latency:
        limit = min(len(time_axis), len(rx_values)-latency)
        
        # Plot Sinyal Pesan ASLI (Hijau Tebal Transparan)
        plt.plot(time_axis[:limit], original_msg_scaled[:limit], 
                 label="Pesan Asli (Ideal)", color='green', linewidth=3, alpha=0.4)
        
        # Plot Output FPGA (Merah Tipis)
        plt.plot(time_axis[:limit], rx_values[latency:latency+limit], 
                 label="Output FPGA (Aktual)", color='red', linewidth=1.5)

    plt.title("2. Perbandingan: Pesan Asli vs Hasil Demodulasi FPGA")
    plt.ylabel("Amplitude (0-255)")
    plt.ylim(-10, 265)
    plt.legend(loc='upper right')
    plt.grid(True)

    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    main()
import serial
import numpy as np
import scipy.io.wavfile as wav
import scipy.signal as signal
import time
import os

# === KONFIGURASI ===
SERIAL_PORT  = 'COM7'                    # Ganti Port FPGA
BAUD_RATE    = 2000000                   # 2 Mbps
INPUT_FM_WAV = 'fm_modulated_signal.wav' # Input dari script pertama
OUTPUT_FINAL = 'hasil_demodulasi.wav'    # Output audio final

def main():
    # 1. BACA FILE SINYAL FM
    if not os.path.exists(INPUT_FM_WAV):
        print(f"Error: '{INPUT_FM_WAV}' tidak ditemukan.")
        print("Jalankan script ke-1 dulu!")
        return

    print(f"Membaca file modulasi: {INPUT_FM_WAV}...")
    fpga_rate, fm_data = wav.read(INPUT_FM_WAV)

    # Pastikan data bertipe uint8 (0-255)
    if fm_data.dtype != np.uint8:
        print("Peringatan: Format WAV bukan 8-bit unsigned. Mencoba konversi...")
        # Jika terbaca int16, konversi paksa ke uint8
        fm_data = (fm_data / 256 + 128).astype(np.uint8)

    tx_bytes = fm_data.tobytes()
    print(f"Siap mengirim {len(tx_bytes)} bytes ke FPGA...")

    # 2. BUKA KONEKSI UART
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=2)
        ser.reset_input_buffer()
        ser.reset_output_buffer()
    except Exception as e:
        print(f"Gagal membuka port: {e}")
        return

    # 3. KIRIM & TERIMA (STREAMING)
    print("Mulai streaming ke FPGA...")
    rx_data = bytearray()
    CHUNK_SIZE = 4096
    
    start_time = time.time()

    for i in range(0, len(tx_bytes), CHUNK_SIZE):
        chunk = tx_bytes[i:i+CHUNK_SIZE]
        ser.write(chunk)
        
        # Jeda kecil untuk stabilitas buffer
        time.sleep(0.004)
        
        # Baca balasan
        while ser.in_waiting > 0:
            rx_data.extend(ser.read(ser.in_waiting))
        
        # Progress Bar
        if i % (CHUNK_SIZE*20) == 0:
            print(f"\rProgress: {(i/len(tx_bytes))*100:.1f}%", end="")

    # Tunggu sisa data
    retry = 0
    while len(rx_data) < len(tx_bytes) and retry < 50:
        if ser.in_waiting:
            rx_data.extend(ser.read(ser.in_waiting))
            retry = 0
        else:
            time.sleep(0.05)
            retry += 1
    
    ser.close()
    print(f"\nSelesai! Dikirim: {len(tx_bytes)}, Diterima: {len(rx_data)}")

    if len(rx_data) == 0:
        print("Data kosong diterima dari FPGA.")
        return

    # 4. KONVERSI BALIK KE AUDIO
    print("Memproses hasil demodulasi...")
    rx_array = np.array(list(rx_data), dtype=np.uint8)
    
    # Unsigned (0..255) -> Float Audio (-1.0..1.0)
    audio_recovered = (rx_array.astype(float) - 128.0) / 128.0

    # Downsample ke 44.1 kHz (Standar Audio)
    TARGET_RATE = 44100
    num_samples_out = int(len(audio_recovered) * TARGET_RATE / fpga_rate)
    audio_final = signal.resample(audio_recovered, num_samples_out)

    # Simpan
    wav.write(OUTPUT_FINAL, TARGET_RATE, (audio_final * 32767).astype(np.int16))
    print(f"BERHASIL! Audio tersimpan di: {OUTPUT_FINAL}")

if __name__ == "__main__":
    main()
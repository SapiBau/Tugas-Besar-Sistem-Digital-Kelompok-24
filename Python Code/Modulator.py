import numpy as np
import scipy.io.wavfile as wav
import scipy.signal as signal
import os

# === KONFIGURASI ===
INPUT_FILE   = 'Prague.wav'              # File lagu/suara asli
OUTPUT_FM    = 'fm_modulated_signal.wav'# File output berisi sinyal FM
FPGA_RATE    = 200000                   # Sample rate sistem (200 kSps)
CARRIER_FREQ = 50000                    # 50 kHz
DEV_FREQ     = 5000                     # 5 kHz Deviation

def main():
    if not os.path.exists(INPUT_FILE):
        print(f"Error: '{INPUT_FILE}' tidak ditemukan.")
        return

    # 1. BACA AUDIO ASLI
    print(f"Membaca audio: {INPUT_FILE}...")
    orig_rate, audio_data = wav.read(INPUT_FILE)

    # Convert ke Mono & Float (-1.0 s.d 1.0)
    if len(audio_data.shape) > 1:
        audio_data = audio_data[:, 0]
    
    # Normalisasi
    audio_float = audio_data.astype(float)
    max_val = np.max(np.abs(audio_float))
    if max_val > 0:
        audio_float /= max_val

    # 2. RESAMPLE KE 200 kHz
    # Sinyal FM butuh resolusi waktu tinggi (high sample rate)
    print(f"Resampling ke {FPGA_RATE} Hz...")
    num_samples = int(len(audio_float) * FPGA_RATE / orig_rate)
    audio_resampled = signal.resample(audio_float, num_samples)

    # 3. MODULASI FM
    print("Melakukan modulasi FM...")
    t = np.arange(num_samples) / FPGA_RATE
    phase_accum = np.cumsum(audio_resampled) / FPGA_RATE
    inst_phase = 2 * np.pi * CARRIER_FREQ * t + 2 * np.pi * DEV_FREQ * phase_accum
    
    # Generate Sinyal Unsigned 8-bit (0-255)
    # 0 = Tegangan Min, 128 = 0V, 255 = Tegangan Max
    fm_signal = 127.5 + 127.5 * np.sin(inst_phase)
    
    # Casting ke uint8 (Wajib untuk WAV 8-bit)
    fm_bytes = fm_signal.astype(np.uint8)

    # 4. SIMPAN SEBAGAI WAV 8-BIT
    # Kita simpan dengan sample rate 200kHz agar durasinya pas
    print(f"Menyimpan sinyal ter-modulasi ke '{OUTPUT_FM}'...")
    wav.write(OUTPUT_FM, FPGA_RATE, fm_bytes)
    
    print("Selesai! File ini berisi sinyal digital FM (bukan audio biasa).")

if __name__ == "__main__":
    main()
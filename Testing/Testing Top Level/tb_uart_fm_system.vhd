library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL; -- Library untuk fungsi Sinus & Real math

entity tb_uart_fm_system is
    -- Testbench tidak memiliki port
end tb_uart_fm_system;

architecture Behavioral of tb_uart_fm_system is

    -- === 1. KONFIGURASI SIMULASI ===
    constant CLK_PERIOD   : time := 20 ns; -- 50 MHz
    
    -- Konfigurasi UART (Harus sama dengan Top Level)
    constant BAUD_RATE    : integer := 2000000;
    constant BIT_PERIOD   : time    := 500 ns; -- 1/2.000.000 detik
    
    -- Konfigurasi Sinyal (Sama dengan Python)
    constant F_MSG        : real := 14080.0;   -- Audio 440 Hz
    constant F_CARRIER    : real := 50000.0; -- Carrier 50 kHz
    constant F_DEV        : real := 5000.0;  -- Deviasi 5 kHz
    constant SAMPLE_RATE  : real := 200000.0;-- 200 kSps
    constant DT           : real := 1.0 / SAMPLE_RATE;

    -- === 2. SINYAL TESTBENCH ===
    signal clk       : std_logic := '0';
    signal rst_n     : std_logic := '0'; -- Active Low Reset
    signal uart_rx   : std_logic := '1'; -- Idle High
    signal uart_tx   : std_logic;

    -- Sinyal Analog Virtual (Untuk debugging di Waveform)
    signal debug_msg_val : real := 0.0;
    signal debug_fm_val  : integer := 0;
    signal tb_dbg_pd  : std_logic_vector(15 downto 0);
    signal tb_dbg_lf  : std_logic_vector(31 downto 0);
    signal tb_dbg_nco : std_logic_vector(7 downto 0);
    signal dbg_audio_out : std_logic_vector(7 downto 0);
    
    signal probe_msg_audio : signed(15 downto 0) := (others => '0');

    signal probe_pd      : signed(15 downto 0);
    signal probe_lf      : signed(31 downto 0);
    signal probe_nco     : signed(7 downto 0);

     

begin

    -- ==========================================
    -- 1. INSTANSIASI UNIT UNDER TEST (UUT)
    -- ==========================================
    uut: entity work.uart_fm_system
        port map (
            clk     => clk,
            rst_n   => rst_n,
            uart_rx => uart_rx,
            uart_tx => uart_tx,

            dbg_pd_out  => tb_dbg_pd,
            dbg_lf_out  => tb_dbg_lf,
            dbg_nco_out => tb_dbg_nco,
            dbg_audio_out => dbg_audio_out
        );

    probe_pd  <= signed(tb_dbg_pd);
    probe_lf  <= signed(tb_dbg_lf);
    probe_nco <= signed(unsigned(tb_dbg_nco) - 128);

    -- ==========================================
    -- 2. GENERATOR CLOCK (50 MHz)
    -- ==========================================
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- ==========================================
    -- 3. PROSES GENERATOR SINYAL (PYTHON REPLACEMENT)
    -- ==========================================
    stimulus_process: process
        -- Variabel Matematika Sinyal
        variable t_real      : real := 0.0;
        variable msg_val     : real := 0.0;
        variable phase_accum : real := 0.0;
        variable inst_phase  : real := 0.0;
        variable fm_sample   : integer;
        
        -- Variabel Transmisi UART
        variable tx_byte     : std_logic_vector(7 downto 0);
    begin
        -- A. Reset Sequence
        rst_n <= '0';
        uart_rx <= '1'; -- Idle State
        wait for 200 ns;
        rst_n <= '1';   -- Lepas Reset
        wait for 100 ns;

        -- B. Loop Pengiriman Data (Simulasi selama 5 ms)
        -- Kita kirim 1000 sampel (1000 * 5us = 5ms)
        for i in 0 to 1000 loop
            
            -- 1. Hitung Matematika Sinyal (Sama seperti Python)
            -- Message = Sin(2*pi*f_msg*t)
            msg_val := sin(MATH_2_PI * F_MSG * t_real);
            
            -- Integral Message (Cumulative Sum)
            phase_accum := phase_accum + msg_val; 
            -- Note: Di python cumsum, disini akumulasi manual.
            -- Faktor 1/SampleRate sudah masuk di scaling deviasi fase di bawah
            
            -- Hitung Fase Instan FM
            -- Phase = 2*pi*Fc*t + 2*pi*Fdev * Integral(msg)*dt
            inst_phase := (MATH_2_PI * F_CARRIER * t_real) + 
                          (MATH_2_PI * F_DEV * phase_accum * DT);
                          
            -- Generate Nilai Sinus FM (0-255)
            -- 127.5 + 127.5 * sin(phase)
            fm_sample := integer(127.5 + (127.5 * sin(inst_phase)));
            
            -- Debugging Signals (Agar muncul di Waveform)
            debug_msg_val <= msg_val;
            debug_fm_val  <= fm_sample;

            probe_msg_audio <= to_signed(integer(msg_val * 30000.0), 16);
            
            tx_byte := std_logic_vector(to_unsigned(fm_sample, 8));

            -- 2. Kirim via UART (Bit-Banging)
            -- Start Bit (Low)
            uart_rx <= '0';
            wait for BIT_PERIOD;
            
            -- Data Bits (LSB First)
            for bit_idx in 0 to 7 loop
                uart_rx <= tx_byte(bit_idx);
                wait for BIT_PERIOD;
            end loop;
            
            -- Stop Bit (High)
            uart_rx <= '1';
            wait for BIT_PERIOD;
            
            -- 3. Update Waktu
            t_real := t_real + DT;
            
            -- Tidak perlu wait tambahan karena durasi kirim UART (10 bit * 500ns = 5us)
            -- persis sama dengan periode sampling 200kHz (5us).
            
        end loop;

        -- Selesai
        wait for 10 us;
        assert false report "Simulasi Selesai (End of Stream)" severity failure;
        wait;
    end process;

end Behavioral;
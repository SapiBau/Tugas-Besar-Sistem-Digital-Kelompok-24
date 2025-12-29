library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_fm_demodulator is
    -- Kosong
end tb_fm_demodulator;

architecture Behavioral of tb_fm_demodulator is

    -- === KONFIGURASI ===
    constant CLK_PERIOD : time := 20 ns; -- 50 MHz
    constant F_MSG      : real := 440.0; -- Message 440 Hz
    constant F_CARRIER  : real := 50000.0; -- Carrier 50 kHz
    constant F_DEV      : real := 5000.0;  -- Deviasi 5 kHz

    -- === SINYAL UTAMA ===
    signal clk       : std_logic := '0';
    signal rst       : std_logic := '0';
    signal enable    : std_logic := '0';
    
    -- Input/Output Sistem
    signal fm_input  : std_logic_vector(7 downto 0);
    signal audio_out : std_logic_vector(7 downto 0);
    
    -- Konfigurasi Loop Filter
    signal kp_tb     : signed(15 downto 0) := (others => '0');
    signal ki_tb     : signed(15 downto 0) := (others => '0');

    -- === SINYAL MONITORING (DEBUG) ===
    -- Sinyal ini yang harus Anda masukkan ke Waveform Viewer
    signal mon_pd_out  : signed(15 downto 0); -- Output Phase Detector
    signal mon_lf_out  : signed(23 downto 0); -- Output Loop Filter
    signal mon_nco_out : signed(7 downto 0);  -- Output NCO Local
    
    -- Sinyal Visualisasi Message Asli (Reference)
    signal wave_msg_ref : signed(15 downto 0) := (others => '0');

    -- Koneksi sementara untuk port mapping
    signal dbg_pd_vec  : std_logic_vector(15 downto 0);
    signal dbg_lf_vec  : std_logic_vector(23 downto 0);
    signal dbg_nco_vec : std_logic_vector(7 downto 0);

begin

    -- Instansiasi Top Entity
    UUT: entity work.fm_demodulator_top
        port map (
            clk         => clk,
            rst         => rst,
            enable      => enable,
            kp_config   => kp_tb,
            ki_config   => ki_tb,
            data_in     => fm_input,
            audio_out   => audio_out,
            
            -- Hubungkan Debug Ports
            dbg_pd_out  => dbg_pd_vec,
            dbg_lf_out  => dbg_lf_vec,
            dbg_nco_out => dbg_nco_vec
        );

    -- Konversi Vector ke Signed untuk Waveform Analog yang Bagus
    mon_pd_out  <= signed(dbg_pd_vec);
    mon_lf_out  <= signed(dbg_lf_vec);
    mon_nco_out <= signed(unsigned(dbg_nco_vec) - 128); -- Offset binary ke Signed

    -- Generator Clock
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Generator Stimulus FM & Message
    stim_proc: process
        variable t_real   : real := 0.0;
        variable msg_val  : real := 0.0;
        variable inst_ph  : real := 0.0;
        variable fm_val   : real := 0.0;
        constant TWO_PI   : real := 6.28318530718;
    begin
        -- Inisialisasi
        rst <= '1';
        enable <= '0';
        fm_input <= x"80"; -- Mid-scale
        
        -- Tuning PI Controller (Kp=2.0, Ki=0.05 approx)
        kp_tb <= to_signed(32000, 16); 
        ki_tb <= to_signed(50, 16);
        
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;
        enable <= '1';

        -- Loop Simulasi (10 ms)
        while t_real < 5.0 loop
            
            -- 1. Generate Message Signal (440 Hz)
            msg_val := sin(TWO_PI * F_MSG * t_real);
            
            -- Simpan ke sinyal untuk dilihat di Waveform (Skala 30000 agar jelas)
            wave_msg_ref <= to_signed(integer(msg_val * 30000.0), 16);

            -- 2. Generate FM Signal
            -- Integral frekuensi menjadi fase
            inst_ph := inst_ph + (TWO_PI * (F_CARRIER + (F_DEV * msg_val)) * (real(20) * 1.0e-9));
            
            -- Wrap Phase
            if inst_ph > TWO_PI then inst_ph := inst_ph - TWO_PI; end if;

            -- Output Sinus FM (Scale to 0-255)
            fm_val := (sin(inst_ph) * 127.0) + 128.0;
            fm_input <= std_logic_vector(to_unsigned(integer(fm_val), 8));

            -- 3. Advance Time
            t_real := t_real + (real(20) * 1.0e-9);
            wait for CLK_PERIOD;
        end loop;
        
        wait;
    end process;

end Behavioral;
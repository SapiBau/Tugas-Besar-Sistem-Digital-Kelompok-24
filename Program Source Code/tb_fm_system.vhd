library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_fm_system is
end tb_fm_system;

architecture Behavioral of tb_fm_system is

    -- === 1. KONFIGURASI SIMULASI ===
    -- UART dipercepat drastis agar simulasi tidak lelet
    constant c_SIM_BAUD_CLKS : integer := 5; 
    
    -- Parameter Sinyal (HARUS COCOK dengan perhitungan VHDL)
    constant C_SAMPLE_RATE   : real := 200000.0; -- 250 kHz
    constant C_CARRIER_FREQ  : real := 50000.0;  -- 90 kHz
    constant C_FM_DEVIATION  : real := 15000.0;  -- Deviasi +/- 15 kHz
    constant C_AUDIO_FREQ    : real := 200.0;   -- Nada Audio 2 kHz

    component fm_demodulator_top is
        Generic ( g_CLKS_PER_BIT_OVERRIDE : integer := 25 );
        Port (
            clk, rst, rx_serial : in std_logic;
            tx_serial : out std_logic
        );
    end component;

    signal clk, rst, rx_serial, tx_serial : std_logic := '0';
    constant clk_period : time := 20 ns; -- 50 MHz
    constant c_BIT_PERIOD : time := c_SIM_BAUD_CLKS * clk_period;

    -- Debug Signals (Analog)
    signal dbg_audio_in   : real := 0.0;
    signal dbg_fm_freq    : real := 0.0;
    signal dbg_uart_byte  : integer := 0;

begin

    -- Gunakan Generic Override untuk mempercepat UART di Top Level
    uut: entity work.fm_demodulator_top
    generic map ( g_CLKS_PER_BIT_OVERRIDE => c_SIM_BAUD_CLKS ) 
    port map ( clk, rst, rx_serial, tx_serial );

    -- Clock Process
    process begin
        clk <= '0'; wait for clk_period/2;
        clk <= '1'; wait for clk_period/2;
    end process;

    -- Stimulus Process
    stim_proc: process
        procedure UART_SEND(data_val : integer) is
            variable vec : std_logic_vector(7 downto 0);
        begin
            vec := std_logic_vector(to_unsigned(data_val, 8));
            rx_serial <= '0'; wait for c_BIT_PERIOD; -- Start
            for i in 0 to 7 loop
                rx_serial <= vec(i); wait for c_BIT_PERIOD;
            end loop;
            rx_serial <= '1'; wait for c_BIT_PERIOD; -- Stop
        end procedure;

        -- Variabel Matematika
        variable t_now       : real := 0.0;
        variable dt          : real := 1.0 / C_SAMPLE_RATE; -- Langkah waktu per sampel
        variable phase_accum : real := 0.0;
        variable current_freq: real := 0.0;
        variable sine_val    : real := 0.0;
        variable dac_int     : integer := 0;

    begin
        -- Reset
        rst <= '1'; rx_serial <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        report "SIMULASI MULAI: Fs=" & real'image(C_SAMPLE_RATE) & " Fc=" & real'image(C_CARRIER_FREQ);

        -- Loop Generate 1000 Sampel
        for i in 0 to 1000000 loop
            
            -- 1. Buat Sinyal Audio (Modulating Signal)
            -- Sinyal sinus murni 2 kHz
            dbg_audio_in <= sin(2.0 * MATH_PI * C_AUDIO_FREQ * t_now);
            
            -- 2. Modulasi FM
            -- Freq sesaat = 90k + (15k * audio)
            current_freq := C_CARRIER_FREQ + (C_FM_DEVIATION * dbg_audio_in);
            dbg_fm_freq  <= current_freq;

            -- 3. Akumulasi Fase (Integral)
            phase_accum := phase_accum + (current_freq * dt);
            -- Wrap phase 0..2PI
            if phase_accum > 2.0 * MATH_PI then
                phase_accum := phase_accum - (2.0 * MATH_PI);
            end if;

            -- 4. Generate Gelombang Carrier (FM Signal)
            sine_val := sin(phase_accum); -- Range -1 sd 1

            -- 5. Konversi ke Byte (0 sd 255)
            dac_int := integer((sine_val * 127.0) + 128.0);
            if dac_int > 255 then dac_int := 255; end if;
            if dac_int < 0 then dac_int := 0; end if;
            
            dbg_uart_byte <= dac_int;

            -- 6. Kirim via UART
            UART_SEND(dac_int);

            -- 7. Update Waktu Virtual
            t_now := t_now + dt;

            -- Jeda opsional antar paket (simulasi processing time laptop)
            -- UART cepat (50 clock) + Jeda ini tidak boleh melebihi periode sampling nyata
            wait for 100 ns; 

        end loop;

        report "SIMULASI SELESAI.";
        wait;
    end process;

end Behavioral;
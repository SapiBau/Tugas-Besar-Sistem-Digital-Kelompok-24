library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity top_fm_demodulator is
    Port (
        clk         : in  STD_LOGIC;        -- Clock Utama (50 MHz)
        rst_n       : in  STD_LOGIC;        -- Reset Active Low (Tombol / Key)
        rx_pin      : in  STD_LOGIC;        -- INPUT: Dari PC (Data FM)
        tx_pin      : out STD_LOGIC;        -- OUTPUT 1: Ke PC (Data Grafik/Loopback)
        pwm_audio   : out STD_LOGIC;        -- OUTPUT 2: Ke Speaker (Data Suara)
        debug_led   : out STD_LOGIC         -- Indikator Visual (Nyala jika FIFO ada isi)
    );
end top_fm_demodulator;


architecture Behavioral of top_fm_demodulator is


    -- Sinyal Kontrol
    signal s_fifo_rd    : std_logic;
    signal s_en_pd      : std_logic;
    signal s_en_pi_acc  : std_logic;
    signal s_en_pi_out  : std_logic;
    signal s_en_nco_ph  : std_logic;
    signal s_en_nco_out : std_logic;
    signal s_tx_start   : std_logic;


    -- Sinyal Status
    signal s_fifo_empty : std_logic;


    -- Sinyal Data
    signal rx_byte_raw  : std_logic_vector(7 downto 0); -- Data mentah dari UART RX
    signal rx_valid     : std_logic;                    -- Valid pulse dari UART RX
    signal fifo_out     : std_logic_vector(7 downto 0); -- Data keluar dari FIFO
   
    -- Sinyal DPLL
    signal fm_input_s   : signed(7 downto 0);   -- Input FM (-128 s.d 127)
    signal nco_fb_s     : signed(7 downto 0);   -- Feedback NCO
    signal error_s      : signed(15 downto 0);  -- Error Phase Detector
    signal audio_s      : signed(31 downto 0);  -- Output Loop Filter (32-bit)


    -- Sinyal Output Interface
    signal audio_unsigned_8bit : unsigned(7 downto 0);      -- Audio siap pakai (0-255)
    signal tx_data_byte        : std_logic_vector(7 downto 0); -- Data kirim balik ke PC


    -- PWM Internal
    signal pwm_cnt : unsigned(7 downto 0) := (others => '0');


begin


    U_CONTROLLER: entity work.fsm_controller
    port map (
        clk         => clk,
        rst_n       => rst_n,
        fifo_empty  => s_fifo_empty,    -- Input Status
        fifo_rd_en  => s_fifo_rd,       -- Output Control
        en_pd       => s_en_pd,
        en_pi_acc   => s_en_pi_acc,
        en_pi_out   => s_en_pi_out,
        en_nco_ph   => s_en_nco_ph,
        en_nco_out  => s_en_nco_out,
        tx_start    => s_tx_start       -- Trigger kirim data balik
    );


    -- UART Receiver
    U_UART_RX: entity work.uart_rx
    port map (
        clk      => clk,
        rst_n    => rst_n,
        rx_pin   => rx_pin,
        rx_data  => rx_byte_raw,
        rx_valid => rx_valid
    );


    -- FIFO Buffer
    U_FIFO: entity work.simple_fifo
    port map (
        clk     => clk,
        rst_n   => rst_n,
        wr_en   => rx_valid,
        wr_data => rx_byte_raw,
        rd_en   => s_fifo_rd,    -- Dikontrol FSM
        rd_data => fifo_out,
        empty   => s_fifo_empty  -- Lapor ke FSM
    );


 
    fm_input_s <= signed(not fifo_out(7) & fifo_out(6 downto 0));


    -- Phase Detector
    U_PD: entity work.phase_detector
    port map (
        clk       => clk,
        en        => s_en_pd,
        fm_in     => fm_input_s,
        nco_fb    => nco_fb_s,
        error_out => error_s
    );


    -- Loop Filter (PI Controller)
    U_LF: entity work.loop_filter
    port map (
        clk       => clk,
        rst_n     => rst_n,
        acc_en    => s_en_pi_acc,
        out_en    => s_en_pi_out,
        error_in  => error_s,
        audio_out => audio_s    -- Output Audio Mentah (32-bit Signed)
    );


    -- NCO (Oscillator)
    U_NCO: entity work.nco
    port map (
        clk       => clk,
        rst_n     => rst_n,
        phase_en  => s_en_nco_ph,
        out_en    => s_en_nco_out,
        audio_in  => audio_s,
        nco_out   => nco_fb_s
    );




    audio_unsigned_8bit <= unsigned(not audio_s(23) & audio_s(22 downto 16));
   
    -- Format data untuk UART TX (std_logic_vector)
    tx_data_byte <= std_logic_vector(audio_unsigned_8bit);


    -- UART Transmitter (Kirim balik ke Laptop untuk Grafik)
    U_UART_TX: entity work.uart_tx
    port map (
        clk      => clk,
        rst_n    => rst_n,
        tx_start => s_tx_start,  -- Dipicu oleh FSM (State OUTPUT)
        tx_data  => tx_data_byte,
        tx_pin   => tx_pin,
        tx_busy  => open        
    );


    -- PWM Generator Process (Output Audio ke Speaker)
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            pwm_cnt <= (others => '0');
            pwm_audio <= '0';
        elsif rising_edge(clk) then
            -- Counter naik terus 0..255..0
            pwm_cnt <= pwm_cnt + 1;
           
            -- Komparator Lebar Pulsa
            if pwm_cnt < audio_unsigned_8bit then
                pwm_audio <= '1';
            else
                pwm_audio <= '0';
            end if;
        end if;
    end process;


    -- LED menyala jika FIFO TIDAK kosong (Ada data diproses)
    debug_led <= not s_fifo_empty;


end Behavioral;
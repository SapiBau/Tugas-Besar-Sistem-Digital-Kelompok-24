library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_fm_system is
    Port ( 
        clk      : in  std_logic; -- System Clock (50 MHz)
        rst_n    : in  std_logic; -- RESET ACTIVE LOW (Tekan = 0, Lepas = 1)
        uart_rx  : in  std_logic; -- Serial Input
        uart_tx  : out std_logic;  -- Serial Output

        dbg_pd_out  : out std_logic_vector(15 downto 0);
        dbg_lf_out  : out std_logic_vector(31 downto 0);
        dbg_nco_out : out std_logic_vector(7 downto 0);
        dbg_audio_out : out std_logic_vector(7 downto 0)
    );
end uart_fm_system;

architecture Behavioral of uart_fm_system is

    -- === KONFIGURASI ===
    -- Baudrate 2.000.000 pada Clock 50 MHz = 25 Clocks/bit
    constant CLKS_PER_BIT : integer := 25; 
    
    -- Tuning Parameter (Hardcoded)
    constant KP_VAL : signed(15 downto 0) := to_signed(32000, 16);
    constant KI_VAL : signed(15 downto 0) := to_signed(50, 16);

    -- === SINYAL ===
    
    -- Sinyal Reset Internal (Active High)
    signal sys_rst   : std_logic;

    -- UART RX Signals
    signal rx_dv     : std_logic;
    signal rx_byte   : std_logic_vector(7 downto 0);
    
    -- FIFO RX Signals
    signal fifo_rx_rd_en : std_logic := '0';
    signal fifo_rx_dout  : std_logic_vector(7 downto 0);
    signal fifo_rx_empty : std_logic;
    signal fifo_rx_full  : std_logic;

    -- Demodulator Signals
    signal demod_en      : std_logic := '0';
    signal demod_out     : std_logic_vector(7 downto 0);
    
    -- FIFO TX Signals
    signal fifo_tx_wr_en : std_logic := '0';
    signal fifo_tx_full  : std_logic;
    signal fifo_tx_empty : std_logic;
    signal fifo_tx_rd_en : std_logic := '0';
    signal fifo_tx_dout  : std_logic_vector(7 downto 0);
    
    -- UART TX Signals
    signal tx_active     : std_logic;
    signal tx_done       : std_logic;
    signal tx_dv         : std_logic := '0';

    -- State Machine
    type t_state is (IDLE, PROCESS_SAMPLE, WRITE_OUTPUT);
    signal state : t_state := IDLE;

begin

    -- ========================================================
    -- 1. RESET INVERSION
    -- ========================================================
    -- Mengubah Active Low (Tombol) menjadi Active High (Sistem)
    sys_rst <= not rst_n;

    -- ========================================================
    -- 2. UART RECEIVER
    -- ========================================================
    inst_uart_rx: entity work.uart_rx
    generic map (g_CLKS_PER_BIT => CLKS_PER_BIT)
    port map (
        i_Clk       => clk,
        i_Rx_Serial => uart_rx,
        o_Rx_DV     => rx_dv,
        o_Rx_Byte   => rx_byte
    );

    -- ========================================================
    -- 3. FIFO RX (Input Buffer)
    -- ========================================================
    -- Note: Menggunakan sys_rst (Active High)
    inst_fifo_rx: entity work.fifo
    generic map (g_WIDTH => 8, g_DEPTH => 256)
    port map (
        i_Clk => clk, i_Rst => sys_rst, 
        i_Wr_En => rx_dv, i_Wr_Data => rx_byte, o_Full => fifo_rx_full,
        i_Rd_En => fifo_rx_rd_en, o_Rd_Data => fifo_rx_dout, o_Empty => fifo_rx_empty
    );

    -- ========================================================
    -- 4. CONTROL LOGIC (Pipeline Manager)
    -- ========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if sys_rst = '1' then -- Menggunakan sys_rst
                state <= IDLE;
                fifo_rx_rd_en <= '0';
                fifo_tx_wr_en <= '0';
                demod_en      <= '0';
            else
                -- Default values
                fifo_rx_rd_en <= '0';
                fifo_tx_wr_en <= '0';
                demod_en      <= '0';
                
                case state is
                    when IDLE =>
                        if fifo_rx_empty = '0' and fifo_tx_full = '0' then
                            fifo_rx_rd_en <= '1';
                            state <= PROCESS_SAMPLE;
                        end if;
                        
                    when PROCESS_SAMPLE =>
                        demod_en <= '1';
                        state <= WRITE_OUTPUT;
                        
                    when WRITE_OUTPUT =>
                        fifo_tx_wr_en <= '1';
                        state <= IDLE;
                        
                end case;
            end if;
        end if;
    end process;

    -- ========================================================
    -- 5. FM DEMODULATOR CORE
    -- ========================================================
    inst_demod: entity work.fm_demodulator_top
    generic map (
        -- TUNING UNTUK BAUDRATE 2.000.000 (Sample Rate 200 kHz)
        -- 1. Center Frequency Word (1.073.741.824)
        CW0_VAL_OVERRIDE => 1073741824,
        
        -- 2. Filter Gain Shift
        -- Ubah dari 12 menjadi 4.
        -- Jika 12, sinyal dibagi 4096 (Audio hilang/flat).
        -- Jika 4, sinyal dibagi 16 (Audio lebih kuat).
        FILTER_SHIFT     => 4
    )
    port map (
        clk        => clk,
        rst        => sys_rst, -- Terhubung ke sys_rst
        enable     => demod_en,
        kp_config  => KP_VAL,
        ki_config  => KI_VAL,
        data_in    => fifo_rx_dout,
        audio_out  => demod_out,
        dbg_pd_out => dbg_pd_out, 
        dbg_lf_out => dbg_lf_out, 
        dbg_nco_out => dbg_nco_out
    );

    dbg_audio_out <= demod_out;

    -- ========================================================
    -- 6. FIFO TX (Output Buffer)
    -- ========================================================
    inst_fifo_tx: entity work.fifo
    generic map (g_WIDTH => 8, g_DEPTH => 256)
    port map (
        i_Clk => clk, i_Rst => sys_rst,
        i_Wr_En => fifo_tx_wr_en, i_Wr_Data => demod_out, o_Full => fifo_tx_full,
        i_Rd_En => fifo_tx_rd_en, o_Rd_Data => fifo_tx_dout, o_Empty => fifo_tx_empty
    );

    -- ========================================================
    -- 7. UART TRANSMITTER CONTROLLER
    -- ========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if sys_rst = '1' then
                tx_dv <= '0';
                fifo_tx_rd_en <= '0';
            else
                tx_dv <= '0';
                fifo_tx_rd_en <= '0';
                
                if tx_active = '0' and fifo_tx_empty = '0' and tx_dv = '0' then
                    fifo_tx_rd_en <= '1';
                    tx_dv <= '1';
                end if;
            end if;
        end if;
    end process;

    -- ========================================================
    -- 8. UART TRANSMITTER
    -- ========================================================
    inst_uart_tx: entity work.uart_tx
    generic map (g_CLKS_PER_BIT => CLKS_PER_BIT)
    port map (
        i_Clk       => clk,
        i_Tx_DV     => tx_dv,
        i_Tx_Byte   => fifo_tx_dout,
        o_Tx_Active => tx_active,
        o_Tx_Serial => uart_tx,
        o_Tx_Done   => tx_done
    );

end Behavioral;
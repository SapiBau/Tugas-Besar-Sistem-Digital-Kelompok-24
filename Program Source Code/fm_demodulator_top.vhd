library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fm_demodulator_top is
	 Generic ( 
        g_CLKS_PER_BIT_OVERRIDE : integer := 25 -- Default 54 (untuk Hardware Nyata)
    );
	 
    Port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        rx_serial   : in  std_logic;
        tx_serial   : out std_logic
    );
end fm_demodulator_top;

architecture Behavioral of fm_demodulator_top is

    -- Konfigurasi Baud Rate (Sesuaikan dengan Clock FPGA & Laptop)
    -- Contoh: 50MHz Clock / 921600 Baud = ~54
    constant c_CLKS_PER_BIT : integer := g_CLKS_PER_BIT_OVERRIDE; 

    component uart_rx is
        generic ( g_CLKS_PER_BIT : integer );
        port ( i_Clk : in std_logic; i_Rx_Serial : in std_logic; o_Rx_DV : out std_logic; o_Rx_Byte : out std_logic_vector(7 downto 0) );
    end component;

    component uart_tx is
        generic ( g_CLKS_PER_BIT : integer );
        port ( i_Clk : in std_logic; i_Tx_DV : in std_logic; i_Tx_Byte : in std_logic_vector(7 downto 0); o_Tx_Active : out std_logic; o_Tx_Serial : out std_logic; o_Tx_Done : out std_logic );
    end component;

    component fifo is
        generic ( g_WIDTH : integer := 8; g_DEPTH : integer := 1024 );
        port ( i_Clk : in std_logic; i_Rst : in std_logic; i_Wr_En : in std_logic; i_Wr_Data : in std_logic_vector(g_WIDTH-1 downto 0); o_Full : out std_logic; i_Rd_En : in std_logic; o_Rd_Data : out std_logic_vector(g_WIDTH-1 downto 0); o_Empty : out std_logic );
    end component;

    component fm_pll_core is
        Port (
            clk, rst : in std_logic;
            i_fifo_not_empty : in std_logic;
            i_data_byte      : in std_logic_vector(7 downto 0);
            o_fifo_read_en   : out std_logic;
            i_fifo_tx_full   : in std_logic;
            o_result_valid   : out std_logic;
            o_result_byte    : out std_logic_vector(7 downto 0)
        );
    end component;

    -- Sinyal Penghubung
    signal uart_rx_dv, rx_fifo_full, rx_fifo_empty, core_read_req : std_logic;
    signal tx_fifo_full, tx_fifo_empty, tx_fifo_wr, tx_rd_en, tx_active : std_logic;
    signal uart_rx_byte, rx_data_to_core, core_result_byte, tx_fifo_dout : std_logic_vector(7 downto 0);
    signal rx_not_empty : std_logic;

begin

    -- Logika Pembantu
    rx_not_empty <= not rx_fifo_empty;

    -- 1. UART RX (Terima dari Laptop)
    inst_uart_rx : uart_rx
    generic map ( g_CLKS_PER_BIT => c_CLKS_PER_BIT )
    port map ( clk, rx_serial, uart_rx_dv, uart_rx_byte );

    -- 2. FIFO RX (Buffer Input)
    inst_fifo_rx : fifo
    port map (
        i_Clk => clk, i_Rst => rst,
        i_Wr_En => uart_rx_dv, i_Wr_Data => uart_rx_byte, o_Full => rx_fifo_full,
        i_Rd_En => core_read_req, o_Rd_Data => rx_data_to_core, o_Empty => rx_fifo_empty
    );

    -- 3. PLL CORE (Otak FSM)
    inst_core : fm_pll_core
    port map (
        clk => clk, rst => rst,
        i_fifo_not_empty => rx_not_empty,    -- Beritahu core ada data
        i_data_byte      => rx_data_to_core, -- Data sample
        o_fifo_read_en   => core_read_req,   -- Core minta ambil data
        i_fifo_tx_full   => tx_fifo_full,    -- Cek buffer output penuh/tidak
        o_result_valid   => tx_fifo_wr,      -- Core selesai proses
        o_result_byte    => core_result_byte -- Hasil demodulasi
    );

    -- 4. FIFO TX (Buffer Output)
    inst_fifo_tx : fifo
    port map (
        i_Clk => clk, i_Rst => rst,
        i_Wr_En => tx_fifo_wr, i_Wr_Data => core_result_byte, o_Full => tx_fifo_full,
        i_Rd_En => tx_rd_en, o_Rd_Data => tx_fifo_dout, o_Empty => tx_fifo_empty
    );

    -- Baca FIFO TX hanya jika tidak kosong DAN UART TX sedang tidak sibuk
    tx_rd_en <= '1' when (tx_fifo_empty = '0' and tx_active = '0') else '0';

    -- 5. UART TX (Kirim ke Laptop)
    inst_uart_tx : uart_tx
    generic map ( g_CLKS_PER_BIT => c_CLKS_PER_BIT )
    port map ( clk, tx_rd_en, tx_fifo_dout, tx_active, tx_serial, open );

end Behavioral;
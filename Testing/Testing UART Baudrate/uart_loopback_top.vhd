library ieee;
use ieee.std_logic_1164.all;

entity uart_loopback_top is
    port (
        i_Clk     : in  std_logic;  -- 50 MHz System Clock
        i_UART_RX : in  std_logic;  -- Map to GPIO connected to USB-TX
        o_UART_TX : out std_logic;   -- Map to GPIO connected to USB-RX
        o_LED : out std_logic
    );
end uart_loopback_top;

architecture rtl of uart_loopback_top is

    -- 50,000,000 / 1,000,000 = 50
    constant c_CLKS_PER_BIT : integer := 434;

    signal w_Rx_DV     : std_logic;
    signal w_Rx_Byte   : std_logic_vector(7 downto 0);
    signal w_Tx_Active : std_logic;
    signal w_Tx_Serial : std_logic;
    
    -- Component Declaration
    component uart_rx is
        generic (g_CLKS_PER_BIT : integer);
        port (
            i_Clk       : in  std_logic;
            i_Rx_Serial : in  std_logic;
            o_Rx_DV     : out std_logic;
            o_Rx_Byte   : out std_logic_vector(7 downto 0)
        );
    end component uart_rx;
    
    component uart_tx is
        generic (g_CLKS_PER_BIT : integer);
        port (
            i_Clk       : in  std_logic;
            i_Tx_DV     : in  std_logic;
            i_Tx_Byte   : in  std_logic_vector(7 downto 0);
            o_Tx_Active : out std_logic;
            o_Tx_Serial : out std_logic;
            o_Tx_Done   : out std_logic
        );
    end component uart_tx;

begin

    process(w_Tx_Serial)
    begin
        o_LED <= w_Tx_Serial;
    end process;

    -- Instantiate Receiver
    UART_RX_INST : uart_rx
    generic map (
        g_CLKS_PER_BIT => c_CLKS_PER_BIT
    )
    port map (
        i_Clk       => i_Clk,
        i_Rx_Serial => i_UART_RX,
        o_Rx_DV     => w_Rx_DV,
        o_Rx_Byte   => w_Rx_Byte
    );

    -- Instantiate Transmitter
    -- CRITICAL LOGIC: Tie RX_DV directly to TX_DV
    -- This makes the FPGA immediately echo whatever it hears.
    UART_TX_INST : uart_tx
    generic map (
        g_CLKS_PER_BIT => c_CLKS_PER_BIT
    )
    port map (
        i_Clk       => i_Clk,
        i_Tx_DV     => w_Rx_DV,    -- Trigger TX when RX is complete
        i_Tx_Byte   => w_Rx_Byte,  -- Pass the data straight through
        o_Tx_Active => w_Tx_Active,
        o_Tx_Serial => w_Tx_Serial,
        o_Tx_Done   => open        -- We don't need to monitor Done for loopback
    );

    -- Drive the physical pin
    o_UART_TX <= w_Tx_Serial;

end rtl;
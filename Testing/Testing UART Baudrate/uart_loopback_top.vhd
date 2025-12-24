library ieee;
use ieee.std_logic_1164.all;

entity uart_loopback_top is
    port (
        i_Clk     : in  std_logic; 
        i_UART_RX : in  std_logic; 
        o_UART_TX : out std_logic;
        o_LED     : out std_logic
    );
end uart_loopback_top;

architecture rtl of uart_loopback_top is

    
    constant c_CLKS_PER_BIT : integer := 434; 

    -- Signals for UART RX
    signal w_Rx_DV     : std_logic;
    signal w_Rx_Byte   : std_logic_vector(7 downto 0);

    -- Signals for FIFO
    signal w_FIFO_Empty  : std_logic;
    signal w_FIFO_Full   : std_logic;
    signal w_FIFO_Rd_Data: std_logic_vector(7 downto 0);
    signal r_FIFO_Rd_En  : std_logic := '0';

    -- Signals for UART TX
    signal w_Tx_Active : std_logic;
    signal w_Tx_Serial : std_logic;
    signal r_Tx_DV     : std_logic := '0';
    
    -- State Machine for moving data from FIFO to TX
    type t_SM_Flow is (s_IDLE, s_READ_FIFO, s_SEND_TX);
    signal r_SM_Flow : t_SM_Flow := s_IDLE;

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

    component fifo is
        generic (g_WIDTH : integer; g_DEPTH : integer);
        port (
            i_Clk, i_Rst : in std_logic;
            i_Wr_En      : in std_logic;
            i_Wr_Data    : in std_logic_vector;
            o_Full       : out std_logic;
            i_Rd_En      : in std_logic;
            o_Rd_Data    : out std_logic_vector;
            o_Empty      : out std_logic
        );
    end component fifo;

begin

    -- Diagnostic LED
    o_LED <= not w_FIFO_Empty; -- LED Lights up when buffer has data

    -- 1. Receiver
    UART_RX_INST : uart_rx
    generic map (g_CLKS_PER_BIT => c_CLKS_PER_BIT)
    port map (
        i_Clk       => i_Clk,
        i_Rx_Serial => i_UART_RX,
        o_Rx_DV     => w_Rx_DV,      -- This triggers the FIFO Write
        o_Rx_Byte   => w_Rx_Byte     -- Data goes into FIFO
    );

    -- 2. The Buffer (FIFO)
    FIFO_INST : fifo
    generic map (g_WIDTH => 8, g_DEPTH => 256) -- 256 Byte Buffer
    port map (
        i_Clk     => i_Clk,
        i_Rst     => '0',            -- No reset button needed for simple loopback
        i_Wr_En   => w_Rx_DV,        -- Write when RX gets a byte
        i_Wr_Data => w_Rx_Byte,
        o_Full    => w_FIFO_Full,
        i_Rd_En   => r_FIFO_Rd_En,   -- Controlled by Flow Process below
        o_Rd_Data => w_FIFO_Rd_Data, -- Goes to TX
        o_Empty   => w_FIFO_Empty
    );

    -- 3. Flow Control Process (The "Glue" Logic)
    p_FIFO_TO_TX : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            
            -- Defaults
            r_FIFO_Rd_En <= '0';
            r_Tx_DV      <= '0';

            case r_SM_Flow is
                
                -- Wait until there is Data in FIFO AND TX is free
                when s_IDLE =>
                    if w_FIFO_Empty = '0' and w_Tx_Active = '0' then
                        r_FIFO_Rd_En <= '1'; -- Pull data from FIFO
                        r_SM_Flow    <= s_READ_FIFO;
                    end if;

                -- Wait 1 cycle for RAM to output data
                when s_READ_FIFO =>
                    r_Tx_DV   <= '1'; -- Tell TX to start
                    r_SM_Flow <= s_SEND_TX;

                -- Wait for TX to acknowledge (Active goes High)
                when s_SEND_TX =>
                    -- We can just go back to IDLE immediately because
                    -- UART_TX latches the data on the first clock cycle.
                    r_SM_Flow <= s_IDLE;
                    
            end case;
        end if;
    end process;

    -- 4. Transmitter
    UART_TX_INST : uart_tx
    generic map (g_CLKS_PER_BIT => c_CLKS_PER_BIT)
    port map (
        i_Clk       => i_Clk,
        i_Tx_DV     => r_Tx_DV,         -- Triggered by our Flow Logic
        i_Tx_Byte   => w_FIFO_Rd_Data,  -- Data comes from FIFO
        o_Tx_Active => w_Tx_Active,     -- Tells us if busy
        o_Tx_Serial => w_Tx_Serial,
        o_Tx_Done   => open
    );

    o_UART_TX <= w_Tx_Serial;

end rtl;
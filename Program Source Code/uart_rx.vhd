library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic (
        g_CLKS_PER_BIT : integer := 434
    );
    port (
        i_Clk       : in  std_logic;
        i_Rx_Serial : in  std_logic;
        o_Rx_DV     : out std_logic;       -- Data Valid Pulse
        o_Rx_Byte   : out std_logic_vector(7 downto 0)
    );
end uart_rx;

architecture rtl of uart_rx is

    type t_SM_Main is (s_IDLE, s_RX_START_BIT, s_RX_DATA_BITS, s_RX_STOP_BIT, s_CLEANUP);
    signal r_SM_Main : t_SM_Main := s_IDLE;

    signal r_Clk_Count : integer range 0 to g_CLKS_PER_BIT-1 := 0;
    signal r_Bit_Index : integer range 0 to 7 := 0; -- 8 Bits Total
    signal r_Rx_Byte   : std_logic_vector(7 downto 0) := (others => '0');
    -- Initialize to '1' (UART Idle state) to prevent false start
    signal r_Rx_Data_R : std_logic := '1';
    signal r_Rx_Data   : std_logic := '1';

begin

    -- Purpose: Double-register the incoming data to remove metastability
    p_SAMPLE : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            r_Rx_Data_R <= i_Rx_Serial;
            r_Rx_Data   <= r_Rx_Data_R;
        end if;
    end process p_SAMPLE;

    -- Purpose: Control RX State Machine
    p_UART_RX : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            case r_SM_Main is
                
                -- Wait for Start Bit (Falling Edge)
                when s_IDLE =>
                    o_Rx_DV     <= '0';
                    r_Clk_Count <= 0;
                    r_Bit_Index <= 0;

                    if r_Rx_Data = '0' then       -- Start bit detected
                        r_SM_Main <= s_RX_START_BIT;
                    else
                        r_SM_Main <= s_IDLE;
                    end if;

                -- Check middle of Start Bit to confirm validity
                when s_RX_START_BIT =>
                    if r_Clk_Count = (g_CLKS_PER_BIT-1)/2 then
                        if r_Rx_Data = '0' then
                            r_Clk_Count <= 0;  -- Reset counter, found the middle
                            r_SM_Main   <= s_RX_DATA_BITS;
                        else
                            r_SM_Main   <= s_IDLE;
                        end if;
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_Main   <= s_RX_START_BIT;
                    end if;

                -- Sample Data Bits
                when s_RX_DATA_BITS =>
                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_Main   <= s_RX_DATA_BITS;
                    else
                        r_Clk_Count            <= 0;
                        r_Rx_Byte(r_Bit_Index) <= r_Rx_Data;
                        
                        if r_Bit_Index < 7 then
                            r_Bit_Index <= r_Bit_Index + 1;
                            r_SM_Main   <= s_RX_DATA_BITS;
                        else
                            r_Bit_Index <= 0;
                            r_SM_Main   <= s_RX_STOP_BIT;
                        end if;
                    end if;

                -- Receive Stop Bit (Wait for it to finish)
                when s_RX_STOP_BIT =>
                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_Main   <= s_RX_STOP_BIT;
                    else
                        o_Rx_DV     <= '1';
                        o_Rx_Byte   <= r_Rx_Byte;
                        r_Clk_Count <= 0;
                        r_SM_Main   <= s_CLEANUP;
                    end if;

                -- Stay here for 1 clock cycle
                when s_CLEANUP =>
                    r_SM_Main <= s_IDLE;
                    o_Rx_DV   <= '0';

                when others =>
                    r_SM_Main <= s_IDLE;

            end case;
        end if;
    end process p_UART_RX;

end rtl;
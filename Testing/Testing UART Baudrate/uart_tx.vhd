library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic (
        g_CLKS_PER_BIT : integer := 25
    );
    port (
        i_Clk       : in  std_logic;
        i_Tx_DV     : in  std_logic;
        i_Tx_Byte   : in  std_logic_vector(7 downto 0);
        o_Tx_Active : out std_logic;
        o_Tx_Serial : out std_logic;
        o_Tx_Done   : out std_logic
    );
end uart_tx;

architecture rtl of uart_tx is

    type t_SM_Main is (s_IDLE, s_TX_START_BIT, s_TX_DATA_BITS, s_TX_STOP_BIT, s_CLEANUP);
    signal r_SM_Main : t_SM_Main := s_IDLE;

    signal r_Clk_Count : integer range 0 to g_CLKS_PER_BIT-1 := 0;
    signal r_Bit_Index : integer range 0 to 7 := 0;
    signal r_Tx_Data   : std_logic_vector(7 downto 0) := (others => '0');

begin

    p_UART_TX : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            case r_SM_Main is

                when s_IDLE =>
                    o_Tx_Serial <= '1'; -- Drive Line High for Idle
                    o_Tx_Done   <= '0';
                    r_Clk_Count <= 0;
                    r_Bit_Index <= 0;

                    if i_Tx_DV = '1' then
                        r_Tx_Data   <= i_Tx_Byte;
                        r_SM_Main   <= s_TX_START_BIT;
                        o_Tx_Active <= '1';
                    else
                        o_Tx_Active <= '0';
                    end if;

                -- Send Start Bit (Logic 0)
                when s_TX_START_BIT =>
                    o_Tx_Serial <= '0';

                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_Main   <= s_TX_START_BIT;
                    else
                        r_Clk_Count <= 0;
                        r_SM_Main   <= s_TX_DATA_BITS;
                    end if;

                -- Send Data Bits (Least Significant Bit First)
                when s_TX_DATA_BITS =>
                    o_Tx_Serial <= r_Tx_Data(r_Bit_Index);

                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_Main   <= s_TX_DATA_BITS;
                    else
                        r_Clk_Count <= 0;
                        if r_Bit_Index < 7 then
                            r_Bit_Index <= r_Bit_Index + 1;
                            r_SM_Main   <= s_TX_DATA_BITS;
                        else
                            r_Bit_Index <= 0;
                            r_SM_Main   <= s_TX_STOP_BIT;
                        end if;
                    end if;

                -- Send Stop Bit (Logic 1)
                when s_TX_STOP_BIT =>
                    o_Tx_Serial <= '1';

                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_Main   <= s_TX_STOP_BIT;
                    else
                        o_Tx_Done   <= '1';
                        r_Clk_Count <= 0;
                        r_SM_Main   <= s_CLEANUP;
                        o_Tx_Active <= '0';
                    end if;

                when s_CLEANUP =>
                    o_Tx_Done <= '1';
                    r_SM_Main <= s_IDLE;

                when others =>
                    r_SM_Main <= s_IDLE;

            end case;
        end if;
    end process p_UART_TX;

end rtl;
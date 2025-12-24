library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is
    generic (
        g_WIDTH : integer := 8;
        g_DEPTH : integer := 256
    );
    port (
        i_Clk   : in std_logic;
        i_Rst   : in std_logic;
        
        -- Write Interface (Connect to UART RX)
        i_Wr_En : in std_logic;
        i_Wr_Data : in std_logic_vector(g_WIDTH-1 downto 0);
        o_Full  : out std_logic;
        
        -- Read Interface (Connect to UART TX)
        i_Rd_En : in std_logic;
        o_Rd_Data : out std_logic_vector(g_WIDTH-1 downto 0);
        o_Empty : out std_logic
    );
end fifo;

architecture rtl of fifo is
    type t_FIFO_Data is array (0 to g_DEPTH-1) of std_logic_vector(g_WIDTH-1 downto 0);
    signal r_FIFO_Data : t_FIFO_Data := (others => (others => '0'));

    signal r_Wr_Index : integer range 0 to g_DEPTH-1 := 0;
    signal r_Rd_Index : integer range 0 to g_DEPTH-1 := 0;
    signal r_Count    : integer range 0 to g_DEPTH := 0;

begin

    process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            if i_Rst = '1' then
                r_Wr_Index <= 0;
                r_Rd_Index <= 0;
                r_Count    <= 0;
            else
                -- Write Logic
                if (i_Wr_En = '1' and r_Count < g_DEPTH) then
                    r_FIFO_Data(r_Wr_Index) <= i_Wr_Data;
                    
                    if r_Wr_Index = g_DEPTH-1 then
                        r_Wr_Index <= 0;
                    else
                        r_Wr_Index <= r_Wr_Index + 1;
                    end if;
                end if;

                -- Read Logic
                if (i_Rd_En = '1' and r_Count > 0) then
                    o_Rd_Data <= r_FIFO_Data(r_Rd_Index);
                    
                    if r_Rd_Index = g_DEPTH-1 then
                        r_Rd_Index <= 0;
                    else
                        r_Rd_Index <= r_Rd_Index + 1;
                    end if;
                end if;

                -- Count Logic (Updates based on Read/Write happening same cycle)
                if (i_Wr_En = '1' and i_Rd_En = '0' and r_Count < g_DEPTH) then
                    r_Count <= r_Count + 1;
                elsif (i_Wr_En = '0' and i_Rd_En = '1' and r_Count > 0) then
                    r_Count <= r_Count - 1;
                end if;
                -- If both happen, Count stays the same
            end if;
        end if;
    end process;

    o_Full  <= '1' when r_Count = g_DEPTH else '0';
    o_Empty <= '1' when r_Count = 0       else '0';

end rtl;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity loop_filter is
    Port (
        clk      : in  STD_LOGIC;
        rst_n    : in  STD_LOGIC;
        acc_en   : in  STD_LOGIC;
        out_en   : in  STD_LOGIC;
        error_in : in  SIGNED(15 downto 0);
        audio_out: out SIGNED(31 downto 0)
    );
end loop_filter;


architecture Behavioral of loop_filter is
    signal accumulator : SIGNED(31 downto 0);
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            accumulator <= (others => '0');
            audio_out <= (others => '0');
        elsif rising_edge(clk) then
            -- Jalur Integral (Update Akumulator)
            if acc_en = '1' then
                -- Geser 6 bit (bagi 64) sebagai Gain Ki
                accumulator <= accumulator + resize(shift_right(error_in, 6), 32);
            end if;
           
            -- Jalur Output (P + I)
            if out_en = '1' then
                -- Geser 2 bit (bagi 4) sebagai Gain Kp
                audio_out <= accumulator + resize(shift_right(error_in, 2), 32);
            end if;
        end if;
    end process;
end Behavioral;
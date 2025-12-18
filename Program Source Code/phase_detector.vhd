library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity phase_detector is
    Port (
        clk         : in  STD_LOGIC;
        rst_n       : in  STD_LOGIC;
        en          : in  STD_LOGIC; -- Sinyal Enable dari FSM
        fm_in       : in  SIGNED(7 downto 0); -- Input dari FIFO
        nco_fb      : in  SIGNED(7 downto 0); -- Feedback dari NCO
        error_out   : out SIGNED(15 downto 0) -- Output 16-bit
    );
end phase_detector;


architecture Behavioral of phase_detector is
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            error_out <= (others => '0');
        elsif rising_edge(clk) then
            if en = '1' then
                -- Perkalian: 8-bit * 8-bit = 16-bit
                error_out <= fm_in * nco_fb;
            end if;
        end if;
    end process;
end Behavioral;
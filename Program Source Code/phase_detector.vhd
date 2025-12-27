library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity phase_detector is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        enable   : in  std_logic;
        
        data_in  : in  std_logic_vector(7 downto 0); 
        nco_in   : in  std_logic_vector(7 downto 0);

        pd_out   : out std_logic_vector(15 downto 0)
    );
end phase_detector;

architecture rtl of phase_detector is
    signal input_signed : signed(7 downto 0);
    signal nco_signed   : signed(7 downto 0);
    signal mult_result  : signed(15 downto 0);
begin
    input_signed <= signed(unsigned(data_in) - 128);
    nco_signed   <= signed(unsigned(nco_in) - 128);

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                mult_result <= (others => '0');
            elsif enable = '1' then
                mult_result <= input_signed * nco_signed;
            end if;
        end if;
    end process;

    pd_out <= std_logic_vector(mult_result);
end rtl;
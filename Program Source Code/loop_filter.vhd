library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity loop_filter is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        enable   : in  std_logic;
        pd_in    : in  std_logic_vector(15 downto 0);
        lf_out   : out std_logic_vector(31 downto 0)
    );
end loop_filter;

architecture rtl of loop_filter is
    signal pd_signed     : signed(15 downto 0);
    signal integrator    : signed(31 downto 0) := (others => '0');
    signal output_signal : signed(31 downto 0) := (others => '0');
begin
    pd_signed <= signed(pd_in);

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                integrator <= (others => '0');
                output_signal <= (others => '0');
            elsif enable = '1' then
                -- HIGH GAIN: Resize FIRST, then Multiply by 1024 (Shift 10)
                integrator    <= integrator + shift_left(resize(pd_signed, 32), 10);
                output_signal <= shift_left(resize(pd_signed, 32), 10) + integrator;
            end if;
        end if;
    end process;

    lf_out <= std_logic_vector(output_signal);
end rtl;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity loop_filter is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        enable   : in  std_logic;
        
        pd_in    : in  std_logic_vector(15 downto 0); -- Dari Phase Detector
        
        lf_out   : out std_logic_vector(31 downto 0)  -- Sinyal Audio / Kontrol NCO
    );
end loop_filter;

architecture rtl of loop_filter is
    signal pd_signed     : signed(15 downto 0);
    signal integrator    : signed(31 downto 0) := (others => '0');
    signal output_signal : signed(31 downto 0);
begin
    pd_signed <= signed(pd_in);

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                integrator <= (others => '0');
                output_signal <= (others => '0');
            elsif enable = '1' then
                -- 1. Update Integrator (I)
                -- Gain Integral (Ki) = 1/64 (Shift Right 6)
                -- Integrator mengakumulasi error
                integrator <= integrator + resize(shift_right(pd_signed, 10), 32);
                
                -- 2. Hitung Output (P + I)
                -- Gain Proporsional (Kp) = 1/2 (Shift Right 1)
                -- Output = (P * Error) + Integrator
                output_signal <= resize(shift_right(pd_signed, 10), 32) + integrator;
            end if;
        end if;
    end process;

    lf_out <= std_logic_vector(output_signal);
end rtl;
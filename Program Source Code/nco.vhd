library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity nco is
    port (
        clk : in std_logic;
        reset : in std_logic;
        enable   : in std_logic;
        phase_in : in std_logic_vector(31 downto 0);
        sine_out : out std_logic_vector(7 downto 0)
    );
end nco;

architecture Behavioral of nco is

    constant phase_in_res : integer := 32;
    constant lookup_table_depth : integer := 256;
    constant lookup_table_bit : integer := 8;

    signal phase_acc : unsigned(phase_in_res-1 downto 0);

    type lookup_table is array (0 to lookup_table_depth-1) of std_logic_vector(lookup_table_bit-1 downto 0);

    constant sine_lookup_table : lookup_table := (
        x"80", x"83", x"86", x"89", x"8C", x"8F", x"92", x"95", 
        x"98", x"9B", x"9E", x"A2", x"A5", x"A7", x"AA", x"AD", 
        x"B0", x"B3", x"B6", x"B9", x"BC", x"BE", x"C1", x"C4",
        x"C6", x"C9", x"CB", x"CE", x"D0", x"D3", x"D5", x"D7",
        x"DA", x"DC", x"DE", x"E0", x"E2", x"E4", x"E6", x"E8",
        x"EA", x"EB", x"ED", x"EE", x"F0", x"F1", x"F3", x"F4",
        x"F5", x"F6", x"F8", x"F9", x"FA", x"FA", x"FB", x"FC",
        x"FD", x"FD", x"FE", x"FE", x"FE", x"FF", x"FF", x"FF",
        x"FF", x"FF", x"FF", x"FF", x"FE", x"FE", x"FE", x"FD",
        x"FD", x"FC", x"FB", x"FA", x"FA", x"F9", x"F8", x"F6",
        x"F5", x"F4", x"F3", x"F1", x"F0", x"EE", x"ED", x"EB",
        x"EA", x"E8", x"E6", x"E4", x"E2", x"E0", x"DE", x"DC",
        x"DA", x"D7", x"D5", x"D3", x"D0", x"CE", x"CB", x"C9",
        x"C6", x"C4", x"C1", x"BE", x"BC", x"B9", x"B6", x"B3",
        x"B0", x"AD", x"AA", x"A7", x"A5", x"A2", x"9E", x"9B",
        x"98", x"95", x"92", x"8F", x"8C", x"89", x"86", x"83",
        x"80", x"7C", x"79", x"76", x"73", x"70", x"6D", x"6A",
        x"67", x"64", x"61", x"5D", x"5A", x"58", x"55", x"52",
        x"4F", x"4C", x"49", x"46", x"43", x"41", x"3E", x"3B",
        x"39", x"36", x"34", x"31", x"2F", x"2C", x"2A", x"28",
        x"25", x"23", x"21", x"1F", x"1D", x"1B", x"19", x"17",
        x"15", x"14", x"12", x"11", x"0F", x"0E", x"0C", x"0B",
        x"0A", x"09", x"07", x"06", x"05", x"05", x"04", x"03",
        x"02", x"02", x"01", x"01", x"01", x"00", x"00", x"00",
        x"00", x"00", x"00", x"00", x"01", x"01", x"01", x"02",
        x"02", x"03", x"04", x"05", x"05", x"06", x"07", x"09",
        x"0A", x"0B", x"0C", x"0E", x"0F", x"11", x"12", x"14",
        x"15", x"17", x"19", x"1B", x"1D", x"1F", x"21", x"23",
        x"25", x"28", x"2A", x"2C", x"2F", x"31", x"34", x"36",
        x"39", x"3B", x"3E", x"41", x"43", x"46", x"49", x"4C",
        x"4F", x"52", x"55", x"58", x"5A", x"5D", x"61", x"64",
        x"67", x"6A", x"6D", x"70", x"73", x"76", x"79", x"7C"
    );

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                phase_acc <= (others => '0');
            elsif enable = '1' then
                phase_acc <= phase_acc + unsigned(phase_in);
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            sine_out <= sine_lookup_table(to_integer(phase_acc(phase_in_res-1 downto phase_in_res-lookup_table_bit)));
        end if;
    end process;

end Behavioral;

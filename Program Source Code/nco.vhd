library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity nco is
    Port (
        clk      : in  STD_LOGIC;
        rst_n    : in  STD_LOGIC;
        phase_en : in  STD_LOGIC;
        out_en   : in  STD_LOGIC;
        audio_in : in  SIGNED(31 downto 0);
        nco_out  : out SIGNED(7 downto 0)
    );
end nco;


architecture Behavioral of nco is
    constant CENTER_FREQ : UNSIGNED(31 downto 0) := to_unsigned(171798, 32);
    signal phase_acc : UNSIGNED(31 downto 0);
   
    -- Lookup Table
    type t_rom is array (0 to 15) of SIGNED(7 downto 0);
    constant sine_lut : memory_type := (
        x"7F", x"7F", x"7F", x"7F", x"7E", x"7E", x"7E", x"7D",
        x"7D", x"7C", x"7B", x"7A", x"7A", x"79", x"78", x"76",
        x"75", x"74", x"73", x"71", x"70", x"6F", x"6D", x"6B",
        x"6A", x"68", x"66", x"64", x"62", x"60", x"5E", x"5C",
        x"5A", x"58", x"55", x"53", x"51", x"4E", x"4C", x"49",
        x"47", x"44", x"41", x"3F", x"3C", x"39", x"36", x"33",
        x"31", x"2E", x"2B", x"28", x"25", x"22", x"1F", x"1C",
        x"19", x"16", x"13", x"10", x"0C", x"09", x"06", x"03",
        x"00", x"FD", x"FA", x"F7", x"F4", x"F0", x"ED", x"EA",
        x"E7", x"E4", x"E1", x"DE", x"DB", x"D8", x"D5", x"D2",
        x"CF", x"CD", x"CA", x"C7", x"C4", x"C1", x"BF", x"BC",
        x"B9", x"B7", x"B4", x"B2", x"AF", x"AD", x"AB", x"A8",
        x"A6", x"A4", x"A2", x"A0", x"9E", x"9C", x"9A", x"98",
        x"96", x"95", x"93", x"91", x"90", x"8F", x"8D", x"8C",
        x"8B", x"8A", x"88", x"87", x"86", x"86", x"85", x"84",
        x"83", x"83", x"82", x"82", x"82", x"81", x"81", x"81",
        x"81", x"81", x"81", x"81", x"82", x"82", x"82", x"83",
        x"83", x"84", x"85", x"86", x"86", x"87", x"88", x"8A",
        x"8B", x"8C", x"8D", x"8F", x"90", x"91", x"93", x"95",
        x"96", x"98", x"9A", x"9C", x"9E", x"A0", x"A2", x"A4",
        x"A6", x"A8", x"AB", x"AD", x"AF", x"B2", x"B4", x"B7",
        x"B9", x"BC", x"BF", x"C1", x"C4", x"C7", x"CA", x"CD",
        x"CF", x"D2", x"D5", x"D8", x"DB", x"DE", x"E1", x"E4",
        x"E7", x"EA", x"ED", x"F0", x"F4", x"F7", x"FA", x"FD",
        x"00", x"03", x"06", x"09", x"0C", x"10", x"13", x"16",
        x"19", x"1C", x"1F", x"22", x"25", x"28", x"2B", x"2E",
        x"31", x"33", x"36", x"39", x"3C", x"3F", x"41", x"44",
        x"47", x"49", x"4C", x"4E", x"51", x"53", x"55", x"58",
        x"5A", x"5C", x"5E", x"60", x"62", x"64", x"66", x"68",
        x"6A", x"6B", x"6D", x"6F", x"70", x"71", x"73", x"74",
        x"75", x"76", x"78", x"79", x"7A", x"7A", x"7B", x"7C",
        x"7D", x"7D", x"7E", x"7E", x"7E", x"7F", x"7F", x"7F"
    );
   
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            phase_acc <= (others => '0');
        elsif rising_edge(clk) then
            -- Update Fasa
            if phase_en = '1' then
                phase_acc <= phase_acc + CENTER_FREQ + unsigned(audio_in);
            end if;
           
            -- Baca ROM (Ambil 4 bit MSB sebagai alamat contoh ini)
            if out_en = '1' then
                nco_out <= sine_lut(to_integer(phase_acc(31 downto 28)));
            end if;
        end if;
    end process;
end Behavioral;
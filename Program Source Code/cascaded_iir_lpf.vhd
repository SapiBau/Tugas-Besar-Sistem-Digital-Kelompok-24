library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cascaded_iir_lpf is
    Generic (
        STAGES       : integer := 0;   
        SHIFT_FACTOR : integer := 0;   
        DATA_WIDTH   : integer := 32;
        -- UBAH INI: Perkecil shift agar sinyal kecil bisa terlihat
        OUTPUT_SHIFT : integer := 4  
    );
    Port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        enable   : in  std_logic;
        data_in  : in  std_logic_vector(31 downto 0);
        data_out : out std_logic_vector(7 downto 0)
    );
end cascaded_iir_lpf;

architecture Behavioral of cascaded_iir_lpf is

    type filter_array_t is array (0 to STAGES) of signed(DATA_WIDTH-1 downto 0);
    signal filter_stages : filter_array_t;

begin

    filter_stages(0) <= signed(data_in);

    gen_filters: for i in 1 to STAGES generate
        process(clk)
            variable diff : signed(DATA_WIDTH downto 0);
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    filter_stages(i) <= (others => '0');
                elsif enable = '1' then 
                    diff := resize(filter_stages(i-1), DATA_WIDTH + 1) - resize(filter_stages(i), DATA_WIDTH + 1);
                    filter_stages(i) <= filter_stages(i) + resize(shift_right(diff, SHIFT_FACTOR), DATA_WIDTH);
                end if;
            end if;
        end process;
    end generate;

    -- LOGIKA OUTPUT DENGAN SATURASI (Agar tidak lurus 0/255 terus)
    process(filter_stages, rst)
        variable v_scaled_val : signed(DATA_WIDTH-1 downto 0);
        variable v_final_int  : integer;
    begin
        if rst = '1' then
            data_out <= x"80"; -- Default 128
        else
            -- Geser data sesuai OUTPUT_SHIFT
            v_scaled_val := shift_right(filter_stages(STAGES), OUTPUT_SHIFT);
            v_final_int  := to_integer(v_scaled_val);

            -- Logika Saturasi: Cek apakah melebihi range -128 s.d +127
            if v_final_int > 127 then
                data_out <= x"FF"; -- Mentok Atas
            elsif v_final_int < -128 then
                data_out <= x"00"; -- Mentok Bawah
            else
                -- Tambah 128 agar jadi Unsigned (0-255)
                data_out <= std_logic_vector(to_unsigned(v_final_int + 128, 8));
            end if;
        end if;
    end process;

end Behavioral;
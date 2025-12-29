library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity low_pass_filter is
    Generic (
        STAGES       : integer := 2;   -- Number of cascaded filters
        SHIFT_FACTOR : integer := 4;   -- Filter strength (Alpha = 1/2^SHIFT_FACTOR)
        DATA_WIDTH   : integer := 24;  -- Input width
        OUTPUT_WIDTH : integer := 8    -- Output width
    );
    Port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        en       : in  std_logic;
        data_in  : in  signed(DATA_WIDTH-1 downto 0);
        data_out : out unsigned(OUTPUT_WIDTH-1 downto 0)
    );
end low_pass_filter;

architecture Behavioral of low_pass_filter is

    -- DSP FIX: Internal accumulators need extra precision to prevent deadband.
    -- We add 'SHIFT_FACTOR' extra bits at the bottom (fractional part).
    constant ACC_WIDTH : integer := DATA_WIDTH + SHIFT_FACTOR;
    
    type filter_array_t is array (0 to STAGES) of signed(ACC_WIDTH-1 downto 0);
    signal filter_stages : filter_array_t;

begin

    -- Stage 0 is just the input, but we must shift it up to match the accumulator width
    -- (Mathematically effectively multiplying by 2^SHIFT_FACTOR)
    filter_stages(0) <= shift_left(resize(data_in, ACC_WIDTH), SHIFT_FACTOR);
	 
    gen_filters: for i in 1 to STAGES generate
        process(clk)
            variable diff : signed(ACC_WIDTH downto 0);
            variable next_val : signed(ACC_WIDTH downto 0); -- Extra bit for overflow check
            
            -- Constants for clamping
            constant MAX_VAL : signed(ACC_WIDTH-1 downto 0) := (ACC_WIDTH-1 => '0', others => '1');
            constant MIN_VAL : signed(ACC_WIDTH-1 downto 0) := (ACC_WIDTH-1 => '1', others => '0');
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    filter_stages(i) <= (others => '0');
                elsif en = '1' then
                    -- 1. Calculate Difference
                    diff := resize(filter_stages(i-1), ACC_WIDTH + 1) - resize(filter_stages(i), ACC_WIDTH + 1);
                    
                    -- 2. Calculate "Proposed" Next Value (using extra bit to detect overflow)
                    next_val := resize(filter_stages(i), ACC_WIDTH + 1) + resize(shift_right(diff, SHIFT_FACTOR), ACC_WIDTH + 1);
                    
                    -- 3. Clamping / Saturation Logic
                    if next_val > MAX_VAL then
                        filter_stages(i) <= MAX_VAL;
                    elsif next_val < MIN_VAL then
                        filter_stages(i) <= MIN_VAL;
                    else
                        -- Safe to cast back because we are within range
                        filter_stages(i) <= resize(next_val, ACC_WIDTH);
                    end if;
                end if;
            end if;
        end process;
    end generate;
	 
-- Output Assignment dengan SATURASI (Agar tidak wrapping/overflow)
    process(filter_stages)
        variable rounded_result : signed(DATA_WIDTH-1 downto 0);
        variable output_temp    : signed(DATA_WIDTH-1 downto 0);
    begin
        -- 1. Buang bagian pecahan (Rounding)
        rounded_result := resize(shift_right(filter_stages(STAGES), SHIFT_FACTOR), DATA_WIDTH);
        
        -- 2. Logika Saturasi (Clamping) ke range 8-bit (-128 sampai +127)
        -- Jika nilai > 127, paksa jadi 127.
        if rounded_result > 127 then
            output_temp := to_signed(127, DATA_WIDTH);
        -- Jika nilai < -128, paksa jadi -128.
        elsif rounded_result < -128 then
            output_temp := to_signed(-128, DATA_WIDTH);
        else
            output_temp := rounded_result;
        end if;

        -- 3. Konversi ke Unsigned 0-255 (Tambah 128) untuk UART/Python
        -- Ambil 8 bit terbawah setelah saturasi
        data_out <= unsigned(resize(output_temp + 128, OUTPUT_WIDTH));
        
    end process;

end Behavioral;
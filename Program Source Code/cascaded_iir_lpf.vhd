library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cascaded_iir_lpf is
    Generic (
        STAGES       : integer := 2;   -- Number of cascaded filters (poles)
        SHIFT_FACTOR : integer := 4;   -- Cutoff control: 2^4 = 16 (Higher = Slower/Smoother)
        DATA_WIDTH   : integer := 32   -- Internal calculation width
    );
    Port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        data_in  : in  std_logic_vector(31 downto 0); -- 32-bit Input
        data_out : out std_logic_vector(7 downto 0)   -- 8-bit Output
    );
end cascaded_iir_lpf;

architecture Behavioral of cascaded_iir_lpf is

    -- Define an array type to hold the 'y' (accumulator) for each stage
    type filter_array_t is array (0 to STAGES) of signed(DATA_WIDTH-1 downto 0);
    signal filter_stages : filter_array_t;

begin

    -- Connect the input to the 0th element of our array for easy looping
    filter_stages(0) <= signed(data_in);

    -- Generate loop to create cascaded filter stages
    -- Stage 1 takes input from Stage 0, Stage 2 takes from Stage 1, etc.
    gen_filters: for i in 1 to STAGES generate
        process(clk)
            variable diff : signed(DATA_WIDTH downto 0);
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    filter_stages(i) <= (others => '0');
                else
                    -- The EMA Equation: y[n] = y[n-1] + (x[n] - y[n-1]) >> k
                    
                    -- 1. Calculate difference: (Input from prev stage - Current Output)
                    diff := resize(filter_stages(i-1), DATA_WIDTH + 1) - resize(filter_stages(i),   DATA_WIDTH + 1);
                    
                    -- 2. Update accumulator: Current Output + (Difference / 2^k)
                    filter_stages(i) <= filter_stages(i) + resize(shift_right(diff, SHIFT_FACTOR), DATA_WIDTH);
                end if;
            end if;
        end process;
    end generate;

    -- Output Assignment:
    -- Take the output of the final stage.
    -- Since we have 32-bit precision but only want 8-bit output,
    -- we take the Most Significant Bits (MSBs) to preserve the range.
    data_out <= std_logic_vector(filter_stages(STAGES)(31 downto 24));

end Behavioral;
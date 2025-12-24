library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_cascaded_iir_lpf is
-- Testbench has no inputs or outputs
end tb_cascaded_iir_lpf;

architecture Behavioral of tb_cascaded_iir_lpf is

    -- 1. Component Declaration for the Unit Under Test (UUT)
    component cascaded_iir_lpf
        Generic (
            STAGES       : integer;
            SHIFT_FACTOR : integer;
            DATA_WIDTH   : integer
        );
        Port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            data_in  : in  std_logic_vector(31 downto 0);
            data_out : out std_logic_vector(7 downto 0)
        );
    end component;

    -- 2. Signal Definitions
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';
    signal data_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal data_out : std_logic_vector(7 downto 0);

    -- Clock period definition (100 MHz)
    constant clk_period : time := 10 ns;

begin

    -- 3. Instantiate the Unit Under Test (UUT)
    uut: cascaded_iir_lpf
    generic map (
        STAGES       => 2,  -- 2 Stages (2nd Order Filter)
        SHIFT_FACTOR => 4,  -- Filter Strength (Higher = Slower)
        DATA_WIDTH   => 32
    )
    port map (
        clk      => clk,
        rst      => rst,
        data_in  => data_in,
        data_out => data_out
    );

    -- 4. Clock Process definitions
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- 5. Stimulus Process
    stim_proc: process
    begin		
        -- == INITIALIZATION ==
        rst <= '1';
        data_in <= (others => '0'); -- Input starts at 0
        wait for 20 ns;	
        
        rst <= '0';
        wait for 20 ns;

        -- == TEST 1: STEP UP RESPONSE ==
        -- We apply a sudden "Step" to the maximum positive value.
        -- Input: 0x7FFFFFFF (Maximum 32-bit positive integer)
        -- Expected Output: Should NOT jump instantly. It should slowly count up 
        -- from 0x00 to 0x7F over many clock cycles.
        data_in <= X"7FFFFFFF"; 
        
        -- Hold this value for 200 clock cycles to let the filter "charge up"
        wait for clk_period * 200;

        -- == TEST 2: STEP DOWN RESPONSE ==
        -- We drop the input instantly back to 0.
        -- Expected Output: Should slowly decay from 0x7F down to 0x00.
        data_in <= X"00000000";
        
        wait for clk_period * 200;
        
        -- == TEST 3: NEGATIVE VALUE TEST ==
        -- We drop the input to a large negative value.
        -- Input: 0x80000000 (Maximum 32-bit negative integer, approx -2 billion)
        -- Expected Output: Should slowly drop to 0x80 (which represents -128 in 8-bit)
        data_in <= X"80000000";
        
        wait for clk_period * 200;

        -- End simulation
        wait;
    end process;

end Behavioral;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_nco is
    -- Testbench has no ports
end tb_nco;

architecture Behavioral of tb_nco is

    -- 1. Component Declaration (Must match your entity exactly)
    component nco
    port (
        clk      : in std_logic;
        reset    : in std_logic;
        phase_in : in std_logic_vector(31 downto 0);
        sine_out : out std_logic_vector(7 downto 0)
    );
    end component;

    -- 2. Signals
    signal clk_tb      : std_logic := '0';
    signal reset_tb    : std_logic := '0';
    signal phase_in_tb : std_logic_vector(31 downto 0) := (others => '0');
    signal sine_out_tb : std_logic_vector(7 downto 0);

    -- Clock Period (100 MHz)
    constant clk_period : time := 10 ns;

begin

    -- 3. Instantiate Unit Under Test (UUT)
    uut: nco PORT MAP (
        clk      => clk_tb,
        reset    => reset_tb,
        phase_in => phase_in_tb,
        sine_out => sine_out_tb
    );

    -- 4. Clock Process
    clk_process : process
    begin
        clk_tb <= '0';
        wait for clk_period/2;
        clk_tb <= '1';
        wait for clk_period/2;
    end process;

    -- 5. Stimulus Process
    stim_proc: process
    begin
        -- A. Reset the System
        reset_tb <= '1';
        wait for 100 ns;
        reset_tb <= '0';
        wait for clk_period;

        -- B. Test Case 1: Generate ~1 MHz Output
        -- Formula: FTW = (F_out * 2^32) / F_clk
        -- FTW = (1 MHz * 4,294,967,296) / 100 MHz = 42,949,673
        phase_in_tb <= std_logic_vector(to_unsigned(42949673, 32));
        
        wait for 2000 ns; -- Observe the 1 MHz wave

        -- C. Test Case 2: Double the frequency (~2 MHz)
        phase_in_tb <= std_logic_vector(to_unsigned(85899346, 32));

        wait for 2000 ns;

        -- D. Test Case 3: Zero Frequency (DC)
        phase_in_tb <= (others => '0');
        
        wait;
    end process;

end Behavioral;
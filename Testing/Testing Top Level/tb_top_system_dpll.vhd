library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_top_system_dpll is
end tb_top_system_dpll;

architecture behavior of tb_top_system_dpll is

    -- COMPONENT DECLARATION
    component top_system_dpll
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        rx_pin   : in  std_logic;
        tx_pin   : out std_logic
    );
    end component;

    -- SIGNALS
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';
    signal rx_pin   : std_logic := '1'; -- UART IDLE is High
    signal tx_pin   : std_logic;

    -- CLOCK PERIOD (50 MHz)
    constant clk_period : time := 20 ns;
    
    -- UART PERIOD (115200 Baud)
    -- 1 sec / 115200 = 8.68 us
    constant c_BIT_PERIOD : time := 8680 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: top_system_dpll port map (
        clk    => clk,
        rst    => rst,
        rx_pin => rx_pin,
        tx_pin => tx_pin
    );

    -- Clock Process
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- STIMULUS PROCESS (The "Fake PC")
-- STIMULUS PROCESS
    stim_proc: process
        file input_file      : text open read_mode is "simulation_input.txt";
        variable current_line : line;
        variable v_data_hex   : std_logic_vector(7 downto 0);
    begin
        -- 1. Reset Sequence
        rx_pin <= '1'; -- Idle
        rst <= '0';    -- Reset Active
        wait for 100 ns;
        rst <= '1';    -- Reset Released (Run)
        wait for 100 ns;

        -- 2. Loop through the file
        while not endfile(input_file) loop
            readline(input_file, current_line);
            hread(current_line, v_data_hex);

            -- A. Start Bit
            rx_pin <= '0';
            wait for c_BIT_PERIOD;
            
            -- B. Data Bits
            for i in 0 to 7 loop
                rx_pin <= v_data_hex(i);
                wait for c_BIT_PERIOD;
            end loop;
            
            -- C. Stop Bit
            rx_pin <= '1';
            wait for c_BIT_PERIOD;
            
            -- CRITICAL: Add Gap between bytes to let FIFO settle
            wait for 20 us; 
        end loop;

        assert false report "Simulation Finished" severity failure;
        wait;
    end process;

end behavior;
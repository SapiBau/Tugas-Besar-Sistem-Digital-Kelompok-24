library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_tx is
end tb_uart_tx;

architecture behave of tb_uart_tx is

    -- Component Declaration
    component uart_tx is
        generic (
            g_CLKS_PER_BIT : integer := 50
        );
        port (
            i_Clk       : in  std_logic;
            i_Tx_DV     : in  std_logic;
            i_Tx_Byte   : in  std_logic_vector(7 downto 0);
            o_Tx_Active : out std_logic;
            o_Tx_Serial : out std_logic;
            o_Tx_Done   : out std_logic
        );
    end component;

    -- Testbench Constants
    constant c_CLKS_PER_BIT : integer := 50;
    constant c_CLK_PERIOD   : time    := 20 ns; -- 50 MHz
    constant c_BIT_PERIOD   : time    := c_CLKS_PER_BIT * c_CLK_PERIOD;

    -- Signals
    signal r_Clk       : std_logic := '0';
    signal r_Tx_DV     : std_logic := '0';
    signal r_Tx_Byte   : std_logic_vector(7 downto 0) := (others => '0');
    signal w_Tx_Active : std_logic;
    signal w_Tx_Serial : std_logic;
    signal w_Tx_Done   : std_logic;

begin

    -- Instantiate the Unit Under Test (UUT)
    UUT : uart_tx
    generic map (
        g_CLKS_PER_BIT => c_CLKS_PER_BIT
    )
    port map (
        i_Clk       => r_Clk,
        i_Tx_DV     => r_Tx_DV,
        i_Tx_Byte   => r_Tx_Byte,
        o_Tx_Active => w_Tx_Active,
        o_Tx_Serial => w_Tx_Serial,
        o_Tx_Done   => w_Tx_Done
    );

    -- Clock Generation
    p_CLK_GEN : process
    begin
        r_Clk <= not r_Clk;
        wait for c_CLK_PERIOD / 2;
    end process p_CLK_GEN;

    -- ----------------------------------------------------------------------
    -- PROCESS 1: STIMULUS (The Driver)
    -- This process acts like the CPU sending data TO the UART Transmitter
    -- ----------------------------------------------------------------------
    p_STIMULUS : process
    begin
        -- Wait for Reset/Stabilize
        wait for c_CLK_PERIOD * 10;

        -- TEST CASE 1: Send 0x55 (Binary 01010101)
        -- We pulse i_Tx_DV for one clock cycle
        wait until rising_edge(r_Clk);
        r_Tx_Byte <= X"55";
        r_Tx_DV   <= '1'; 
        
        wait until rising_edge(r_Clk);
        r_Tx_DV   <= '0'; -- Turn off Data Valid trigger

        -- Wait for the Transmitter to finish
        wait until w_Tx_Done = '1';
        wait for c_CLK_PERIOD * 2;
        
        -- TEST CASE 2: Send 0x37 (Binary 00110111)
        wait until rising_edge(r_Clk);
        r_Tx_Byte <= X"37";
        r_Tx_DV   <= '1';
        
        wait until rising_edge(r_Clk);
        r_Tx_DV   <= '0';

        wait until w_Tx_Done = '1';

        -- End Simulation
        wait for c_CLK_PERIOD * 50;
        report "Simulation Complete. Check Waveforms." severity failure;
    end process p_STIMULUS;

    -- ----------------------------------------------------------------------
    -- PROCESS 2: VERIFICATION (The Monitor)
    -- This process "reads" the serial line to check if the data is correct.
    -- It runs in parallel to the stimulus.
    -- ----------------------------------------------------------------------
    p_CHECKER : process
        variable v_Rx_Byte : std_logic_vector(7 downto 0);
    begin
        -- Wait for Start Bit (Falling Edge of Serial Line)
        wait until falling_edge(w_Tx_Serial);

        -- Wait 1.5 bit periods to center align with the first Data Bit
        wait for c_BIT_PERIOD * 1.5;

        -- Loop to sample 8 data bits
        for ii in 0 to 7 loop
            v_Rx_Byte(ii) := w_Tx_Serial;
            wait for c_BIT_PERIOD;
        end loop;

        -- Check if Stop Bit is High
        -- We are currently in the middle of the Stop Bit
        assert w_Tx_Serial = '1' report "Test Failed: Stop Bit not detected." severity error;

        -- Compare Received Data with what we expected to send
        -- Note: We check r_Tx_Byte. 
        if r_Tx_Byte = v_Rx_Byte then
            report "Test Passed: Sent " & integer'image(to_integer(unsigned(r_Tx_Byte))) & 
                   ", Received " & integer'image(to_integer(unsigned(v_Rx_Byte)));
        else
            report "Test Failed: Sent " & integer'image(to_integer(unsigned(r_Tx_Byte))) & 
                   ", Received " & integer'image(to_integer(unsigned(v_Rx_Byte))) severity error;
        end if;
        
    end process p_CHECKER;

end behave;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_rx is
end tb_uart_rx;

architecture behave of tb_uart_rx is

    -- Component Declaration for the Unit Under Test (UUT)
    component uart_rx
        generic (
            g_CLKS_PER_BIT : integer := 50
        );
        port (
            i_Clk       : in  std_logic;
            i_Rx_Serial : in  std_logic;
            o_Rx_DV     : out std_logic;
            o_Rx_Byte   : out std_logic_vector(7 downto 0)
        );
    end component;

    -- Testbench Constants and Signals
    constant c_CLKS_PER_BIT : integer := 50;
    constant c_CLK_PERIOD   : time    := 20 ns; -- 50 MHz Clock
    constant c_BIT_PERIOD   : time    := c_CLKS_PER_BIT * c_CLK_PERIOD;

    signal r_Clk       : std_logic := '0';
    signal r_Rx_Serial : std_logic := '1'; -- UART Line is Idle High
    signal w_Rx_DV     : std_logic;
    signal w_Rx_Byte   : std_logic_vector(7 downto 0) := (others => '0');

    -- Procedure to generate the UART Serial Stream (The Test Vector)
    procedure UART_WRITE_BYTE (
        i_Data_In       : in  std_logic_vector(7 downto 0);
        signal o_Serial : out std_logic) is
    begin
        -- 1. Send Start Bit (Drive Low)
        o_Serial <= '0';
        wait for c_BIT_PERIOD;

        -- 2. Send Data Byte (LSB First)
        for ii in 0 to 7 loop
            o_Serial <= i_Data_In(ii);
            wait for c_BIT_PERIOD;
        end loop;

        -- 3. Send Stop Bit (Drive High)
        o_Serial <= '1';
        
        
        
    end UART_WRITE_BYTE;

begin

    -- Instantiate the UUT
    UUT : uart_rx
    generic map (
        g_CLKS_PER_BIT => c_CLKS_PER_BIT
    )
    port map (
        i_Clk       => r_Clk,
        i_Rx_Serial => r_Rx_Serial,
        o_Rx_DV     => w_Rx_DV,
        o_Rx_Byte   => w_Rx_Byte
    );

    -- Clock Generation Process
    p_CLK_GEN : process
    begin
        r_Clk <= not r_Clk;
        wait for c_CLK_PERIOD / 2;
    end process p_CLK_GEN;

    -- Main Stimulus Process
    p_STIMULUS : process
    begin
        -- Initial Wait to stabilize
        wait for c_CLK_PERIOD * 10;

        -- TEST CASE 1: Send the byte 0x37 (Binary 00110111)
        -- We expect o_Rx_Byte to become 0x37 and o_Rx_DV to pulse high.
        UART_WRITE_BYTE(X"37", r_Rx_Serial);
        
        -- Check logic pulse
        wait until w_Rx_DV = '1';
        report "Test Passed: Data Valid Pulse Detected";
        
        assert w_Rx_Byte = X"37" 
            report "Test Failed: Received Byte mismatch. Expected 37" 
            severity failure;

        -- End Simulation
        wait for c_CLK_PERIOD * 50;
        assert false report "Simulation Complete" severity failure;
    end process p_STIMULUS;

    -- TIMEOUT PROCESS
    -- Stops simulation if it runs longer than 1 ms (safety valve)
    p_TIMEOUT : process
    begin
        wait for 1 ms; -- Wait for a long time (much longer than expected packet)
        
        report "TEST FAILED: Timeout reached. The RX Unit never asserted Data Valid." 
        severity failure; -- This forces the simulator to stop
    end process p_TIMEOUT;

end behave;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_system_dpll is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        rx_pin   : in  std_logic;
        tx_pin   : out std_logic
    );
end top_system_dpll;

architecture rtl of top_system_dpll is

    -- CENTER FREQUENCY (0.25 * Sample Rate)
    constant CENTER_FREQ_WORD : unsigned(31 downto 0) := x"40000000"; 

    component uart_rx is
        generic ( g_CLKS_PER_BIT : integer := 434 );
        port (
            i_Clk       : in  std_logic;
            i_Rx_Serial : in  std_logic;
            o_Rx_DV     : out std_logic;
            o_Rx_Byte   : out std_logic_vector(7 downto 0)
        );
    end component;

    component uart_tx is
        generic ( g_CLKS_PER_BIT : integer := 434 );
        port (
            i_Clk       : in  std_logic;
            i_Tx_DV     : in  std_logic;
            i_Tx_Byte   : in  std_logic_vector(7 downto 0);
            o_Tx_Active : out std_logic;
            o_Tx_Serial : out std_logic;
            o_Tx_Done   : out std_logic
        );
    end component;

    -- Standard Component Declaration matching fifo.vhd exactly
    component fifo is
        generic ( g_WIDTH : integer := 8; g_DEPTH : integer := 256 );
        port (
            i_Clk     : in std_logic;
            i_Rst     : in std_logic;
            i_Wr_En   : in std_logic;
            i_Wr_Data : in std_logic_vector(g_WIDTH-1 downto 0);
            o_Full    : out std_logic;
            i_Rd_En   : in std_logic;
            o_Rd_Data : out std_logic_vector(g_WIDTH-1 downto 0);
            o_Empty   : out std_logic
        );
    end component;

    component phase_detector is
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            enable   : in  std_logic;
            data_in  : in  std_logic_vector(7 downto 0);
            nco_in   : in  std_logic_vector(7 downto 0);
            pd_out   : out std_logic_vector(15 downto 0)
        );
    end component;

    component loop_filter is
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            enable   : in  std_logic;
            pd_in    : in  std_logic_vector(15 downto 0);
            lf_out   : out std_logic_vector(31 downto 0)
        );
    end component;

    component nco is
        port (
            clk      : in std_logic;
            reset    : in std_logic;
            enable   : in std_logic;
            phase_in : in std_logic_vector(31 downto 0);
            sine_out : out std_logic_vector(7 downto 0)
        );
    end component;

    -- SIGNALS
    signal rx_data_byte : std_logic_vector(7 downto 0);
    signal rx_dv        : std_logic;
    signal fifo_empty   : std_logic;
    signal fifo_full    : std_logic;
    signal fifo_data_out: std_logic_vector(7 downto 0);
    signal fifo_read_en : std_logic := '0';
    signal system_enable : std_logic := '0';
    signal tx_active     : std_logic;
    signal tx_dv         : std_logic := '0';
    
    signal nco_feedback_sig : std_logic_vector(7 downto 0);
    signal pd_result_sig    : std_logic_vector(15 downto 0);
    signal lf_output_sig    : std_logic_vector(31 downto 0);
    signal nco_control_word : std_logic_vector(31 downto 0);
    signal final_output_byte : std_logic_vector(7 downto 0);
    signal w_rst_active : std_logic;

begin

    -- HANDS-FREE RESET (For Active Low Button)
    w_rst_active <= not rst;

    -- Instantiation with NAMED MAPPING (Prevents mismatches)
    inst_uart_rx: uart_rx
        generic map ( g_CLKS_PER_BIT => 434 )
        port map (
            i_Clk       => clk,
            i_Rx_Serial => rx_pin,
            o_Rx_DV     => rx_dv,
            o_Rx_Byte   => rx_data_byte
        );

    inst_fifo: fifo
        port map (
            i_Clk     => clk,
            i_Rst     => w_rst_active,
            i_Wr_En   => rx_dv,
            i_Wr_Data => rx_data_byte,
            o_Full    => fifo_full,
            i_Rd_En   => fifo_read_en,
            o_Rd_Data => fifo_data_out,
            o_Empty   => fifo_empty
        );

    -- PIPELINED TIMING LOGIC (The "Silence" Fix)
    process(clk)
    begin
        if rising_edge(clk) then
            if w_rst_active = '1' then
                fifo_read_en  <= '0';
                system_enable <= '0';
                tx_dv         <= '0';
            else
                fifo_read_en  <= '0';
                
                -- DELAY CHAIN:
                -- 1. Read Enable triggers fetch...
                -- 2. System Enable fires 1 cycle later (when data is ready)
                system_enable <= fifo_read_en; 
                
                -- 3. TX fires 1 cycle after processing
                tx_dv <= system_enable;
                
                -- TRIGGER:
                if (fifo_empty = '0') and (tx_active = '0') then
                    fifo_read_en <= '1';
                end if;
            end if;
        end if;
    end process;

    inst_pd: phase_detector
        port map (
            clk     => clk,
            rst     => w_rst_active,
            enable  => system_enable,
            data_in => fifo_data_out,
            nco_in  => nco_feedback_sig,
            pd_out  => pd_result_sig
        );

    inst_lf: loop_filter
        port map (
            clk    => clk,
            rst    => w_rst_active,
            enable => system_enable,
            pd_in  => pd_result_sig,
            lf_out => lf_output_sig
        );

    -- NCO ADDER (Shift 12 for Stability)
    nco_adder_proc: process(lf_output_sig)
    begin
        nco_control_word <= std_logic_vector(signed(CENTER_FREQ_WORD) + shift_left(signed(lf_output_sig), 12));
    end process;

    inst_nco: nco
        port map (
            clk      => clk,
            reset    => w_rst_active,
            enable   => system_enable,
            phase_in => nco_control_word,
            sine_out => nco_feedback_sig
        );

    -- DIRECT OUTPUT (No Filter Component)
    -- Select Bits 15-8 and Invert Bit 15 (Signed->Unsigned)
    final_output_byte <= (not lf_output_sig(15)) & lf_output_sig(14 downto 8);

    inst_uart_tx: uart_tx
        generic map ( g_CLKS_PER_BIT => 434 )
        port map (
            i_Clk       => clk,
            i_Tx_DV     => tx_dv,
            i_Tx_Byte   => final_output_byte,
            o_Tx_Active => tx_active,
            o_Tx_Serial => tx_pin,
            o_Tx_Done   => open
        );

end rtl;
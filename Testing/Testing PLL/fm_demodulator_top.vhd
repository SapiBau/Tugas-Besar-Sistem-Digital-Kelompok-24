library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fm_demodulator_top is
    Port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        enable     : in  std_logic;
        
        kp_config  : in  signed(15 downto 0);
        ki_config  : in  signed(15 downto 0);
        
        data_in    : in  std_logic_vector(7 downto 0);
        audio_out  : out std_logic_vector(7 downto 0);
        
        -- Debug Ports
        dbg_pd_out   : out std_logic_vector(15 downto 0); 
        dbg_lf_out   : out std_logic_vector(23 downto 0); 
        dbg_nco_out  : out std_logic_vector(7 downto 0)   
    );
end fm_demodulator_top;

architecture Structural of fm_demodulator_top is

    -- Sinyal Internal
    signal pd_result     : std_logic_vector(15 downto 0);
    signal pd_result_sgn : signed(15 downto 0);
    signal lf_cw_out     : signed(23 downto 0);
    signal lf_sat_flag   : std_logic;
    signal lf_err_smooth : signed(15 downto 0);
    signal nco_phase_in  : std_logic_vector(31 downto 0);
    signal nco_sine_out  : std_logic_vector(7 downto 0);
	 
	signal audio_centered : signed(23 downto 0);

begin

    -- 1. Phase Detector
    PD_INST: entity work.phase_detector
        port map (
            clk => clk, rst => rst, enable => enable,
            data_in => data_in, nco_in => nco_sine_out, pd_out => pd_result
        );
    pd_result_sgn <= signed(pd_result);

    -- 2. Loop Filter
    LF_INST: entity work.loop_filter
        generic map (CW0_VAL => 4294967, SHIFT_AMT =>12)
        port map (
            clk => clk, rst => rst, en => enable,
            kp_in => kp_config, ki_in => ki_config, error_raw => pd_result_sgn,
            cw_out => lf_cw_out, sat_flag => lf_sat_flag, error_smooth => lf_err_smooth
        );

    -- 3. NCO
    nco_phase_in <= std_logic_vector(resize(unsigned(lf_cw_out), 32));
    NCO_INST: entity work.nco
        port map (
            clk => clk, reset => rst, enable => enable,
            phase_in => nco_phase_in, sine_out => nco_sine_out
        );

		  audio_centered <= signed(lf_cw_out) - to_signed(4294967, 24);
		  
    -- 4. AUDIO PROCESSOR (Carrier Removal + LPF) - MODUL BARU
    AUDIO_PROC_INST: entity work.low_pass_filter
        generic map (
            STAGES     => 2, 
            SHIFT_FACTOR    => 4, 
            DATA_WIDTH   => 24,
			OUTPUT_WIDTH => 8
        )
        port map (
            clk       => clk,
            rst       => rst,
            en        => enable,
            data_in     => audio_centered, -- Input langsung 24-bit Signed
            data_out => audio_out  -- Output langsung 8-bit
        );

    -- Debug Outputs
    dbg_pd_out  <= pd_result;
    dbg_lf_out  <= std_logic_vector(lf_cw_out);
    dbg_nco_out <= nco_sine_out;

end Structural;
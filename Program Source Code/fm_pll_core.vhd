library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fm_pll_core is
    Port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        
        -- Interface ke FIFO RX
        i_fifo_not_empty : in  std_logic;
        i_data_byte      : in  std_logic_vector(7 downto 0);
        o_fifo_read_en   : out std_logic;
        
        -- Interface ke FIFO TX
        i_fifo_tx_full   : in  std_logic;
        o_result_valid   : out std_logic;
        o_result_byte    : out std_logic_vector(7 downto 0)
    );
end fm_pll_core;

architecture Behavioral of fm_pll_core is
    -- Rumus: (Fc / Fs) * 2^32
    -- Contoh: Carrier 90kHz, Sample Rate 250kHz
    -- (90.000 / 250.000) * 4294967296 = 1,546,188,226 (x5C28F5C2)
    constant C_CENTER_FREQ : unsigned(31 downto 0) := x"40000000";

    -- Komponen DSP (Sesuai update di atas)
    component phase_detector is
        port (clk, rst, enable : in std_logic; data_in, nco_in : in std_logic_vector(7 downto 0); pd_out : out std_logic_vector(15 downto 0));
    end component;

    component loop_filter is
        port (clk, rst, enable : in std_logic; pd_in : in std_logic_vector(15 downto 0); lf_out : out std_logic_vector(31 downto 0));
    end component;

    component nco is
        port (clk, reset, enable : in std_logic; phase_in : in std_logic_vector(31 downto 0); sine_out : out std_logic_vector(7 downto 0));
    end component;

    component cascaded_iir_lpf is
        port (clk, rst, enable : in std_logic; data_in : in std_logic_vector(31 downto 0); data_out : out std_logic_vector(7 downto 0));
    end component;

    -- Sinyal Kontrol Enable
    signal pd_en, lf_en, nco_en, iir_en : std_logic;
    
    -- Sinyal Data Internal
    signal nco_out   : std_logic_vector(7 downto 0);
    signal pd_result : std_logic_vector(15 downto 0);
    signal lf_result : std_logic_vector(31 downto 0);

    signal nco_phase_inc : std_logic_vector(31 downto 0);
    
    -- State Machine
    type t_SM is (
	 s_IDLE, 
	 s_READ_REQ, 
	 s_WAIT_RAM, 
	 s_PD, 
	 s_LF, 
	 s_CALC_FREQ,
	 s_NCO, 
	 s_IIR, 
	 s_WRITE_OUT);
    signal r_SM : t_SM := s_IDLE;

begin

    -- Instansiasi Komponen
    inst_pd  : phase_detector port map(clk, rst, pd_en, i_data_byte, nco_out, pd_result);
    inst_lf  : loop_filter    port map(clk, rst, lf_en, pd_result, lf_result);
    inst_nco : nco            port map(clk, rst, nco_en, nco_phase_inc, nco_out);
    inst_iir : cascaded_iir_lpf port map(clk, rst, iir_en, lf_result, o_result_byte);

    -- Proses FSM Sekuensial
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_SM <= s_IDLE;
                o_fifo_read_en <= '0';
                o_result_valid <= '0';
                pd_en <= '0'; lf_en <= '0'; nco_en <= '0'; iir_en <= '0';
            else
                -- Default: Matikan semua sinyal enable (hanya nyala 1 clock saat dibutuhkan)
                o_fifo_read_en <= '0';
                o_result_valid <= '0';
                pd_en <= '0'; lf_en <= '0'; nco_en <= '0'; iir_en <= '0';

                case r_SM is
                    when s_IDLE =>
                        -- Cek apakah ada data di input DAN ada tempat di output
                        if (i_fifo_not_empty = '1' and i_fifo_tx_full = '0') then
                            r_SM <= s_READ_REQ;
                        end if;

                    when s_READ_REQ =>
                        o_fifo_read_en <= '1'; -- Ambil data dari FIFO
                        r_SM <= s_WAIT_RAM;

                    when s_WAIT_RAM =>
                        -- Tunggu data valid keluar dari memori FIFO
                        r_SM <= s_PD;

                    when s_PD =>
                        pd_en <= '1'; -- Hitung Phase Detector
                        r_SM <= s_LF;

                    when s_LF =>
                        lf_en <= '1'; -- Hitung Loop Filter
                        r_SM <= s_CALC_FREQ;

                    when s_CALC_FREQ =>
                        -- Di sini kita tambahkan Center Freq + Output Filter
                        -- Loop Filter output (Signed 32-bit) ditambahkan ke Center Freq (Unsigned 32-bit)
                        nco_phase_inc <= std_logic_vector(C_CENTER_FREQ + unsigned(lf_result));
                        r_SM <= s_NCO;

                    when s_NCO =>
                        nco_en <= '1'; -- Update NCO (untuk sampel DEPAN)
                        r_SM <= s_IIR;

                    when s_IIR =>
                        iir_en <= '1'; -- Update Output Filter
                        r_SM <= s_WRITE_OUT;

                    when s_WRITE_OUT =>
                        o_result_valid <= '1'; -- Kirim ke FIFO TX
                        r_SM <= s_IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
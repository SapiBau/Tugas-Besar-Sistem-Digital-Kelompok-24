library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity loop_filter is
    generic (
        -- CW0_VAL dihitung untuk Carrier 50 kHz pada Clock 50 MHz
        -- Rumus: (50.000 / 50.000.000) * 2^32 = 4294967
        CW0_VAL   : integer := 4294967; 
        
        -- SHIFT_AMT = 12 untuk format Q12 (Fixed Point Arithmetic)
        SHIFT_AMT : integer := 12       
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        en           : in  std_logic;
        
        -- Input Gain Dinamis (Format Q12)
        -- Contoh: Nilai 4096 berarti Gain = 1.0
        -- Rekomendasi Awal: Kp = 4000-8000, Ki = 50-200
        kp_in        : in  signed(15 downto 0);
        ki_in        : in  signed(15 downto 0);
        
        error_raw    : in  signed(15 downto 0); -- Input dari Phase Detector
        
        cw_out       : out signed(23 downto 0); -- Output Tuning Word untuk NCO
        sat_flag     : out std_logic;           -- Indikator Saturasi
        error_smooth : out signed(15 downto 0)  -- Sinyal Error setelah FIR
    );
end entity;

architecture rtl of loop_filter is
    
    -- === 1. DEFINISI FIR FILTER (Smoothing) ===
    -- Koefisien filter untuk menghaluskan sinyal error yang noisy
    type coef_array is array (0 to 7) of integer;
    constant FIR_COEFF : coef_array := (1, 2, 3, 4, 4, 3, 2, 1); -- Total bobot = 20
    
    -- Shift Register untuk FIR
    type tap_array is array (0 to 7) of signed(15 downto 0);
    signal taps : tap_array := (others => (others => '0'));

    -- === 2. DEFINISI INTEGRATOR & INTERNAL ===
    signal integrator_acc : signed(31 downto 0) := (others => '0');
    
    -- Batas saturasi (Anti-windup limit)
    -- Mencegah integrator "meluap" terlalu jauh saat sinyal tidak lock
    constant INT_LIMIT : signed(31 downto 0) := to_signed(16777216, 32);
    
    -- Register Internal
    signal err_filt_sig : signed(15 downto 0) := (others => '0');
    signal kp_reg       : signed(15 downto 0) := (others => '0');
    signal ki_reg       : signed(15 downto 0) := (others => '0');

begin

    process(clk)
        -- Variabel FIR
        variable fir_sum  : integer;
        variable err_filt : integer;
        
        -- Variabel PI Controller
        variable kp_product : signed(31 downto 0);
        variable ki_product : signed(31 downto 0);
        variable combined   : signed(31 downto 0);
        variable cw_corr    : signed(31 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset Values
                taps           <= (others => (others => '0'));
                integrator_acc <= (others => '0');
                cw_out         <= to_signed(CW0_VAL, 24);
                sat_flag       <= '0';
                err_filt_sig   <= (others => '0');
                kp_reg         <= (others => '0');
                ki_reg         <= (others => '0');
                
            elsif en = '1' then
                
                -- Latch nilai Kp dan Ki agar stabil
                kp_reg <= kp_in;
                ki_reg <= ki_in;
                
                -- ========================================================
                -- TAHAP 1: FIR FILTER
                -- ========================================================
                -- Geser shift register
                --for i in 7 downto 1 loop 
                --    taps(i) <= taps(i-1);
                --end loop;
                --taps(0) <= error_raw;
                
                -- Hitung Konvolusi (Weighted Sum)
                --fir_sum := 0;
                --for i in 0 to 7 loop
                --    fir_sum := fir_sum + (to_integer(taps(i)) * FIR_COEFF(i));
                --end loop;
                
                -- Normalisasi (Dibagi total bobot 20)
                --err_filt := fir_sum / 20;
                --err_filt_sig <= to_signed(err_filt, 16);

                err_filt := to_integer(error_raw);
                err_filt_sig <= error_raw;

                -- ========================================================
                -- TAHAP 2: INTEGRATOR (I)
                -- ========================================================
                -- ki_product = Error * Ki
                ki_product := resize(to_signed(err_filt, 16) * ki_reg, 32);
                
                -- Akumulasi (Integrate)
                integrator_acc <= integrator_acc + shift_right(ki_product, SHIFT_AMT);

                -- Anti-Windup Logic
                if integrator_acc > INT_LIMIT then 
                    integrator_acc <= INT_LIMIT;
                    sat_flag <= '1';
                elsif integrator_acc < -INT_LIMIT then 
                    integrator_acc <= -INT_LIMIT;
                    sat_flag <= '1';
                else
                    sat_flag <= '0';
                end if;
                
                -- ========================================================
                -- TAHAP 3: PROPORTIONAL (P) & KOMBINASI
                -- ========================================================
                -- kp_product = Error * Kp
                kp_product := resize(to_signed(err_filt, 16) * kp_reg, 32);

                -- Combined = (P term >> shift) + I term
                combined := shift_right(kp_product, SHIFT_AMT) + integrator_acc;
                
                -- ========================================================
                -- TAHAP 4: OUTPUT FINAL
                -- ========================================================
                -- Correction = Combined >> shift
                cw_corr := shift_right(combined, SHIFT_AMT);

                -- Output = Frekuensi Dasar (50kHz) + Koreksi PI
                cw_out <= to_signed(CW0_VAL, 24) + resize(cw_corr, 24);
                
            end if;
        end if;
    end process;
    
    -- Output assignment untuk debugging
    error_smooth <= err_filt_sig;

end architecture;
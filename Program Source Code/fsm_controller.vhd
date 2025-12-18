library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity fsm_controller is
    Port (
        clk         : in  STD_LOGIC;
        rst_n       : in  STD_LOGIC;
       
        -- INPUT (Status dari Datapath)
        fifo_empty  : in  STD_LOGIC;
       
        -- OUTPUT (Kendali ke Datapath)
        fifo_rd_en  : out STD_LOGIC;
        en_pd       : out STD_LOGIC;
        en_pi_acc   : out STD_LOGIC;
        en_pi_out   : out STD_LOGIC;
        en_nco_ph   : out STD_LOGIC;
        en_nco_out  : out STD_LOGIC;
        tx_start    : out STD_LOGIC  
    );
end fsm_controller;


architecture Behavioral of fsm_controller is


    type t_state is (IDLE, READ_FIFO, CALC_PD, CALC_PI1, CALC_PI2, UPD_NCO1, UPD_NCO2, OUTPUT);
    signal state : t_state;


begin


    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= IDLE;
            -- Reset semua output
            fifo_rd_en <= '0';
            en_pd <= '0';
            en_pi_acc <= '0'; en_pi_out <= '0';
            en_nco_ph <= '0'; en_nco_out <= '0';
            tx_start   <= '0';
           
        elsif rising_edge(clk) then
            -- Default: Matikan semua enable (Pulse logic)
            fifo_rd_en <= '0';
            en_pd <= '0';
            en_pi_acc <= '0'; en_pi_out <= '0';
            en_nco_ph <= '0'; en_nco_out <= '0';
            tx_start   <= '0';


            case state is
                when IDLE =>
                    if fifo_empty = '0' then -- Cek Status Input
                        state <= READ_FIFO;
                    end if;
               
                when READ_FIFO =>
                    fifo_rd_en <= '1'; -- Perintah Datapath
                    state <= CALC_PD;
                   
                when CALC_PD =>
                    en_pd <= '1';
                    state <= CALC_PI1;
                   
                when CALC_PI1 =>
                    en_pi_acc <= '1';
                    state <= CALC_PI2;


                when CALC_PI2 =>
                    en_pi_out <= '1';
                    state <= UPD_NCO1;


                when UPD_NCO1 =>
                    en_nco_ph <= '1';
                    state <= UPD_NCO2;


                when UPD_NCO2 =>
                    en_nco_out <= '1';
                    state <= OUTPUT;
                   
                when OUTPUT =>
                    tx_start <= '1'; -- Picu UART TX
                    state <= IDLE;
            end case;
        end if;
    end process;


end Behavioral;
--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ERASER is
    Port (
        -- CLOCK AND RESET
        CLK             : in  std_logic;
        RST             : in  std_logic;

        -- INPUT META INTERFACE (PER EACH PACKET)
        RX_META_DISCARD : in  std_logic;
        RX_META_VLD     : in  std_logic;

        -- INPUT STREAM INTERFACE
        RX_DATA         : in  std_logic_vector(7 downto 0);
        RX_SOP          : in  std_logic;
        RX_EOP          : in  std_logic;
        RX_VLD          : in  std_logic;
        RX_RDY          : out std_logic;

        -- OUTPUT STREAM INTERFACE
        TX_DATA         : out std_logic_vector(7 downto 0);
        TX_SOP          : out std_logic;
        TX_EOP          : out std_logic;
        TX_VLD          : out std_logic;
        TX_RDY          : in  std_logic
    );
end entity;

architecture RTL of ERASER is

    type fsm_state is (idle, paket_ok, paket_ko);
    signal fsm_pstate : fsm_state;
    signal fsm_nstate : fsm_state;

begin

    TX_DATA <= RX_DATA;
    TX_SOP  <= RX_SOP;
    TX_EOP  <= RX_EOP;

    -- -------------------------------------------------------------------------
    --  FSM
    -- -------------------------------------------------------------------------

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                fsm_pstate <= idle;
            else
                fsm_pstate <= fsm_nstate;
            end if;
        end if;
    end process;

    process (fsm_pstate, RX_META_VLD, RX_META_DISCARD, TX_RDY, RX_VLD, RX_EOP)
    begin
        fsm_nstate <= idle;
        RX_RDY <= '0';
        TX_VLD <= '0';

        case fsm_pstate is
            when idle =>
                RX_RDY <= '0';
                TX_VLD <= '0';
                if (RX_META_VLD = '1') then
                    if (RX_META_DISCARD = '1') then
                        fsm_nstate <= paket_ko;
                    else
                        fsm_nstate <= paket_ok;
                    end if;
                else
                    fsm_nstate <= idle;
                end if;

            when paket_ok =>
                RX_RDY <= TX_RDY;
                TX_VLD <= RX_VLD;
                if (RX_EOP = '1' and RX_VLD = '1' and TX_RDY = '1') then
                    fsm_nstate <= idle;
                else
                    fsm_nstate <= paket_ok;
                end if;

            when paket_ko =>
                RX_RDY <= '1';
                TX_VLD <= '0';
                if (RX_EOP = '1' and RX_VLD = '1') then
                    fsm_nstate <= idle;
                else
                    fsm_nstate <= paket_ko;
                end if;
        end case;
    end process;

end architecture;

--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MATCH_UNIT is
    Generic (
        DATA_WIDTH : integer := 8;
        ADDR_WIDTH : integer := 4
    );
    Port (
        -- CLOCK AND RESET
        CLK        : in  std_logic;
        RST        : in  std_logic;

        -- MATCH INTERFACE
        MATCH_DATA : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        MATCH_ENA  : in  std_logic;
        MATCH_REQ  : in  std_logic;
        MATCH_BUSY : out std_logic;
        MATCH_ADDR : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        MATCH_HIT  : out std_logic;
        MATCH_VLD  : out std_logic;

        -- WRITE INTERFACE
        WRITE_DATA : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        WRITE_ENA  : in  std_logic;
        WRITE_ADDR : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        WRITE_REQ  : in  std_logic
    );
end entity;

architecture RTL of MATCH_UNIT is

    constant RAM_DATA_WIDTH : natural := DATA_WIDTH+1;

    signal ram_wr_data        : std_logic_vector(RAM_DATA_WIDTH-1 downto 0);
    signal ram_rd_addr        : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal ram_rd_data        : std_logic_vector(RAM_DATA_WIDTH-1 downto 0);
    signal ram_rd_data_vld    : std_logic;

    signal match_addr_cnt     : unsigned(ADDR_WIDTH+1-1 downto 0);
    signal match_addr_cnt_max : std_logic;
    signal match_data_reg     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal match_ena_reg      : std_logic;
    signal match_run          : std_logic;

    signal ram_match_hit      : std_logic;
    signal ram_match_vld      : std_logic;

    type fsm_state is (idle, match_running, done);
    signal fsm_pstate : fsm_state;
    signal fsm_nstate : fsm_state;

begin

    ram_wr_data <= WRITE_DATA & WRITE_ENA;

    sdp_ram_i : entity work.SDP_RAM
    generic map (
        DATA_WIDTH => RAM_DATA_WIDTH,
        ADDR_WIDTH => ADDR_WIDTH
    )
    port map (
        CLK         => CLK,
        RST         => RST,

        WR_DATA     => ram_wr_data,
        WR_ADDR     => WRITE_ADDR,
        WR_REQ      => WRITE_REQ,

        RD_ADDR     => ram_rd_addr,
        RD_REQ      => match_run,
        RD_DATA     => ram_rd_data,
        RD_DATA_VLD => ram_rd_data_vld
    );

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (match_run = '1') then
                match_addr_cnt <= match_addr_cnt + 1;
            else
                match_addr_cnt <= (others => '0');
            end if;
        end if;
    end process;

    match_addr_cnt_max <= match_addr_cnt(ADDR_WIDTH);
    ram_rd_addr <= std_logic_vector(match_addr_cnt(ADDR_WIDTH-1 downto 0));

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (MATCH_REQ = '1' and match_run = '0') then
                match_data_reg <= MATCH_DATA;
                match_ena_reg  <= MATCH_ENA;
            end if;
        end if;
    end process;

    ram_match_hit <= '1' when (ram_rd_data(DATA_WIDTH+1-1 downto 1) = match_data_reg) else '0';
    ram_match_vld <= ram_match_hit and ram_rd_data(0) and ram_rd_data_vld and match_ena_reg;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (match_run = '0') then
                MATCH_ADDR <= (others => '0');
                MATCH_HIT   <= '0';
            elsif (ram_match_vld = '1') then
                MATCH_ADDR <= ram_rd_addr;
                MATCH_HIT   <= '1';
            end if;
        end if;
    end process;

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

    process (fsm_pstate, MATCH_REQ, match_addr_cnt_max)
    begin
        fsm_nstate <= idle;
        match_run  <= '0';
        MATCH_VLD  <= '0';

        case fsm_pstate is
            when idle =>
                if (MATCH_REQ = '1') then
                    fsm_nstate <= match_running;
                else
                    fsm_nstate <= idle;
                end if;

            when match_running =>
                match_run <= '1';
                if (match_addr_cnt_max = '1') then
                    fsm_nstate <= done;
                else
                    fsm_nstate <= match_running;
                end if;

            when done =>
                match_run  <= '1';
                MATCH_VLD  <= '1';
                fsm_nstate <= idle;

        end case;
    end process;

    MATCH_BUSY <= match_run;

end architecture;

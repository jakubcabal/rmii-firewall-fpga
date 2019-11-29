--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MATCH_UNIT_WB is
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

        -- WISHBONE SLAVE INTERFACE
        WB_CYC     : in  std_logic;
        WB_STB     : in  std_logic;
        WB_WE      : in  std_logic;
        WB_ADDR    : in  std_logic_vector(15 downto 0);
        WB_DIN     : in  std_logic_vector(31 downto 0);
        WB_STALL   : out std_logic;
        WB_ACK     : out std_logic;
        WB_DOUT    : out std_logic_vector(31 downto 0)
    );
end entity;

architecture RTL of MATCH_UNIT_WB is

    constant WB_WORDS : integer := integer(real(DATA_WIDTH)/real(32));

    signal match_hit_sig  : std_logic;
    signal match_vld_sig  : std_logic;

    signal wr_enable      : std_logic;
    signal wr_request     : std_logic;
    signal wr_data_reg    : std_logic_vector(WB_WORDS*32-1 downto 0);
    signal wr_addr_reg    : std_logic_vector(31 downto 0);

    signal index_reg      : integer range 0 to WB_WORDS-1;

    signal cmd_sel        : std_logic;
    signal cmd_we         : std_logic;
    signal cmd_set_rule   : std_logic;
    signal cmd_rst_rule   : std_logic;

    signal addr_sel       : std_logic;
    signal addr_we        : std_logic;

    signal data_sel       : std_logic;
    signal data_we        : std_logic;

    signal status_reg     : std_logic_vector(31 downto 0);

begin

    -- -------------------------------------------------------------------------
    --  MATCH UNIT
    -- -------------------------------------------------------------------------

    match_unit_i : entity work.MATCH_UNIT
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        ADDR_WIDTH => ADDR_WIDTH
    )
    port map (
        CLK        => CLK,
        RST        => RST,

        MATCH_DATA => MATCH_DATA,
        MATCH_ENA  => MATCH_ENA,
        MATCH_REQ  => MATCH_REQ,
        MATCH_BUSY => MATCH_BUSY,
        MATCH_ADDR => MATCH_ADDR,
        MATCH_HIT  => match_hit_sig,
        MATCH_VLD  => match_vld_sig,

        WRITE_DATA => wr_data_reg(DATA_WIDTH-1 downto 0),
        WRITE_ENA  => wr_enable,
        WRITE_ADDR => wr_addr_reg(ADDR_WIDTH-1 downto 0),
        WRITE_REQ  => wr_request
    );

    MATCH_HIT <= match_hit_sig;
    MATCH_VLD <= match_vld_sig;

    wr_enable  <= cmd_set_rule;
    wr_request <= cmd_set_rule or cmd_rst_rule;

    wr_addr_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (addr_we = '1') then
                wr_addr_reg <= WB_DIN;
            end if;
        end if;
    end process;

    index_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or wr_request = '1') then
                index_reg <= 0;
            elsif (data_we = '1') then
                index_reg <= index_reg + 1;
            end if;
        end if;
    end process;

    wr_data_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (data_we = '1') then
                wr_data_reg((index_reg+1)*32-1 downto index_reg*32) <= WB_DIN;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  WISHBONE SLAVE LOGIC
    -- -------------------------------------------------------------------------

    cmd_sel <= '1' when (WB_ADDR(7 downto 0) = X"00") else '0';
    cmd_we  <= WB_STB and WB_WE and cmd_sel;

    addr_sel <= '1' when (WB_ADDR(7 downto 0) = X"08") else '0';
    addr_we  <= WB_STB and WB_WE and addr_sel;

    data_sel <= '1' when (WB_ADDR(7 downto 0) = X"0C") else '0';
    data_we  <= WB_STB and WB_WE and data_sel;

    cmd_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            cmd_set_rule   <= '0';
            cmd_rst_rule   <= '0';
            if (cmd_we = '1' and WB_DIN(7 downto 0) = X"00") then
                cmd_set_rule <= '1';
            end if;
            if (cmd_we = '1' and WB_DIN(7 downto 0) = X"01") then
                cmd_rst_rule <= '1';
            end if;
        end if;
    end process;

    status_reg <= std_logic_vector(to_unsigned(WB_WORDS,32));

    WB_STALL <= '0';

    wb_ack_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            WB_ACK <= WB_CYC and WB_STB;
        end if;
    end process;

    wb_dout_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            case WB_ADDR(7 downto 0) is
                when X"00" =>
                    WB_DOUT <= X"20191121"; -- version
                when X"04" =>
                    WB_DOUT <= status_reg;
                when X"08" =>
                    WB_DOUT <= wr_addr_reg;
                when others =>
                    WB_DOUT <= X"DEADCAFE";
            end case;
        end if;
    end process;

end architecture;

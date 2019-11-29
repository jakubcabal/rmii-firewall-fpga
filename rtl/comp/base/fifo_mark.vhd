--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FIFO_MARK is
    Generic (
        DATA_WIDTH : integer := 8;
        ADDR_WIDTH : integer := 4
    );
    Port (
        CLK         : in  std_logic;
        RST         : in  std_logic;
        -- FIFO WRITE INTERFACE
        WR_DATA     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        WR_REQ      : in  std_logic;
        WR_FULL     : out std_logic;
        -- FIFO READ INTERFACE
        RD_DATA     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        RD_DATA_VLD : out std_logic;
        RD_REQ      : in  std_logic;
        -- FIFO OTHERS SIGNALS
        MARK        : in  std_logic;
        DISCARD     : in  std_logic;
        STATUS      : out std_logic_vector(ADDR_WIDTH-1 downto 0)
    );
end entity;

architecture RTL of FIFO_MARK is

    signal wr_addr      : unsigned(ADDR_WIDTH-1 downto 0);
    signal wr_addr_mark : unsigned(ADDR_WIDTH-1 downto 0);
    signal wr_allowed   : std_logic;
    signal rd_addr      : unsigned(ADDR_WIDTH-1 downto 0);
    signal rd_allowed   : std_logic;
    signal cmp_full     : std_logic;
    signal cmp_afull    : std_logic;
    signal full_next    : std_logic;
    signal full_reg     : std_logic;
    signal cmp_empty    : std_logic;

    type bram_type is array(2**ADDR_WIDTH-1 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal bram : bram_type := (others => (others => '0'));

begin

    wr_allowed <= WR_REQ and not full_reg;
    rd_allowed <= RD_REQ and not cmp_empty;

    -- -------------------------------------------------------------------------
    --  BRAM AND READ DATA VALID
    -- -------------------------------------------------------------------------

    bram_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (wr_allowed = '1') then
                bram(to_integer(wr_addr)) <= WR_DATA;
            end if;
            if (RD_REQ = '1') then
                RD_DATA <= bram(to_integer(rd_addr));
            end if;
        end if;
    end process;

    rd_data_vld_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RD_REQ = '1') then 
                RD_DATA_VLD <= not cmp_empty;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  WRITE ADDRESS COUNTER
    -- -------------------------------------------------------------------------

    wr_addr_cnt_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                wr_addr <= (others => '0');
            elsif (DISCARD = '1') then
                wr_addr <= wr_addr_mark;
            elsif (wr_allowed = '1') then
                wr_addr <= wr_addr + 1;
            end if;
        end if;
    end process;

    wr_addr_mark_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                wr_addr_mark <= (others => '0');
            elsif (MARK = '1') then
                wr_addr_mark <= wr_addr;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  READ ADDRESS COUNTER
    -- -------------------------------------------------------------------------

    rd_addr_cnt_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                rd_addr <= (others => '0');
            elsif (rd_allowed = '1') then
                rd_addr <= rd_addr + 1;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --                        WR_FULL FLAG REGISTER
    -- -------------------------------------------------------------------------

    cmp_full  <= '1' when (rd_addr = (wr_addr+1)) else '0';
    cmp_afull <= '1' when (rd_addr = (wr_addr+2)) else '0';
    full_next <= cmp_full or (cmp_afull and WR_REQ and not RD_REQ);

    full_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                full_reg <= '0';
            else
                full_reg <= full_next;
            end if;
        end if;
    end process;

    WR_FULL <= full_reg;

    -- -------------------------------------------------------------------------
    --                        EMPTY FLAG AND FIFO STATUS
    -- -------------------------------------------------------------------------

    cmp_empty <= '1' when (rd_addr = wr_addr_mark) else '0';
    STATUS    <= std_logic_vector(wr_addr - rd_addr);

end architecture;

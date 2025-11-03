library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
  use std.textio.all;

entity tdp_ram is
  generic (
    G_A_LATENCY : natural range 1 to 2;
    G_B_LATENCY : natural range 1 to 2;
    G_INIT_FILE : string := "";
    G_RAM_STYLE : string := "block";
    G_ADDR_SIZE : integer;
    G_DATA_SIZE : integer
  );
  port (
    -- Port A
    a_clk_i     : in    std_logic;
    a_rst_i     : in    std_logic;
    a_addr_i    : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    a_wr_en_i   : in    std_logic;
    a_wr_data_i : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    a_rd_en_i   : in    std_logic;
    a_rd_data_o : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    -- Port B
    b_clk_i     : in    std_logic;
    b_rst_i     : in    std_logic;
    b_addr_i    : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    b_wr_en_i   : in    std_logic;
    b_wr_data_i : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    b_rd_en_i   : in    std_logic;
    b_rd_data_o : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity tdp_ram;

architecture synthesis of tdp_ram is

  type            ram_type is array (0 to 2 ** G_ADDR_SIZE - 1) of std_logic_vector(G_DATA_SIZE - 1 downto 0);

  -- This reads the ROM contents from a text file

  impure function initramfromfile (
    ramfilename : in string
  ) return ram_type is
    file     ramfile       : text;
    variable ramfileline_v : line;
    variable ram_v         : ram_type := (others => (others => '1'));
  begin
    if ramfilename /= "" then
      file_open(RamFile, ramfilename, read_mode);

      for i in ram_type'range loop
        readline (RamFile, ramfileline_v);
        read (ramfileline_v, ram_v(i));
        if endfile(RamFile) then
          return ram_v;
        end if;
      end loop;

    end if;
    return ram_v;
  end function initramfromfile;

  -- Initial memory contents
  shared variable ram_v : ram_type                                       := initramfromfile(G_INIT_FILE);

  attribute ram_style : string;
  attribute ram_style of ram_v : variable is G_RAM_STYLE;

  signal          a_rd_data : std_logic_vector(G_DATA_SIZE - 1 downto 0) := (others => '0');
  signal          b_rd_data : std_logic_vector(G_DATA_SIZE - 1 downto 0) := (others => '0');

begin

  a_proc : process (a_clk_i)
  begin
    if rising_edge(a_clk_i) then
      if G_A_LATENCY = 1 then
        if a_rd_en_i = '1' then
          a_rd_data_o <= ram_v(to_integer(a_addr_i));
        end if;
      elsif G_A_LATENCY = 2 then
        if a_rd_en_i = '1' then
          a_rd_data <= ram_v(to_integer(a_addr_i));
        end if;
        a_rd_data_o <= a_rd_data;
      else
        assert false;
      end if;

      if a_wr_en_i = '1' then
        ram_v(to_integer(a_addr_i)) := a_wr_data_i;
      end if;
    end if;
  end process a_proc;

  b_proc : process (b_clk_i)
  begin
    if rising_edge(b_clk_i) then
      if G_B_LATENCY = 1 then
        if b_rd_en_i = '1' then
          b_rd_data_o <= ram_v(to_integer(b_addr_i));
        end if;
      elsif G_B_LATENCY = 2 then
        if b_rd_en_i = '1' then
          b_rd_data <= ram_v(to_integer(b_addr_i));
        end if;
        b_rd_data_o <= b_rd_data;
      else
        assert false;
      end if;

      if b_wr_en_i = '1' then
        ram_v(to_integer(b_addr_i)) := b_wr_data_i;
      end if;
    end if;
  end process b_proc;

end architecture synthesis;


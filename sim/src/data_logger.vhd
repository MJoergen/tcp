library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This dumps the AXI data, in byte order

entity data_logger is
  generic (
    G_ENABLE     : boolean;
    G_LOG_NAME   : string(1 to 3);
    G_DATA_BYTES : natural
  );
  port (
    clk_i   : in    std_logic;
    rst_i   : in    std_logic;
    ready_i : in    std_logic;
    valid_i : in    std_logic;
    data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1  downto 0);
    start_i : in    natural range 0 to G_DATA_BYTES - 1;
    end_i   : in    natural range 0 to G_DATA_BYTES;
    last_i  : in    std_logic
  );
end entity data_logger;

architecture simulation of data_logger is

  constant C_BYTES_PER_ROW : natural := 4;

  pure function byte_reverse (
    arg : std_logic_vector
  ) return std_logic_vector is
    variable arg_v   : std_logic_vector(arg'length-1 downto 0);
    variable res_v   : std_logic_vector(arg'length-1 downto 0);
    variable bytes_v : natural;
  begin
    assert (arg'length mod 8) = 0;
    arg_v   := arg;
    bytes_v := arg_v'length / 8;
    for i in bytes_v - 1 downto 0 loop
      res_v(8 * i + 7 downto 8 * i) := arg_v(bytes_v * 8 - i * 8 - 1 downto bytes_v * 8 - i * 8 - 8);
    end loop;
    return res_v;
  end function byte_reverse;

begin

  logger_proc : process (clk_i)
    constant C_EMPTY_STR_V : string(1 to 2 * G_DATA_BYTES) := (others => '.');
    variable first_str_v   : string(1 to 6);
    variable last_str_v    : string(1 to 5);
    variable bytes_v       : natural range 1 to G_DATA_BYTES;
    variable first_row_v   : natural range 0 to G_DATA_BYTES / C_BYTES_PER_ROW;
    variable last_row_v    : natural range 0 to G_DATA_BYTES / C_BYTES_PER_ROW;
    variable first_idx_v   : natural range 0 to C_BYTES_PER_ROW - 1;
    variable last_idx_v    : natural range 0 to C_BYTES_PER_ROW;
  begin
    if rising_edge(clk_i) then
      if valid_i = '1' and ready_i = '1' and G_ENABLE then
        if end_i > start_i then
          bytes_v     := end_i - start_i;

          -- Determine which rows are active
          first_row_v := start_i / C_BYTES_PER_ROW;
          last_row_v  := (end_i - 1)  / C_BYTES_PER_ROW;

          for row in first_row_v to last_row_v loop
            first_str_v := "      ";
            first_idx_v := 0;
            last_str_v  := "     ";
            last_idx_v  := C_BYTES_PER_ROW;

            if row = first_row_v then
              first_str_v := G_LOG_NAME & " : ";
              first_idx_v := start_i mod C_BYTES_PER_ROW;
            end if;

            if row = last_row_v then
              last_idx_v := (end_i + C_BYTES_PER_ROW - 1) mod C_BYTES_PER_ROW + 1;
              if last_i = '1' then
                last_str_v := " LAST";
              end if;
            end if;

            report first_str_v &
                   C_EMPTY_STR_V(1 to 2 * first_idx_v) &
                   to_hstring(byte_reverse(data_i(
                   row * C_BYTES_PER_ROW * 8 + last_idx_v * 8 - 1 downto
                   row * C_BYTES_PER_ROW * 8 + first_idx_v * 8))) &
                   C_EMPTY_STR_V(2 * last_idx_v + 1 to 2 * C_BYTES_PER_ROW) &
                   last_str_v;
          end loop;
        end if;
      end if;
    end if;
  end process logger_proc;

end architecture simulation;


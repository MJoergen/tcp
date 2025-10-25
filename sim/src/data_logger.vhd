library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This dumps the data transmitted, in byte order

entity data_logger is
  generic (
    G_ENABLE    : boolean;
    G_LOG_NAME  : string(1 to 3);
    G_DATA_SIZE : natural
  );
  port (
    clk_i   : in    std_logic;
    rst_i   : in    std_logic;
    ready_i : in    std_logic;
    valid_i : in    std_logic;
    data_i  : in    std_logic_vector(G_DATA_SIZE - 1  downto 0);
    bytes_i : in    natural range 0 to G_DATA_SIZE / 8 - 1;
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

  assert (G_DATA_SIZE mod 8) = 0;

  logger_proc : process (clk_i)
    variable first_str_v  : string(1 to 6);
    variable last_str_v   : string(1 to 5);
    variable bytes_v      : natural range 1 to G_DATA_SIZE / 8;
    variable bytes_last_v : natural range 1 to C_BYTES_PER_ROW;
    variable num_rows_v   : natural range 1 to G_DATA_SIZE / 8 / C_BYTES_PER_ROW;
  begin
    if rising_edge(clk_i) then
      if valid_i = '1' and ready_i = '1' and G_ENABLE then
        -- Total number of bytes in packet
        bytes_v := G_DATA_SIZE / 8;
        if bytes_i > 0 then
          bytes_v := bytes_i;
        end if;

        assert bytes_v > 0;
        assert bytes_v <= G_DATA_SIZE / 8;

        -- Number of rows
        num_rows_v   := (bytes_v + C_BYTES_PER_ROW - 1) / C_BYTES_PER_ROW;

        -- Number of bytes in last row
        bytes_last_v := (bytes_v - 1) mod C_BYTES_PER_ROW + 1;

        for row in 0 to num_rows_v - 1 loop
          if row = 0 then
            first_str_v := G_LOG_NAME & " : ";
          else
            first_str_v := (others => ' ');
          end if;

          last_str_v := "     ";
          if row = num_rows_v - 1 then
            if last_i = '1' then
              last_str_v := " LAST";
            end if;
            report first_str_v & to_hstring(byte_reverse(data_i(
                   row * C_BYTES_PER_ROW * 8 + bytes_last_v * 8 - 1 downto
                   row * C_BYTES_PER_ROW * 8)
                   )) & last_str_v;
          else
            report first_str_v & to_hstring(byte_reverse(data_i(
                   row * C_BYTES_PER_ROW * 8 + C_BYTES_PER_ROW * 8 - 1 downto
                   row * C_BYTES_PER_ROW * 8)
                   ));
          end if;

        end loop;
      end if;
    end if;
  end process logger_proc;

end architecture simulation;


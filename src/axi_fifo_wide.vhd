library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This is an "elastic" FIFO. It accepts any number of bytes in each clock cycle.
-- And you can read out any number of bytes in each clock cycle.
--
-- The output m_bytes_o shows the number of bytes actually available.
--
-- Specifically, set m_bytes_i to the number of bytes you wish to read. Sampled when
-- m_ready_i is 1. The output m_valid_o is 1 if the m_bytes_o >= m_bytes_i.
--
-- The special case m_bytes_i = 0 causes all currently available bytes to be read.

entity axi_fifo_wide is
  generic (
    G_DATA_SIZE : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_bytes_i : in    natural range 0 to G_DATA_SIZE / 8;

    m_ready_i : in    std_logic;
    m_bytes_i : in    natural range 0 to G_DATA_SIZE / 8;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_bytes_o : out   natural range 0 to G_DATA_SIZE / 8
  );
end entity axi_fifo_wide;

architecture synthesis of axi_fifo_wide is

  signal data  : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal bytes : natural range 0 to G_DATA_SIZE / 8;

begin

  assert (G_DATA_SIZE mod 8) = 0;

  s_ready_o <= '1' when bytes + s_bytes_i <= G_DATA_SIZE / 8 and
                        (m_valid_o = '0' or m_ready_i = '0') else
               '0';

  m_valid_o <= '1' when bytes > 0 else
               '0';
  m_bytes_o <= bytes;
  m_data_o  <= data;

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_valid_o = '1' and m_ready_i = '1' then
        -- This is essentially a shift right
        for i in 0 to G_DATA_SIZE - 1 loop
          if i + m_bytes_i * 8 < G_DATA_SIZE then
            data(i) <= data(i + m_bytes_i * 8);
          end if;
        end loop;

        if m_bytes_i = 0 then
          bytes <= 0;
        else
          bytes <= bytes - m_bytes_i;
        end if;
      elsif s_valid_i = '1' and s_ready_o = '1' then
        for i in 0 to G_DATA_SIZE - 1 loop
          if i < s_bytes_i * 8 then
            data(bytes * 8 + i) <= s_data_i(i);
          end if;
        end loop;
        bytes <= bytes + s_bytes_i;
      end if;

      if rst_i = '1' then
        bytes <= 0;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;


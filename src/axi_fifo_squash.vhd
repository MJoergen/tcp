library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This is an "elastic" FIFO. It can accept a variable number of bytes in each clock
-- cycle, and will gather together and align the bytes.

entity axi_fifo_squash is
  generic (
    G_DATA_BYTES : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_start_i : in    natural range 0 to G_DATA_BYTES;
    s_end_i   : in    natural range 0 to G_DATA_BYTES;
    s_push_i  : in    std_logic;  -- Force empty of internal buffer

    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_bytes_o : out   natural range 0 to G_DATA_BYTES;
    m_empty_o : out   std_logic
  );
end entity axi_fifo_squash;

architecture synthesis of axi_fifo_squash is

  -- Internal buffer
  signal m_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal m_bytes : natural range 0 to G_DATA_BYTES - 1 := 0;

begin

  -- TBD: This can perhaps be optimized to higher throughput, i.e. by setting s_ready_o to '1' in more situations.
  s_ready_o <= '1' when m_bytes = 0 and m_valid_o = '0' else
               '0';

  m_empty_o <= '1' when m_bytes = 0 else
               '0';

  fsm_proc : process (clk_i)
    variable s_bytes_v     : natural range 0 to G_DATA_BYTES;
    variable shift_v       : integer range -G_DATA_BYTES to G_DATA_BYTES;
    variable shift_bits_v  : natural range 0 to 8 * G_DATA_BYTES;
    variable new_m_bytes_v : natural range 0 to 2 * G_DATA_BYTES - 1;
    variable new_s_begin_v : natural range 0 to 2 * G_DATA_BYTES;
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';

        if m_bytes > 0 then
          -- Forward internal buffer
          m_bytes_o <= m_bytes;
          m_data_o  <= m_data;
          m_bytes   <= 0;
          m_data    <= (others => '0');
        elsif m_valid_o = '1' then
          -- Empty output buffer
          m_bytes_o <= 0;
          m_data_o  <= (others => '0');
        end if;
      end if;

      -- Ignore inputs where start > end
      if s_valid_i = '1' and s_ready_o = '1' and s_start_i <= s_end_i then
        s_bytes_v     := s_end_i - s_start_i;
        shift_v       := m_bytes_o - s_start_i;
        new_m_bytes_v := s_bytes_v + m_bytes_o;  -- Alternatively: s_end_i + shift_v;
        new_s_begin_v := G_DATA_BYTES - shift_v;

        -- Shift right and shift left are handled separately for better portability.
        if shift_v < 0 then
          shift_bits_v := -8 * shift_v;

          for i in 0 to G_DATA_BYTES - 1 loop
            if i >= m_bytes_o and i < new_m_bytes_v then
              m_data_o(8 * i + 7 downto 8 * i) <= s_data_i(8 * i + 7 + shift_bits_v downto 8 * i + shift_bits_v);
            end if;
          end loop;

        else
          shift_bits_v := 8 * shift_v;

          for i in 0 to G_DATA_BYTES - 1 loop
            if i >= m_bytes_o and i < new_m_bytes_v then
              m_data_o(8 * i + 7 downto 8 * i) <= s_data_i(8 * i + 7 - shift_bits_v downto 8 * i - shift_bits_v);
            end if;
          end loop;

        end if;

        if new_m_bytes_v <= G_DATA_BYTES then
          m_bytes_o <= new_m_bytes_v;
          if new_m_bytes_v = G_DATA_BYTES then
            -- Output buffer full always valid
            m_valid_o <= '1';
          end if;
        else
          -- Full output buffer
          m_bytes_o <= G_DATA_BYTES;
          m_valid_o <= '1';

          -- Populate internal buffer
          m_bytes   <= new_m_bytes_v - G_DATA_BYTES;

          for i in 0 to G_DATA_BYTES - 1 loop
            if new_s_begin_v + i < G_DATA_BYTES then
              m_data(8 * i + 7 downto 8 * i) <= s_data_i(8 * i + 7 + 8 * new_s_begin_v downto 8 * i + 8 * new_s_begin_v);
            end if;
          end loop;

        end if;

        if s_push_i = '1' and new_m_bytes_v /= 0 then
          -- Force output, but only if non-empty
          m_valid_o <= '1';
        end if;
      end if;

      if rst_i = '1' then
        m_bytes_o <= 0;
        m_data_o  <= (others => '0');
        m_valid_o <= '0';
        m_bytes   <= 0;
        m_data    <= (others => '0');
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;


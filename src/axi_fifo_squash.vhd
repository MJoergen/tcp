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
    clk_i                : in    std_logic;
    rst_i                : in    std_logic;

    s_ready_o            : out   std_logic;
    s_valid_i            : in    std_logic;
    s_data_i             : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_start_i            : in    natural range 0 to G_DATA_BYTES;
    s_end_i              : in    natural range 0 to G_DATA_BYTES;
    s_push_i             : in    std_logic;  -- Force empty of buffer

    s_bytes_v_o          : out   natural range 0 to G_DATA_BYTES;
    new_shift_v_o        : out   integer range -G_DATA_BYTES to G_DATA_BYTES;
    new_shift_bits_v_o   : out   natural range 0 to 8 * G_DATA_BYTES;
    new_m_bytes_v_o      : out   natural range 0 to 2 * G_DATA_BYTES;
    new_s_begin_v_o      : out   natural range 0 to 2 * G_DATA_BYTES;
    new_s_begin_bits_v_o : out   natural range 0 to 8 * 2 * G_DATA_BYTES;

    m_ready_i            : in    std_logic;
    m_valid_o            : out   std_logic;
    m_data_o             : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_bytes_o            : out   natural range 0 to G_DATA_BYTES;
    m_empty_o            : out   std_logic
  );
end entity axi_fifo_squash;

architecture synthesis of axi_fifo_squash is

  signal m_valid : std_logic;
  signal m_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal m_bytes : natural range 0 to G_DATA_BYTES;

begin

  assert s_start_i <= s_end_i;

  s_ready_o <= (not m_valid) or (m_ready_i or not m_valid_o);

  m_empty_o <= '1' when m_valid = '0' and m_bytes = 0 and (m_bytes_o = 0 or m_valid_o = '1') else
               '0';

  fsm_proc : process (clk_i)
    variable s_bytes_v          : natural range 0 to G_DATA_BYTES;
    variable new_shift_v        : integer range -G_DATA_BYTES to G_DATA_BYTES;
    variable new_shift_bits_v   : natural range 0 to 8 * G_DATA_BYTES;
    variable new_m_bytes_v      : natural range 0 to 2 * G_DATA_BYTES;
    variable new_s_begin_v      : natural range 0 to 2 * G_DATA_BYTES;
    variable new_s_begin_bits_v : natural range 0 to 8 * 2 * G_DATA_BYTES;
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
        m_bytes_o <= m_bytes;
        m_data_o  <= m_data;
        m_valid   <= '0';
        m_bytes   <= 0;
        m_data    <= (others => '0');
        if m_bytes = G_DATA_BYTES then
          m_valid_o <= '1';
        end if;
      end if;

      if s_valid_i = '1' and s_ready_o = '1' then
        s_bytes_v := s_end_i - s_start_i;
        if m_valid_o = '1' and m_ready_i = '1' then
          new_shift_v   := m_bytes - s_start_i;
          new_m_bytes_v := s_bytes_v + m_bytes;                                                                             -- s_end_i + new_shift_v;
        else
          new_shift_v   := m_bytes_o - s_start_i;
          new_m_bytes_v := s_bytes_v + m_bytes_o;                                                                           -- s_end_i + new_shift_v;
        end if;
        new_s_begin_v := G_DATA_BYTES - new_shift_v;

        if new_shift_v < 0 then
          new_shift_bits_v := -8 * new_shift_v;
          for i in 0 to G_DATA_BYTES - 1 loop
            if i >= m_bytes_o and i < new_m_bytes_v then
              m_data_o(8 * i + 7 downto 8 * i) <= s_data_i(8 * i + 7 + new_shift_bits_v downto 8 * i + new_shift_bits_v);
            end if;
          end loop;
        else
          new_shift_bits_v := 8 * new_shift_v;
          for i in 0 to G_DATA_BYTES - 1 loop
            if i >= m_bytes_o and i < new_m_bytes_v then
              m_data_o(8 * i + 7 downto 8 * i) <= s_data_i(8 * i + 7 - new_shift_bits_v downto 8 * i - new_shift_bits_v);
            end if;
          end loop;
        end if;

        if new_m_bytes_v <= G_DATA_BYTES then
          m_bytes_o <= new_m_bytes_v;
          if new_m_bytes_v = G_DATA_BYTES then
            m_valid_o <= '1';
          end if;
        else
          m_bytes_o          <= G_DATA_BYTES;
          m_valid_o          <= '1';
          m_bytes            <= new_m_bytes_v - G_DATA_BYTES;
          new_s_begin_bits_v := 8 * new_s_begin_v;
          for i in 0 to G_DATA_BYTES - 1 loop
            if new_s_begin_v + i < G_DATA_BYTES then
              m_data(8 * i + 7 downto 8 * i) <= s_data_i(8 * i + 7 + new_s_begin_bits_v downto 8 * i + new_s_begin_bits_v);
            end if;
          end loop;
          m_valid <= '1';
        end if;

        if s_push_i = '1' and new_m_bytes_v /= 0 then
          m_valid_o <= '1';
        end if;
      end if;

      if rst_i = '1' then
        m_bytes_o <= 0;
        m_data_o  <= (others => '0');
        m_valid_o <= '0';
        m_bytes   <= 0;
        m_data    <= (others => '0');
        m_valid   <= '0';
      end if;
    end if;

    s_bytes_v_o          <= s_bytes_v;
    new_shift_v_o        <= new_shift_v;
    new_shift_bits_v_o   <= new_shift_bits_v;
    new_m_bytes_v_o      <= new_m_bytes_v;
    new_s_begin_v_o      <= new_s_begin_v;
    new_s_begin_bits_v_o <= new_s_begin_bits_v;
  end process fsm_proc;

end architecture synthesis;


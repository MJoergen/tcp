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
-- If m_bytes_i > m_bytes_o then only m_bytes_o bytes are actually read.
--
-- Synthesis report with G_S_DATA_BYTES = 8 and G_M_DATA_BYTES = 4:
--   LUTs      : 210
--   Registers : 107
--
-- Synthesis report with G_S_DATA_BYTES = 4 and G_M_DATA_BYTES = 8:
--   LUTs      : 203
--   Registers :  68

entity axi_fifo_wide is
  generic (
    G_S_DATA_BYTES : natural;
    G_M_DATA_BYTES : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_S_DATA_BYTES * 8 - 1 downto 0);
    s_bytes_i : in    natural range 0 to G_S_DATA_BYTES;

    m_ready_i : in    std_logic;
    m_bytes_i : in    natural range 0 to G_M_DATA_BYTES;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_M_DATA_BYTES * 8 - 1 downto 0);
    m_bytes_o : out   natural range 0 to G_M_DATA_BYTES
  );
end entity axi_fifo_wide;

architecture synthesis of axi_fifo_wide is

  constant C_DEBUG : boolean := false;

  signal   s_data  : std_logic_vector(G_S_DATA_BYTES * 8 - 1 downto 0);
  signal   s_start : natural range 0 to G_S_DATA_BYTES;
  signal   s_end   : natural range 0 to G_S_DATA_BYTES;

  signal   m_data  : std_logic_vector(G_M_DATA_BYTES * 8 - 1 downto 0);
  signal   m_bytes : natural range 0 to G_M_DATA_BYTES;

  pure function copy_data (
    dst_data : std_logic_vector;
    src_data : std_logic_vector;
    dst_ptr  : natural range 0 to G_M_DATA_BYTES;
    src_ptr  : natural range 0 to G_S_DATA_BYTES
  ) return std_logic_vector is
    variable res_v   : std_logic_vector(dst_data'range);
    variable shift_v : natural range 0 to maximum(G_S_DATA_BYTES, G_M_DATA_BYTES);
  begin
    if C_DEBUG then
      report "copy_data: dst_ptr=" & to_string(dst_ptr) &
             ", src_ptr=" & to_string(src_ptr);
    end if;
    res_v := dst_data;
    if src_ptr >= dst_ptr then
      -- Shift right
      shift_v := src_ptr - dst_ptr;

      for i in 0 to G_M_DATA_BYTES - 1 loop
        if i >= dst_ptr and i + shift_v < G_S_DATA_BYTES then
          res_v(8 * i + 7 downto 8 * i) := src_data(8 * i + 7 + 8 * shift_v downto 8 * i + 8 * shift_v);
        end if;
      end loop;
    else
      -- Shift left
      shift_v := dst_ptr - src_ptr;

      for i in 0 to G_M_DATA_BYTES - 1 loop
        if i >= dst_ptr and i - shift_v < G_S_DATA_BYTES then
          res_v(8 * i + 7 downto 8 * i) := src_data(8 * i + 7 - 8 * shift_v downto 8 * i - 8 * shift_v);
        end if;
      end loop;
    end if;

    return res_v;
  end function copy_data;

begin

  s_ready_o <= '1' when m_bytes + s_bytes_i <= maximum(G_S_DATA_BYTES, G_M_DATA_BYTES) and
                        (m_valid_o = '0' or (m_ready_i = '0' and s_start = s_end)) else
               '0';

  m_valid_o <= '1' when m_bytes > 0 else
               '0';
  m_bytes_o <= m_bytes;
  m_data_o  <= m_data;

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_valid_o = '1' and m_ready_i = '1' then
        -- M : |.|.|.|M|M|M|1|0|
        -- M : |.|.|.|.|.|M|M|M|
        --
        -- Shift right
        if m_bytes_i >= m_bytes then
          m_bytes <= 0;

          if s_start < s_end and G_S_DATA_BYTES > G_M_DATA_BYTES then
            -- S : |.|.|.|4|3|2|1|0|
            -- M :         |.|.|.|M|

            -- Shift left
            m_data <= copy_data(m_data, s_data, 0, s_start);
            if s_end - s_start >= G_M_DATA_BYTES then
              m_bytes <= G_M_DATA_BYTES;
              s_start <= s_start + G_M_DATA_BYTES;
            else
              m_bytes <= s_end - s_start;
              s_start <= s_end;
            end if;
          end if;
        else
          m_data  <= std_logic_vector(shift_right(unsigned(m_data), 8 * m_bytes_i));
          m_bytes <= m_bytes - m_bytes_i;
        end if;
      elsif s_valid_i = '1' and s_ready_o = '1' and s_bytes_i > 0 then
        if G_S_DATA_BYTES > G_M_DATA_BYTES then
          if m_bytes + s_bytes_i <= G_M_DATA_BYTES then
            -- S : |.|.|.|.|.|2|1|0|
            -- M :         |.|.|.|M|

            -- Shift left
            m_data  <= copy_data(m_data, s_data_i, m_bytes, 0);
            m_bytes <= m_bytes + s_bytes_i;
          else
            -- S : |.|.|.|4|3|2|1|0|
            -- M :         |.|.|.|M|

            s_data  <= s_data_i;
            s_start <= G_M_DATA_BYTES - m_bytes;
            s_end   <= s_bytes_i;

            -- Shift left
            m_data  <= copy_data(m_data, s_data_i, m_bytes, 0);
            m_bytes <= G_M_DATA_BYTES;
          end if;
        else
          -- S :         |.|2|1|0|
          -- M : |.|.|.|.|.|.|M|M|
          --
          -- Shift left
          m_data  <= copy_data(m_data, s_data_i, m_bytes, 0);
          m_bytes <= m_bytes + s_bytes_i;
        end if;
      end if;

      if rst_i = '1' then
        s_start <= 0;
        s_end   <= 0;
        m_bytes <= 0;
        m_data  <= (others => '0');
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;


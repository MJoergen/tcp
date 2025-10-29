library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This is an "elastic" pipeline. It accepts any number of bytes in each clock cycle.
-- And you can read out any number of bytes in each clock cycle.
--
-- The output m_bytes_o shows the number of bytes actually available.
--
-- Specifically, set m_bytes_i to the number of bytes you wish to read. Sampled when
-- m_ready_i is 1.
--
-- The actual number of bytes transferred is the minimum of m_bytes_i and m_bytes_o.
--
-- Synth report with G_S_DATA_BYTES = 8 and G_M_DATA_BYTES = 4:
--   LUTs      : 216
--   Registers : 109
--
-- Synth report with G_S_DATA_BYTES = 4 and G_M_DATA_BYTES = 8:
--   LUTs      : 174
--   Registers :  69
--
-- A frequency of 250 MHz closes timing.

entity axi_pipe_wide is
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
    s_start_i : in    natural range 0 to G_S_DATA_BYTES-1;
    s_end_i   : in    natural range 0 to G_S_DATA_BYTES;
    s_last_i  : in    std_logic;

    m_ready_i : in    std_logic;
    m_bytes_i : in    natural range 0 to G_M_DATA_BYTES;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_M_DATA_BYTES * 8 - 1 downto 0);
    m_bytes_o : out   natural range 0 to G_M_DATA_BYTES;
    m_last_o  : out   std_logic
  );
end entity axi_pipe_wide;

architecture synthesis of axi_pipe_wide is

  constant C_DEBUG : boolean := false;

  -- Input buffer
  signal   s_data  : std_logic_vector(G_S_DATA_BYTES * 8 - 1 downto 0);
  signal   s_start : natural range 0 to G_S_DATA_BYTES;
  signal   s_end   : natural range 0 to G_S_DATA_BYTES;
  signal   s_last  : std_logic;

  -- Internal buffer
  signal   m_data  : std_logic_vector(G_M_DATA_BYTES * 8 - 1 downto 0);
  signal   m_bytes : natural range 0 to G_M_DATA_BYTES;
  signal   m_last  : std_logic;

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

    -- Shift left and shift right are handled separately for better synthesis portability.
    if src_ptr >= dst_ptr then
      -- Shift right:
      -- Input  :  |.|3|2|1|0|.|.|.|
      -- Output :          |.|.|M|M|
      shift_v := src_ptr - dst_ptr;

      for i in 0 to G_M_DATA_BYTES - 1 loop
        if i >= dst_ptr and i + shift_v < G_S_DATA_BYTES then
          res_v(8 * i + 7 downto 8 * i) := src_data(8 * i + 7 + 8 * shift_v downto 8 * i + 8 * shift_v);
        end if;
      end loop;
    else
      -- Shift left:
      -- Input  :  |.|5|4|3|2|1|0|.|
      -- Output :          |.|.|M|M|
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

  -- TBD: This can perhaps be optimized to higher throughput, by setting s_ready_o to '1' in (specific) situations where
  -- m_ready_i = '1'.
  s_ready_o <= '1' when m_bytes + (s_end_i - s_start_i) <= maximum(G_S_DATA_BYTES, G_M_DATA_BYTES) and
                        (m_valid_o = '0' or (m_ready_i = '0' and s_start = s_end)) and
                        m_last = '0' else
               '0';

  m_valid_o <= '1' when m_bytes > 0 else
               '0';
  m_bytes_o <= m_bytes;
  m_data_o  <= m_data;
  m_last_o  <= m_last when m_bytes_o <= m_bytes_i else
               '0';

  fsm_proc : process (clk_i)
    variable s_bytes_v : natural range 0 to G_S_DATA_BYTES;
  begin
    if rising_edge(clk_i) then
      if m_valid_o = '1' and m_ready_i = '1' then
        if m_bytes_i >= m_bytes then
          m_bytes <= 0;
          m_last  <= '0';

          if G_S_DATA_BYTES > G_M_DATA_BYTES and s_start < s_end then
            s_bytes_v := s_end - s_start;
            if C_DEBUG then
              report "READY: Input buffer contains " & to_string(s_bytes_v) & " bytes";
            end if;
            -- S : |.|.|.|2|1|0|.|.|
            -- M : |.|.|.|.|.|.|.|.|
            --
            -- Shift right
            -- Copy remaining data to internal buffer
            m_data <= copy_data(m_data, s_data, 0, s_start);

            if s_end - s_start < G_M_DATA_BYTES then
              m_bytes <= s_end - s_start;
              s_start <= s_end;
            else
              if C_DEBUG then
                report "Internal buffer is now filled";
              end if;
              m_bytes <= G_M_DATA_BYTES;
              s_start <= s_start + G_M_DATA_BYTES;
            end if;

            if s_end - s_start <= G_M_DATA_BYTES then
              m_last <= s_last;
            end if;
          end if;
        else
          m_data  <= std_logic_vector(shift_right(unsigned(m_data), 8 * m_bytes_i));
          m_bytes <= m_bytes - m_bytes_i;
        end if;
      elsif s_valid_i = '1' and s_ready_o = '1' and s_start_i < s_end_i then
        -- Number of input bytes consumed
        s_bytes_v := s_end_i - s_start_i;

        if C_DEBUG then
          report "VALID: m_bytes_o=" & to_string(m_bytes_o) &
                 ", s_bytes_v=" & to_string(s_bytes_v);
        end if;

        if G_S_DATA_BYTES > G_M_DATA_BYTES then
          if m_bytes + s_bytes_v <= G_M_DATA_BYTES then
            -- S : |.|.|.|.|.|1|0|.|
            -- M :         |.|.|M|M|

            -- Shift left
            m_data  <= copy_data(m_data, s_data_i, m_bytes, s_start_i);
            m_bytes <= m_bytes + s_bytes_v;
            m_last  <= s_last_i;
          else
            -- S : |.|.|.|.|2|1|0|.|
            -- M :         |.|M|M|M|

            s_data  <= s_data_i;
            s_start <= G_M_DATA_BYTES - m_bytes + s_start_i;
            s_end   <= s_end_i;
            s_last  <= s_last_i;

            -- Shift left
            m_data  <= copy_data(m_data, s_data_i, m_bytes, s_start_i);
            m_bytes <= G_M_DATA_BYTES;
          end if;
        else
          -- S :         |2|1|0|.|
          -- M : |.|.|.|.|.|.|M|M|
          --
          -- Shift left
          m_data  <= copy_data(m_data, s_data_i, m_bytes, s_start_i);
          m_bytes <= m_bytes + s_bytes_v;
          m_last  <= s_last_i;
        end if;
      end if;

      if rst_i = '1' then
        m_bytes <= 0;
        m_data  <= (others => '0');
        m_last  <= '0';
        s_start <= 0;
        s_end   <= 0;
        s_last  <= '0';
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;


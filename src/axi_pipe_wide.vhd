library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This is an "elastic" pipeline. It accepts any number of bytes in each clock cycle.
-- And you can read out any number of bytes in each clock cycle.
--
-- Specifically, set m_bytes_i to the number of bytes you wish to read. Sampled when
-- m_ready_i is 1.
--
-- The actual number of bytes transferred is the minimum of m_bytes_i and m_bytes_o.
--
-- m_valid_o is high when m_bytes_o > 0.
-- m_bytes_o may increase even when m_valid_o is high.
-- m_last_o  is only asserted when all bytes are requested (i.e. m_bytes_i >= m_bytes_o).
--
-- s_ready_o depends combinatorially on s_start_i and s_end_i.
--
-- Synth report with G_S_DATA_BYTES = 8 and G_M_DATA_BYTES = 4:
--   LUTs      : 307
--   Registers : 109
--
-- Synth report with G_S_DATA_BYTES = 4 and G_M_DATA_BYTES = 8:
--   LUTs      : 299
--   Registers :  73
--
-- A frequency of 200 MHz closes timing.

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
    s_start_i : in    natural range 0 to G_S_DATA_BYTES - 1;
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

  -- Input buffer (only used when G_S_DATA_BYTES > G_M_DATA_BYTES).
  signal s_data  : std_logic_vector(G_S_DATA_BYTES * 8 - 1 downto 0);
  signal s_start : natural range 0 to G_S_DATA_BYTES;
  signal s_end   : natural range 0 to G_S_DATA_BYTES;
  signal s_last  : std_logic;

  -- Output buffer
  signal m_data  : std_logic_vector(G_M_DATA_BYTES * 8 - 1 downto 0);
  signal m_bytes : natural range 0 to G_M_DATA_BYTES;
  signal m_last  : std_logic;

  pure function copy_data (
    dst_data : std_logic_vector;
    src_data : std_logic_vector;
    dst_ptr  : natural range 0 to G_M_DATA_BYTES;
    src_ptr  : natural range 0 to G_S_DATA_BYTES
  ) return std_logic_vector is
    variable res_v         : std_logic_vector(dst_data'range);
    variable shift_right_v : natural range 0 to G_S_DATA_BYTES;
    variable shift_left_v  : natural range 0 to G_M_DATA_BYTES;
  begin
    res_v := dst_data;

    -- Shift left and shift right are handled separately for better synthesis portability.
    if src_ptr >= dst_ptr then
      -- Shift right:
      -- Input  :  |.|3|2|1|0|.|.|.|
      -- Output :          |.|.|M|M|
      shift_right_v := src_ptr - dst_ptr;

      for i in 0 to G_M_DATA_BYTES - 1 loop
        if i >= dst_ptr and i + shift_right_v < G_S_DATA_BYTES then
          res_v(8 * i + 7 downto 8 * i) := src_data(8 * i + 7 + 8 * shift_right_v downto 8 * i + 8 * shift_right_v);
        end if;
      end loop;
    else
      -- Shift left:
      -- Input  :  |.|5|4|3|2|1|0|.|
      -- Output :          |.|.|M|M|
      shift_left_v := dst_ptr - src_ptr;

      for i in 0 to G_M_DATA_BYTES - 1 loop
        if i >= dst_ptr and i - shift_left_v < G_S_DATA_BYTES then
          res_v(8 * i + 7 downto 8 * i) := src_data(8 * i + 7 - 8 * shift_left_v downto 8 * i - 8 * shift_left_v);
        end if;
      end loop;
    end if;

    return res_v;
  end function copy_data;

  signal copy_dst_data : std_logic_vector(G_M_DATA_BYTES * 8 - 1 downto 0);
  signal copy_src_data : std_logic_vector(G_S_DATA_BYTES * 8 - 1 downto 0);
  signal copy_dst_ptr  : natural range 0 to G_M_DATA_BYTES;
  signal copy_src_ptr  : natural range 0 to G_S_DATA_BYTES;

begin

  -- TBD: This can perhaps be optimized to higher throughput, by setting s_ready_o to '1' in
  -- (specific) situations where m_ready_i = '1'.
  s_ready_o     <= '1' when m_bytes + (s_end_i - s_start_i) <= maximum(G_S_DATA_BYTES, G_M_DATA_BYTES) and
                            (m_valid_o = '0' or (m_ready_i = '0' and s_start = s_end)) and
                            m_last = '0' else
                   '0';

  m_valid_o     <= '1' when m_bytes > 0 else
                   '0';
  m_bytes_o     <= m_bytes;
  m_data_o      <= m_data;
  m_last_o      <= m_last when m_bytes_o <= m_bytes_i else
                   '0';

  -- This is a synthesis optimization to ensure copy_data is only instantiated once. This
  -- function contains a barrel shifter and therefore consumes a lot of logic.
  copy_proc : process (all)
  begin
    if s_valid_i = '1' and s_ready_o = '1' then
      copy_src_data <= s_data_i;
      copy_src_ptr  <= s_start_i;
      copy_dst_ptr  <= m_bytes;
    else
      copy_src_data <= s_data;
      copy_src_ptr  <= s_start;
      copy_dst_ptr  <= 0;
    end if;
    copy_dst_data <= copy_data(m_data, copy_src_data, copy_dst_ptr, copy_src_ptr);
  end process copy_proc;

  fsm_proc : process (clk_i)
    variable s_bytes_v : natural range 0 to G_S_DATA_BYTES;
  begin
    if rising_edge(clk_i) then
      if m_valid_o = '1' and m_ready_i = '1' then
        if m_bytes_i >= m_bytes then
          -- Output buffer is fully consumed
          m_bytes <= 0;
          m_last  <= '0';

          -- synthesis translate_off
          m_data  <= (others => '0');
          -- synthesis translate_on

          f_assert_1 : assert s_start <= s_end or rst_i = '1';

          if G_S_DATA_BYTES > G_M_DATA_BYTES and s_start < s_end then
            -- Copy from input buffer
            s_bytes_v := s_end - s_start;
            -- Output buffer is empty at this point.
            -- S : |.|.|.|2|1|0|.|.|
            -- M : |.|.|.|.|.|.|.|.|
            --
            -- Shift right
            -- Copy remaining data to output buffer
            m_data    <= copy_dst_data;

            -- Can all data fit in output buffer?
            if s_bytes_v <= G_M_DATA_BYTES then
              -- Populate output buffer
              m_bytes <= s_bytes_v;
              m_last  <= s_last;
              -- Input buffer is fully consumed
              s_start <= s_end;
            else
              -- Output buffer is now completely filled
              m_bytes <= G_M_DATA_BYTES;

              -- Consume G_M_DATA_BYTES from input buffer.
              s_start <= s_start + G_M_DATA_BYTES;
            end if;
          end if;
        else
          -- Output buffer is partially consumed
          m_data  <= std_logic_vector(shift_right(unsigned(m_data), 8 * m_bytes_i));
          m_bytes <= m_bytes - m_bytes_i;
        end if;
      elsif s_valid_i = '1' and s_ready_o = '1' and s_start_i < s_end_i then
        -- Copy input data to Output buffer
        m_data    <= copy_dst_data;

        -- Number of input bytes consumed
        s_bytes_v := s_end_i - s_start_i;

        if G_S_DATA_BYTES > G_M_DATA_BYTES and m_bytes + s_bytes_v > G_M_DATA_BYTES then
          m_bytes <= G_M_DATA_BYTES;

          -- Copy input to Input buffer as well.
          s_data  <= s_data_i;
          s_start <= s_start_i + G_M_DATA_BYTES - m_bytes;
          s_end   <= s_end_i;
          s_last  <= s_last_i;
        else
          -- Entire input can fit inside Output buffer.
          m_bytes <= m_bytes + s_bytes_v;
          m_last  <= s_last_i;
        end if;
      end if;

      if rst_i = '1' then
        m_bytes <= 0;
        m_last  <= '0';
        s_start <= 0;
        s_end   <= 0;
        s_last  <= '0';

        -- synthesis translate_off
        m_data  <= (others => '0');
        s_data  <= (others => '0');
        -- synthesis translate_on

      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;


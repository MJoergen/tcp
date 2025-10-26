library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This is an "elastic" FIFO. It can accept a variable number of bytes in each clock
-- cycle, and will gather together and align the bytes.
--
-- Synthesis report with G_S_DATA_BYTES = 8 and G_M_DATA_BYTES = 4:
--   LUTs      : 348
--   Registers : 132
--
-- Synthesis report with G_S_DATA_BYTES = 4 and G_M_DATA_BYTES = 8:
--   LUTs      : 246
--   Registers : 104
--
-- Maximum frequency is 250 MHz.

entity axi_fifo_squash is
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
    s_push_i  : in    std_logic;  -- Force empty of internal buffer

    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_M_DATA_BYTES * 8 - 1 downto 0);
    m_bytes_o : out   natural range 0 to G_M_DATA_BYTES := 0;
    m_empty_o : out   std_logic
  );
end entity axi_fifo_squash;

architecture synthesis of axi_fifo_squash is

  constant C_DEBUG : boolean                           := false;

  -- Input buffer
  signal   s_data  : std_logic_vector(G_S_DATA_BYTES * 8 - 1 downto 0);
  signal   s_start : natural range 0 to G_S_DATA_BYTES;
  signal   s_end   : natural range 0 to G_S_DATA_BYTES;

  -- Internal buffer
  signal   m_data  : std_logic_vector(G_M_DATA_BYTES * 8 - 1 downto 0);
  signal   m_bytes : natural range 0 to G_M_DATA_BYTES := 0;

  pure function copy_data (
    dst_data : std_logic_vector;
    src_data : std_logic_vector;
    dst_ptr  : natural range 0 to G_M_DATA_BYTES - 1;
    src_ptr  : natural range 0 to G_S_DATA_BYTES - 1
  ) return std_logic_vector is
    variable res_v         : std_logic_vector(dst_data'range);
    variable shift_v       : integer range -G_S_DATA_BYTES to G_M_DATA_BYTES - 1;
    variable shift_left_v  : natural range 0 to G_M_DATA_BYTES - 1;
    variable shift_right_v : natural range 0 to G_S_DATA_BYTES;
  begin
    if C_DEBUG then
      report "copy_data: dst_ptr=" & to_string(dst_ptr) &
             ", src_ptr=" & to_string(src_ptr);
    end if;
    res_v   := dst_data;
    shift_v := dst_ptr - src_ptr;

    -- Shift left and shift right are handled separately for better synthesis portability.
    if shift_v > 0 then
      -- Shift left:
      -- Input  :  |.|5|4|3|2|1|0|.|
      -- Output :          |.|.|M|M|
      shift_left_v := shift_v;

      f_assert_0 : assert shift_left_v <= dst_ptr;

      for i in 0 to G_M_DATA_BYTES - 1 loop
        if i >= dst_ptr and i >= shift_left_v and i - shift_left_v < G_S_DATA_BYTES then
          res_v(8 * i + 7 downto 8 * i) := src_data(8 * i + 7 - 8 * shift_left_v downto 8 * i - 8 * shift_left_v);
        end if;
      end loop;

    else
      -- Shift right:
      -- Input  :  |.|3|2|1|0|.|.|.|
      -- Output :          |.|.|M|M|
      shift_right_v := -shift_v;

      for i in 0 to G_M_DATA_BYTES - 1 loop
        if i >= dst_ptr and i + shift_right_v < G_S_DATA_BYTES then
          res_v(8 * i + 7 downto 8 * i) := src_data(8 * i + 7 + 8 * shift_right_v downto 8 * i + 8 * shift_right_v);
        end if;
      end loop;

    end if;
    return res_v;
  end function copy_data;

begin

  -- TBD: This can perhaps be optimized to higher throughput, by setting s_ready_o to '1' in (specific) situations where
  -- m_ready_i = '1'.
  s_ready_o <= '1' when m_bytes = 0 and m_valid_o = '0' and s_start = s_end else
               '0';

  m_empty_o <= '1' when m_bytes = 0 else
               '0';

  fsm_proc : process (clk_i)
    variable s_bytes_v        : natural range 0 to G_S_DATA_BYTES;
    variable new_m_bytes_v    : natural range 0 to G_S_DATA_BYTES + G_M_DATA_BYTES;
    variable bytes_consumed_v : natural range 0 to G_M_DATA_BYTES;
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        -- Output buffer is consumed.
        m_valid_o <= '0';

        -- Do we have data in internal buffer?
        if m_bytes > 0 then
          if C_DEBUG then
            report "READY: Internal buffer contains " & to_string(m_bytes);
          end if;
          -- Forward internal buffer
          m_bytes_o <= m_bytes;
          m_data_o  <= m_data;
          if m_bytes = G_M_DATA_BYTES then
            m_valid_o <= '1';
          end if;
          m_bytes <= 0;
          m_data  <= (others => '0');

          f_assert_7 : assert s_start <= s_end;

          -- Do we have data in input buffer?
          if G_S_DATA_BYTES > G_M_DATA_BYTES + 1 and s_start < s_end then
            s_bytes_v := s_end - s_start;
            if C_DEBUG then
              report "READY: Input buffer contains " & to_string(s_bytes_v) & " bytes";
            end if;

            -- Copy remaining data to internal buffer
            m_data <= copy_data(m_data, s_data, 0, s_start);

            -- Can all data fit in internal buffer?
            if s_bytes_v <= G_M_DATA_BYTES then
              if C_DEBUG then
                report "Internal buffer filled with " & to_string(s_bytes_v) & " bytes";
              end if;
              -- Populate internal buffer
              m_bytes <= s_bytes_v;
              -- Entire input is consumed
              s_start <= s_end;
            else
              if C_DEBUG then
                report "Internal buffer is now filled";
              end if;
              m_bytes <= G_M_DATA_BYTES;
              f_assert_1 : assert s_start + G_M_DATA_BYTES <= s_end;
              s_start <= s_start + G_M_DATA_BYTES;
            end if;
          end if;
        elsif m_valid_o = '1' then
          -- Empty output buffer
          m_bytes_o <= 0;
          m_data_o  <= (others => '0');
        end if;
      end if;

      -- Only accept inputs where start <= end
      if s_valid_i = '1' and s_ready_o = '1' and s_start_i <= s_end_i then
        -- Note: The following two asserts are because s_ready_o = '1'.
        --       If we optimize and set s_ready_o to '1' in more situations, these
        --       assertions will need to be revisited.

        -- Input buffer is empty
        f_assert_2 : assert s_start = s_end;
        -- Internal buffer is empty
        f_assert_3 : assert m_bytes = 0;

        -- Store input for later. Only relevant if G_S_DATA_BYTES > G_M_DATA_BYTES.
        s_data    <= s_data_i;
        s_start   <= s_start_i;
        s_end     <= s_end_i;

        -- Number of input bytes consumed
        s_bytes_v := s_end_i - s_start_i;

        if C_DEBUG then
          report "VALID: m_bytes_o=" & to_string(m_bytes_o) &
                 ", s_bytes_v=" & to_string(s_bytes_v);
        end if;

        -- Copy data to output buffer
        m_data_o      <= copy_data(m_data_o, s_data_i, m_bytes_o, s_start_i);

        -- Proposed new byte pointer in output buffer
        new_m_bytes_v := m_bytes_o + s_bytes_v;

        -- Can all data fit in output buffer?
        if new_m_bytes_v <= G_M_DATA_BYTES then
          if C_DEBUG then
            report "Output buffer filled with " & to_string(new_m_bytes_v) &
                   " bytes. Internal buffer is emptied";
          end if;
          m_bytes_o <= new_m_bytes_v;
          -- Entire input is consumed
          s_start   <= s_end_i;
          -- Is output buffer completely full?
          if new_m_bytes_v = G_M_DATA_BYTES then
            m_valid_o <= '1';
          end if;
        else
          -- Output buffer is full
          if C_DEBUG then
            report "Output buffer is filled";
          end if;
          m_bytes_o        <= G_M_DATA_BYTES;
          m_valid_o        <= '1';

          -- Record bytes consumed in output buffer
          bytes_consumed_v := G_M_DATA_BYTES - m_bytes_o;
          s_start          <= s_start_i + bytes_consumed_v;

          -- Copy remaining data to internal buffer
          m_data        <= copy_data(m_data, s_data_i, 0, s_start_i + bytes_consumed_v);

          -- Proposed new byte pointer in internal buffer
          new_m_bytes_v := s_bytes_v - bytes_consumed_v;

          -- Can all data fit in internal buffer?
          if new_m_bytes_v <= G_M_DATA_BYTES then
            if C_DEBUG then
              report "Internal buffer filled with " & to_string(new_m_bytes_v) & " bytes";
            end if;
            -- Populate internal buffer
            m_bytes <= new_m_bytes_v;
            -- Entire input is consumed
            s_start <= s_end_i;
          else
            if C_DEBUG then
              report "Internal buffer is now full";
            end if;
            m_bytes <= G_M_DATA_BYTES;
            s_start <= s_start_i + bytes_consumed_v + G_M_DATA_BYTES;
          end if;
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
        s_start   <= 0;
        s_end     <= 0;
        s_data    <= (others => '0');
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;


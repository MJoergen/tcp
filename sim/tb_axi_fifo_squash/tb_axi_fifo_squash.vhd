library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axi_fifo_squash is
  generic (
    G_FAST       : boolean;
    G_SHOW_TESTS : boolean;
    G_SHOW_DATA  : boolean
  );
end entity tb_axi_fifo_squash;

architecture simulation of tb_axi_fifo_squash is

  constant C_DATA_BYTES : natural := 8;

  signal   clk     : std_logic    := '1';
  signal   rst     : std_logic    := '1';
  signal   running : std_logic    := '1';

  signal   s_ready : std_logic;
  signal   s_valid : std_logic;
  signal   s_data  : std_logic_vector(C_DATA_BYTES * 8 - 1 downto 0);
  signal   s_start : natural range 0 to C_DATA_BYTES;
  signal   s_end   : natural range 0 to C_DATA_BYTES;
  signal   s_push  : std_logic;

  signal   m_ready : std_logic;
  signal   m_valid : std_logic;
  signal   m_data  : std_logic_vector(C_DATA_BYTES * 8 - 1 downto 0);
  signal   m_bytes : natural range 0 to C_DATA_BYTES;
  signal   m_empty : std_logic;

begin

  -------------------------------------
  -- Clock and reset
  -------------------------------------

  clk <= running and not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  -------------------------------------
  -- Test procedure
  -------------------------------------

  test_proc : process
    --

    procedure send (
      tb_arg   : std_logic_vector;
      tb_start : natural;
      tb_end   : natural;
      tb_push  : std_logic
    ) is
      variable arg_v : std_logic_vector(tb_arg'high downto tb_arg'low);
    begin
      -- This is a VHDL trick necessary to convert from a rising range to a falling range.
      arg_v := tb_arg;
      if G_SHOW_DATA then
        if tb_end = tb_start then
          if tb_push = '1' then
            report "  Sending: PUSH";
          else
            report "  Sending: no data";
          end if;
        else
          if tb_push = '1' then
            report "  Sending: " & to_hstring(arg_v(tb_end * 8 - 1 downto tb_start * 8)) & " PUSH";
          else
            report "  Sending: " & to_hstring(arg_v(tb_end * 8 - 1 downto tb_start * 8));
          end if;
        end if;
      end if;

      s_data(arg_v'range) <= arg_v;
      s_start             <= tb_start;
      s_end               <= tb_end;
      s_push              <= tb_push;
      s_valid             <= '1';
      wait until rising_edge(clk);

      assert s_ready = '1'
        report "FAIL: Tx buffer not ready";

      s_data              <= (others => '0');
      s_start             <= 0;
      s_end               <= 0;
      s_push              <= '0';
      s_valid             <= '0';
      if not G_FAST then
        wait until rising_edge(clk);
      else
        wait for 1 ns;
      end if;
    end procedure send;

    procedure verify (
      arg : std_logic_vector
    ) is
      variable exp_v : std_logic_vector(arg'high downto arg'low);
    begin
      -- This is a VHDL trick necessary to convert from a rising range to a falling range.
      exp_v   := arg;

      m_ready <= '1';

      assert m_valid = '1'
        report "Verify FAIL: m_valid not set";

      assert m_bytes = exp_v'length / 8
        report "Verify FAIL length: " &
               "Received " & to_string(m_bytes) & " bytes." &
               " Expected " & to_string(exp_v'length / 8) & " bytes.";

      assert m_data(exp_v'range) = arg
        report "Verify FAIL data: " &
               "Received " & to_hstring(m_data(exp_v'range)) &
               ", expected " & to_hstring(arg);

      if G_SHOW_DATA then
        report "  Received " & to_hstring(m_data(m_bytes * 8 - 1 downto 0));
      end if;

      wait until rising_edge(clk);
      m_ready <= '0';
      if not G_FAST then
        wait until rising_edge(clk);
      else
        wait for 1 ns;
      end if;
    end procedure verify;

  begin
    s_valid <= '0';
    s_data  <= (others => '0');
    s_start <= 0;
    s_end   <= 0;
    s_push  <= '0';
    m_ready <= '0';
    wait until rst = '0';
    wait for 100 ns;
    wait until rising_edge(clk);

    report "Test started";

    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";


    if not G_FAST then
      wait until rising_edge(clk);
    end if;
    if G_SHOW_TESTS then
      report "Test 1: PUSH first write";
    end if;
    send(X"554433221100", 1, 3, '1');
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer contains 2211
    assert m_valid = '1'
      report "m_valid not 1";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    verify(X"2211");
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";


    if not G_FAST then
      wait until rising_edge(clk);
    end if;
    if G_SHOW_TESTS then
      report "Test 2: Full word without PUSH";
    end if;
    send(X"7766554433221100", 0, 8, '0');
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer contains 7766554433221100
    assert m_valid = '1'
      report "m_valid not 1";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    verify(X"7766554433221100");
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";


    if not G_FAST then
      wait until rising_edge(clk);
    end if;
    if G_SHOW_TESTS then
      report "Test 3: PUSH on second write";
    end if;
    send(X"554433221100", 1, 3, '0');
    -- Internal buffer now contains 2211
    assert m_empty = '0'
      report "m_empty not 0";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    send(X"554433221100", 2, 4, '1');
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer contains 33222211
    assert m_valid = '1'
      report "m_valid not 1";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    verify(X"33222211");
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";


    if not G_FAST then
      wait until rising_edge(clk);
    end if;
    if G_SHOW_TESTS then
      report "Test 4: Wrap around without PUSH";
    end if;
    send(X"554433221100", 0, 6, '0');
    -- Internal buffer now contains 554433221100
    assert m_empty = '0'
      report "m_empty not 0";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    send(X"554433221100", 3, 6, '0');
    -- Internal buffer now contains 55
    assert m_empty = '0'
      report "m_empty not 0";
    -- Output buffer contains 4433554433221100
    assert m_valid = '1'
      report "m_valid not 1";
    -- Input buffer is blocked
    assert s_ready = '0'
      report "s_ready not 0";

    verify(X"4433554433221100");
    -- Internal buffer is empty
    assert m_empty = '0'
      report "m_empty not 0";
    -- Output buffer contains 55
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    send(X"221100", 0, 3, '1');
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer contains 22110055
    assert m_valid = '1'
      report "m_valid not 1";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    verify(X"22110055");
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";


    if not G_FAST then
      wait until rising_edge(clk);
    end if;
    if G_SHOW_TESTS then
      report "Test 5: Wrap around whole multiple of word";
    end if;
    send(X"554433221100", 0, 5, '0');
    -- Internal buffer now contains 4433221100
    assert m_empty = '0'
      report "m_empty not 0";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    send(X"554433221100", 3, 6, '0');
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer contains 5544334433221100
    assert m_valid = '1'
      report "m_valid not 1";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    verify(X"5544334433221100");
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";


    if not G_FAST then
      wait until rising_edge(clk);
    end if;
    if G_SHOW_TESTS then
      report "Test 6: Wrap around backwards";
    end if;
    send(X"5544332211", 0, 1, '0');
    -- Internal buffer now contains 11
    assert m_empty = '0'
      report "m_empty not 0";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    send(X"554433221100", 3, 6, '1');
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer contains 55443311
    assert m_valid = '1'
      report "m_valid not 1";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    verify(X"55443311");
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";


    if not G_FAST then
      wait until rising_edge(clk);
    end if;
    if G_SHOW_TESTS then
      report "Test 7: Wrap around whole multiple of word with PUSH first";
    end if;
    send(X"7766554433221100", 0, 8, '1');
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 0";
    -- Output buffer contains 7766554433221100
    assert m_valid = '1'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    send(X"FFEEDDCCBBAA9988", 0, 8, '0');
    -- Internal buffer contains FFEEDDCCBBAA9988
    assert m_empty = '0'
      report "m_empty not 1";
    -- Output buffer contains 7766554433221100
    assert m_valid = '1'
      report "m_valid not 1";
    -- Input buffer is ready
    assert s_ready = '0'
      report "s_ready not 0";

    verify(X"7766554433221100");
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer is empty
    assert m_valid = '1'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    verify(X"FFEEDDCCBBAA9988");
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";


    if not G_FAST then
      wait until rising_edge(clk);
    end if;
    if G_SHOW_TESTS then
      report "Test 8: PUSH without data";
    end if;
    send(X"554433221100", 1, 5, '0');
    -- Internal buffer now contains 44332211
    assert m_empty = '0'
      report "m_empty not 0";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    send(X"554433221100", 3, 3, '1');
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer contains 44332211
    assert m_valid = '1'
      report "m_valid not 1";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";

    verify(X"44332211");
    -- Internal buffer is empty
    assert m_empty = '1'
      report "m_empty not 1";
    -- Output buffer is empty
    assert m_valid = '0'
      report "m_valid not 0";
    -- Input buffer is ready
    assert s_ready = '1'
      report "s_ready not 1";


    report "Test finished";
    wait until rising_edge(clk);
    running <= '0';
    wait;
  end process test_proc;


  -------------------------------------
  -- Instantiate DUT
  -------------------------------------

  axi_fifo_squash_inst : entity work.axi_fifo_squash
    generic map (
      G_DATA_BYTES => C_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => s_ready,
      s_valid_i => s_valid,
      s_data_i  => s_data,
      s_start_i => s_start,
      s_end_i   => s_end,
      s_push_i  => s_push,
      m_ready_i => m_ready,
      m_valid_o => m_valid,
      m_data_o  => m_data,
      m_bytes_o => m_bytes,
      m_empty_o => m_empty
    ); -- axi_fifo_squash_inst : entity work.axi_fifo_squash

end architecture simulation;


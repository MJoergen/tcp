library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axi_fifo_squash is
  generic (
    G_DATA_BYTES : natural;

    G_FAST       : boolean;
    G_SHOW_TESTS : boolean;
    G_SHOW_DATA  : boolean
  );
end entity tb_axi_fifo_squash;

architecture simulation of tb_axi_fifo_squash is

  signal   clk     : std_logic        := '1';
  signal   rst     : std_logic        := '1';
  signal   running : std_logic        := '1';

  signal   s_ready : std_logic;
  signal   s_valid : std_logic;
  signal   s_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal   s_start : natural range 0 to G_DATA_BYTES - 1;
  signal   s_end   : natural range 0 to G_DATA_BYTES;
  signal   s_last  : std_logic;

  signal   m_ready : std_logic;
  signal   m_valid : std_logic;
  signal   m_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal   m_bytes : natural range 0 to G_DATA_BYTES;
  signal   m_last  : std_logic;
  signal   m_empty : std_logic;

  type     test_type is record
    name   : string(1 to 24);
    -- Stimuli
    verify : boolean;
    data   : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    dstart : natural;
    dend   : natural;
    s_last : std_logic;
    -- Response
    empty  : std_logic;
    valid  : std_logic;
    ready  : std_logic;
    m_last : std_logic;
  end record test_type;

  constant C_NONAME : string(1 to 24) := (others => ' ');

  type     test_vector_type is array (natural range <>) of test_type;
  constant C_TESTS : test_vector_type :=
  (                                                                                           --                             Stimuli                              Response
    --                              V   D                    S  E   L     E    V    R    L
    ("LAST first write        ", false, X"7766554433221100", 1, 3, '1',  '1', '1', '0', '0'), -- Output buffer contains 2211
    ("                        ", true,  X"0000000000002211", 0, 2, '1',  '1', '0', '1', '1'),

    ("Full word without LAST  ", false, X"7766554433221100", 0, 8, '0',  '1', '1', '0', '0'), -- Output buffer contains 7766554433221100
    ("                        ", true,  X"7766554433221100", 0, 8, '0',  '1', '0', '1', '0'),
    ("                        ", false, X"7766554433221100", 0, 0, '1',  '1', '1', '0', '0'),
    ("                        ", true,  X"7766554433221100", 0, 0, '0',  '1', '0', '1', '1'),

    ("LAST on second write    ", false, X"7766554433221100", 1, 3, '0',  '1', '0', '1', '0'), -- Internal buffer contains 2211
    ("                        ", false, X"7766554433221100", 2, 4, '1',  '1', '1', '0', '0'), -- Output buffer contains 33222211
    ("                        ", true,  X"0000000033222211", 0, 4, '0',  '1', '0', '1', '1'),

    ("Wrap around without LAST", false, X"7766554433221100", 0, 6, '0',  '1', '0', '1', '0'), -- Internal buffer contains 554433221100
    ("                        ", false, X"7766554433221100", 3, 6, '0',  '0', '1', '0', '0'), -- Internal buffer contains 55
    ("                        ", true,  X"4433554433221100", 0, 8, '0',  '1', '0', '1', '0'),
    ("                        ", false, X"7766554433221100", 0, 3, '1',  '1', '1', '0', '0'), -- Output buffer contains 22110055
    ("                        ", true,  X"0000000022110055", 0, 4, '0',  '1', '0', '1', '1'),

    ("Wrap around with LAST   ", false, X"7766554433221100", 0, 6, '0',  '1', '0', '1', '0'), -- Internal buffer contains 554433221100
    ("                        ", false, X"7766554433221100", 3, 6, '1',  '0', '1', '0', '0'), -- Internal buffer contains 55
    ("                        ", true,  X"4433554433221100", 0, 8, '0',  '1', '1', '0', '0'),
    ("                        ", true,  X"0000000000000055", 0, 1, '0',  '1', '0', '1', '1'),

    ("Wrap around whole word  ", false, X"7766554433221100", 0, 5, '0',  '1', '0', '1', '0'), -- Internal buffer contains 4433221100
    ("                        ", false, X"7766554433221100", 3, 6, '0',  '1', '1', '0', '0'), -- Internal buffer is empty
    ("                        ", true,  X"5544334433221100", 0, 8, '0',  '1', '0', '1', '0'),
    ("                        ", false, X"7766554433221100", 0, 0, '1',  '1', '1', '0', '0'),
    ("                        ", true,  X"7766554433221100", 0, 0, '0',  '1', '0', '1', '1'),

    ("Wrap around backwards   ", false, X"8877665544332211", 0, 1, '0',  '1', '0', '1', '0'), -- Internal buffer contains 11
    ("                        ", false, X"7766554433221100", 3, 6, '1',  '1', '1', '0', '0'), -- Output buffer contains 55443311
    ("                        ", true,  X"0000000055443311", 0, 4, '0',  '1', '0', '1', '1'),

    ("LAST without data       ", false, X"7766554433221100", 1, 5, '0',  '1', '0', '1', '0'), -- Internal buffer contains 44332211
    ("                        ", false, X"7766554433221100", 3, 3, '1',  '1', '1', '0', '0'), -- Output buffer contains 44332211
    ("                        ", true,  X"0000000044332211", 0, 4, '0',  '1', '0', '1', '1')
  );

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
      tb_last  : std_logic
    ) is
      variable arg_v : std_logic_vector(tb_arg'high downto tb_arg'low);
    begin
      -- This is a VHDL trick necessary to convert from a rising range to a falling range.
      arg_v := tb_arg;
      if G_SHOW_DATA then
        if tb_end = tb_start then
          if tb_last = '1' then
            report "--  Sending: LAST";
          else
            report "--  Sending: no data";
          end if;
        else
          if tb_last = '1' then
            report "--  Sending: " & to_hstring(arg_v(tb_end * 8 - 1 downto tb_start * 8)) & " LAST";
          else
            report "--  Sending: " & to_hstring(arg_v(tb_end * 8 - 1 downto tb_start * 8));
          end if;
        end if;
      end if;

      s_data(arg_v'range) <= arg_v;
      s_start             <= tb_start;
      s_end               <= tb_end;
      s_last              <= tb_last;
      s_valid             <= '1';
      wait until rising_edge(clk);

      assert s_ready = '1'
        report "FAIL: Tx buffer not ready";

      s_data              <= (others => '0');
      s_start             <= 0;
      s_end               <= 0;
      s_last              <= '0';
      s_valid             <= '0';
      if not G_FAST then
        wait until rising_edge(clk);
      else
        wait for 1 ns;
      end if;
    end procedure send;

    procedure verify (
      arg  : std_logic_vector;
      last : std_logic
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

      assert m_last = last
        report "Verify FAIL last: " &
               "Received " & to_string(m_last) &
               ", expected " & to_string(last);

      if G_SHOW_DATA then
        report "--  Received " & to_hstring(m_data(m_bytes * 8 - 1 downto 0));
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
    s_last  <= '0';
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

    for i in C_TESTS'range loop
      if not G_FAST then
        wait until rising_edge(clk);
      end if;
      if G_SHOW_TESTS and C_TESTS(i).name /= C_NONAME then
        report "** " & C_TESTS(i).name;
      end if;

      if C_TESTS(i).verify then
        verify(C_TESTS(i).data(C_TESTS(i).dend * 8 - 1 downto 0), C_TESTS(i).m_last);
      else
        send(C_TESTS(i).data, C_TESTS(i).dstart, C_TESTS(i).dend, C_TESTS(i).s_last);
      end if;

      assert m_empty = C_TESTS(i).empty
        report "index " & to_string(i) & ": m_empty not " & to_string(C_TESTS(i).empty);
      assert m_valid = C_TESTS(i).valid
        report "index " & to_string(i) & ": m_valid not " & to_string(C_TESTS(i).valid);
      assert s_ready = C_TESTS(i).ready
        report "index " & to_string(i) & ": s_ready not " & to_string(C_TESTS(i).ready);
    end loop;

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
      G_S_DATA_BYTES => G_DATA_BYTES,
      G_M_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => s_ready,
      s_valid_i => s_valid,
      s_data_i  => s_data,
      s_start_i => s_start,
      s_end_i   => s_end,
      s_last_i  => s_last,
      m_ready_i => m_ready,
      m_valid_o => m_valid,
      m_data_o  => m_data,
      m_bytes_o => m_bytes,
      m_last_o  => m_last,
      m_empty_o => m_empty
    ); -- axi_fifo_squash_inst : entity work.axi_fifo_squash

end architecture simulation;


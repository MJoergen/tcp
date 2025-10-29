library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axi_pipe_wide is
end entity tb_axi_pipe_wide;

architecture simulation of tb_axi_pipe_wide is

  constant C_S_DATA_BYTES : natural := 4;
  constant C_M_DATA_BYTES : natural := 4;

  signal   clk     : std_logic      := '1';
  signal   rst     : std_logic      := '1';
  signal   running : std_logic      := '1';

  signal   s_ready : std_logic;
  signal   s_valid : std_logic;
  signal   s_data  : std_logic_vector(C_S_DATA_BYTES * 8 - 1 downto 0);
  signal   s_bytes : natural range 0 to C_S_DATA_BYTES;
  signal   s_last  : std_logic;

  signal   m_ready         : std_logic;
  signal   m_bytes_consume : natural range 0 to C_M_DATA_BYTES;
  signal   m_valid         : std_logic;
  signal   m_data          : std_logic_vector(C_M_DATA_BYTES * 8 - 1 downto 0);
  signal   m_bytes_avail   : natural range 0 to C_M_DATA_BYTES;
  signal   m_last          : std_logic;

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
      arg : std_logic_vector;
      last : std_logic
    ) is
      variable arg_v : std_logic_vector(arg'high downto arg'low);
    begin
      -- This is a VHDL trick necessary to convert from a rising range to a falling range.
      arg_v               := arg;

      report "Sending: " & to_hstring(arg_v);

      -- Simulation trick to allow combinatorial paths to update
      wait for 1 ns;

      assert s_ready = '1'
        report "FAIL: Tx buffer full";

      s_data(arg_v'range) <= arg_v;
      s_bytes             <= arg_v'length / 8;
      s_valid             <= '1';
      s_last              <= last;
      wait until rising_edge(clk);

      assert s_ready = '1'
        report "FAIL: Tx buffer not ready";

      s_data(arg_v'range) <= (others => '0');
      s_bytes             <= 0;
      s_valid             <= '0';
      s_last              <= '0';
    end procedure send;

    procedure verify (
      arg  : std_logic_vector;
      last : std_logic
    ) is
      variable bytes_v : natural;
      variable exp_v : std_logic_vector(arg'high downto arg'low);
    begin
      -- This is a VHDL trick necessary to convert from a rising range to a falling range.
      exp_v := arg;

      -- Consume only the specified number of bytes
      m_bytes_consume <= arg'length / 8;

      m_ready <= '1';

      -- Simulation trick to allow combinatorial paths to update
      wait for 1 ns;

      assert m_valid = '1'
        report "Verify FAIL: m_valid not set";

      bytes_v := minimum(m_bytes_consume, m_bytes_avail);

      report "Verify received : " & to_hstring(m_data(bytes_v * 8 - 1 downto 0));

      assert m_data(bytes_v * 8 - 1 downto 0) = exp_v(bytes_v * 8 - 1 downto 0)
        report "Verify FAIL: Expected " & to_hstring(exp_v(bytes_v * 8 - 1 downto 0));

      assert m_last = last
        report "Verify last FAIL: Received " & to_string(last) &
               ", expected " & to_string(last);

      wait until rising_edge(clk);
      m_ready <= '0';
    end procedure verify;

  begin
    s_valid         <= '0';
    s_data          <= (others => '0');
    m_ready         <= '0';
    m_bytes_consume <= 0;
    wait until rst = '0';
    wait for 100 ns;
    wait until rising_edge(clk);

    report "Test started";

    send(  X"11",   '0');
    send(  X"22",   '1');
    verify(X"11",   '0');
    verify(X"22",   '1');
    send(  X"4433", '0');
    send(  X"55",   '1');
    verify(X"33",   '0');
    verify(X"5544", '1');

    report "Test finished";
    wait until rising_edge(clk);
    running         <= '0';
    wait;
  end process test_proc;


  -------------------------------------
  -- Instantiate DUT
  -------------------------------------

  axi_pipe_wide_inst : entity work.axi_pipe_wide
    generic map (
      G_S_DATA_BYTES => C_S_DATA_BYTES,
      G_M_DATA_BYTES => C_M_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => s_ready,
      s_valid_i => s_valid,
      s_data_i  => s_data,
      s_start_i => 0,
      s_end_i   => s_bytes,
      s_last_i  => s_last,
      m_ready_i => m_ready,
      m_bytes_i => m_bytes_consume,
      m_valid_o => m_valid,
      m_data_o  => m_data,
      m_bytes_o => m_bytes_avail,
      m_last_o  => m_last
    ); -- axi_pipe_wide_inst : entity work.axi_pipe_wide

end architecture simulation;


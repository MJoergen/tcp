-- ----------------------------------------------------------------------------
-- Title      : Main FPGA
-- Project    : XENTA, RCU, PCB1036 Board
-- ----------------------------------------------------------------------------
-- File       : tb_axi_fifo_wide.vhd
-- Author     : Michael Jørgensen
-- Company    : Weibel Scientific
-- Created    : 2025-05-19
-- Platform   : Simulation
-- ----------------------------------------------------------------------------
-- Description:
-- Simple testbench for the MAC to WBUS interface.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axi_fifo_wide is
end entity tb_axi_fifo_wide;

architecture simulation of tb_axi_fifo_wide is

  constant C_DATA_SIZE : natural := 32; -- Number of bits

  signal   clk     : std_logic   := '1';
  signal   rst     : std_logic   := '1';
  signal   running : std_logic   := '1';

  signal   s_ready         : std_logic;
  signal   s_valid         : std_logic;
  signal   s_data          : std_logic_vector(C_DATA_SIZE - 1 downto 0);
  signal   s_bytes         : natural range 0 to C_DATA_SIZE / 8;
  signal   m_ready         : std_logic;
  signal   m_bytes_consume : natural range 0 to C_DATA_SIZE / 8;
  signal   m_valid         : std_logic;
  signal   m_data          : std_logic_vector(C_DATA_SIZE - 1 downto 0);
  signal   m_bytes_avail   : natural range 0 to C_DATA_SIZE / 8;

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
      arg : std_logic_vector
    ) is
      variable arg_v : std_logic_vector(arg'high downto arg'low);
    begin
      -- This is a VHDL trick necessary to convert from a rising range to a falling range.
      arg_v               := arg;
      report "Sending: " & to_hstring(arg_v);
      assert s_valid = '0' or s_ready = '1'
        report "FAIL: Tx buffer full";

      s_data(arg_v'range) <= arg_v;
      s_bytes             <= arg_v'length / 8;
      s_valid             <= '1';
      wait until rising_edge(clk);

      assert s_ready = '1'
        report "FAIL: Tx buffer not ready";

      s_data(arg_v'range) <= (others => '0');
      s_bytes             <= 0;
      s_valid             <= '0';
    end procedure send;

    procedure verify (
      arg  : std_logic_vector;
      full : boolean := false -- Set to true to empty the output buffer
    ) is
      variable exp_v : std_logic_vector(arg'high downto arg'low);
    begin
      -- This is a VHDL trick necessary to convert from a rising range to a falling range.
      exp_v := arg;

      if full then
        -- Consume entire buffer
        m_bytes_consume <= 0;
      else
        -- Consume only the specified number of bytes
        m_bytes_consume <= arg'length / 8;
      end if;

      m_ready <= '1';

      -- Simulation trick to allow combinatorial paths to update
      wait for 1 ns;

      assert m_valid = '1'
        report "Verify FAIL: m_valid not set";

      if full then
        -- "Give me everything you've got".
        assert m_bytes_avail = arg'length / 8
          report "Verify FAIL (full): " &
                 "Received " & to_string(m_bytes_avail) & " bytes." &
                 " Expected " & to_string(arg'length / 8) & " bytes.";
      else
        -- "Give me what I want".
        assert m_bytes_avail >= m_bytes_consume
          report "Verify FAIL (partial): " &
                 "Received " & to_string(m_bytes_avail) & " bytes." &
                 " Expected " & to_string(m_bytes_consume) & " bytes.";
      end if;

      report "Verify received : " & to_hstring(m_data(arg'length/8 * 8 - 1 downto 0));

      assert m_data(arg'length/8 * 8 - 1 downto 0) = exp_v(arg'length/8 * 8 - 1 downto 0)
        report "Verify FAIL: Expected " & to_hstring(exp_v(arg'length/8 * 8 - 1 downto 0));

      wait until rising_edge(clk);
      m_ready <= '0';
    end procedure verify;

  begin
    s_valid         <= '0';
    m_ready         <= '0';
    m_bytes_consume <= 0;
    wait until rst = '0';
    wait for 100 ns;
    wait until rising_edge(clk);

    report "Test started";

    send(X"11");
    send(X"22");
    send(X"4433");
    verify(X"11");               -- Partial
    send(X"55");

    s_bytes <= 1;
    -- Simulation trick to allow combinatorial paths to update
    wait for 1 ns;

    assert s_ready = '0'
      report "FAIL: Tx buffer still ready";

    verify(X"443322");           -- Partial
    send(X"66");
    verify(X"6655", true);

    report "Test finished";
    wait until rising_edge(clk);
    running         <= '0';
    wait;
  end process test_proc;


  -------------------------------------
  -- Instantiate DUT
  -------------------------------------

  axi_fifo_wide_inst : entity work.axi_fifo_wide
    generic map (
      G_DATA_SIZE => C_DATA_SIZE
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => s_ready,
      s_valid_i => s_valid,
      s_data_i  => s_data,
      s_bytes_i => s_bytes,
      m_ready_i => m_ready,
      m_bytes_i => m_bytes_consume,
      m_valid_o => m_valid,
      m_data_o  => m_data,
      m_bytes_o => m_bytes_avail
    ); -- axi_fifo_wide_inst : entity work.axi_fifo_wide

end architecture simulation;


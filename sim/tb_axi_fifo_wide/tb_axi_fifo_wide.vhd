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

  constant C_DATA_SIZE : natural := 32;

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
    begin
      report "Sending: " & to_hstring(arg);
      assert s_valid = '0' or s_ready = '1';
      s_data(arg'high downto arg'low) <= arg;
      s_bytes                         <= arg'length / 8;
      s_valid                         <= '1';
      wait until rising_edge(clk);
      while s_ready = '0' loop
        wait until rising_edge(clk);
      end loop;
      s_data(arg'high downto arg'low) <= (others => '0');
      s_bytes                         <= 0;
      s_valid                         <= '0';
    end procedure send;

    procedure verify (
      arg : std_logic_vector
    ) is
    begin
      m_bytes_consume <= arg'length / 8;
      m_ready         <= '1';
      wait for 0 ns;
      while m_valid = '0' loop
        wait until rising_edge(clk);
      end loop;
      assert m_data(arg'high downto arg'low) = arg
        report "Verify FAIL: " &
               "Received " & to_hstring(m_data(arg'high downto arg'low)) &
               ", expected " & to_hstring(arg);
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
    send(X"3344");
    verify(X"33442211");

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


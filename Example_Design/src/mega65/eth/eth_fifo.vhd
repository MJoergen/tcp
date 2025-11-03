-- ----------------------------------------------------------------------------
-- Title      : Main FPGA
-- Project    : XENTA, RCU, PCB1036 Board
-- ----------------------------------------------------------------------------
-- File       : eth_fifo.vhd
-- Author     : Michael Jørgensen
-- Company    : Weibel Scientific
-- Created    : 2025-05-19
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description:
-- Provides a Clock Domain Crossing in the form of an asynchronous FIFO.
-- It uses a separate FIFO for the Rx and Tx paths.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library xpm;
  use xpm.vcomponents.all;

entity eth_fifo is
  generic (
    G_FIFO_DEPTH : natural;
    G_DATA_SIZE  : natural
  );
  port (
    -- Client side
    user_clk_i          : in    std_logic;
    user_rst_i          : in    std_logic;
    user_rx_ready_i     : in    std_logic;
    user_rx_valid_o     : out   std_logic;
    user_rx_last_o      : out   std_logic;
    user_rx_data_o      : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    user_tx_ready_o     : out   std_logic;
    user_tx_valid_i     : in    std_logic;
    user_tx_last_i      : in    std_logic;
    user_tx_data_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);

    -- PHY side
    eth_clk_i      : in    std_logic;
    eth_rst_i      : in    std_logic;
    eth_rx_ready_o : out   std_logic;
    eth_rx_valid_i : in    std_logic;
    eth_rx_last_i  : in    std_logic;
    eth_rx_data_i  : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    eth_tx_ready_i : in    std_logic;
    eth_tx_valid_o : out   std_logic;
    eth_tx_last_o  : out   std_logic;
    eth_tx_data_o  : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity eth_fifo;

architecture synthesis of eth_fifo is

begin

  ---------------------------
  -- Rx path: PHY -> Client
  ---------------------------

  xpm_fifo_axis_rx_inst : component xpm_fifo_axis
    generic map (
      CLOCKING_MODE    => "independent_clock",
      FIFO_DEPTH       => G_FIFO_DEPTH,
      FIFO_MEMORY_TYPE => "auto",
      PACKET_FIFO      => "true",
      RELATED_CLOCKS   => 0, -- Must be 0 when PACKET_FIFO is true.
      TDATA_WIDTH      => G_DATA_SIZE,
      USE_ADV_FEATURES => "1000"
    )
    port map (
      almost_empty_axis  => open,
      almost_full_axis   => open,
      dbiterr_axis       => open,
      injectdbiterr_axis => '0',
      injectsbiterr_axis => '0',
      m_aclk             => user_clk_i,
      m_axis_tdata       => user_rx_data_o,
      m_axis_tdest       => open,
      m_axis_tid         => open,
      m_axis_tkeep       => open,
      m_axis_tlast       => user_rx_last_o,
      m_axis_tready      => user_rx_ready_i,
      m_axis_tstrb       => open,
      m_axis_tuser       => open,
      m_axis_tvalid      => user_rx_valid_o,
      prog_empty_axis    => open,
      prog_full_axis     => open,
      rd_data_count_axis => open,
      s_aclk             => eth_clk_i,
      s_aresetn          => not eth_rst_i,
      s_axis_tdata       => eth_rx_data_i,
      s_axis_tdest       => "0",
      s_axis_tid         => "0",
      s_axis_tkeep       => (others => '1'),
      s_axis_tlast       => eth_rx_last_i,
      s_axis_tready      => eth_rx_ready_o,
      s_axis_tstrb       => (others => '1'),
      s_axis_tuser       => "0",
      s_axis_tvalid      => eth_rx_valid_i,
      sbiterr_axis       => open,
      wr_data_count_axis => open
    ); -- xpm_fifo_axis_rx_inst : component xpm_fifo_axis


  ---------------------------
  -- Tx path: Client -> PHY
  ---------------------------

  xpm_fifo_axis_tx_inst : component xpm_fifo_axis
    generic map (
      CLOCKING_MODE    => "independent_clock",
      FIFO_DEPTH       => G_FIFO_DEPTH,
      FIFO_MEMORY_TYPE => "auto",
      PACKET_FIFO      => "true",
      RELATED_CLOCKS   => 0, -- Must be 0 when PACKET_FIFO is true.
      TDATA_WIDTH      => G_DATA_SIZE,
      USE_ADV_FEATURES => "1000"
    )
    port map (
      almost_empty_axis  => open,
      almost_full_axis   => open,
      dbiterr_axis       => open,
      injectdbiterr_axis => '0',
      injectsbiterr_axis => '0',
      m_aclk             => eth_clk_i,
      m_axis_tdata       => eth_tx_data_o,
      m_axis_tdest       => open,
      m_axis_tid         => open,
      m_axis_tkeep       => open,
      m_axis_tlast       => eth_tx_last_o,
      m_axis_tready      => eth_tx_ready_i,
      m_axis_tstrb       => open,
      m_axis_tuser       => open,
      m_axis_tvalid      => eth_tx_valid_o,
      prog_empty_axis    => open,
      prog_full_axis     => open,
      rd_data_count_axis => open,
      s_aclk             => user_clk_i,
      s_aresetn          => not user_rst_i,
      s_axis_tdata       => user_tx_data_i,
      s_axis_tdest       => "0",
      s_axis_tid         => "0",
      s_axis_tkeep       => "1",
      s_axis_tlast       => user_tx_last_i,
      s_axis_tready      => user_tx_ready_o,
      s_axis_tstrb       => "1",
      s_axis_tuser       => "0",
      s_axis_tvalid      => user_tx_valid_i,
      sbiterr_axis       => open,
      wr_data_count_axis => open
    ); -- xpm_fifo_axis_tx_inst : component xpm_fifo_axis

end architecture synthesis;


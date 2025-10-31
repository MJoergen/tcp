library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity top is
  port (
    clk_i        : in    std_logic;                      -- 100 MHz

    -- Connected to Ethernet port
    eth_txd_o    : out   std_logic_vector(1 downto 0);
    eth_txen_o   : out   std_logic;
    eth_rxd_i    : in    std_logic_vector(1 downto 0);
    eth_rxerr_i  : in    std_logic;
    eth_crsdv_i  : in    std_logic;
    eth_intn_i   : in    std_logic;
    eth_mdio_io  : inout std_logic;
    eth_mdc_o    : out   std_logic;
    eth_rstn_o   : out   std_logic;
    eth_refclk_o : out   std_logic
  );
end entity top;

architecture structural of top is

  constant C_MY_MAC : std_logic_vector(47 downto 0) := X"001122334455";
  constant C_MY_IP  : std_logic_vector(31 downto 0) := X"C0A8014D"; -- 192.168.1.77
  constant C_MY_UDP : std_logic_vector(15 downto 0) := X"1234";     -- 4660

  constant C_ETH_PAYLOAD_BYTES : natural            := 10;
  constant C_USER_BYTES        : natural            := 10;

  -- Clock and reset
  signal   eth_clk : std_logic;
  signal   eth_rst : std_logic;
  signal   mac_clk : std_logic;
  signal   mac_rst : std_logic;

  -- Connected to MAC client
  signal   mac_rx_valid : std_logic;
  signal   mac_rx_data  : std_logic_vector(60 * 8 - 1 downto 0);
  signal   mac_rx_last  : std_logic;
  signal   mac_rx_bytes : std_logic_vector(5 downto 0);
  signal   mac_tx_valid : std_logic;
  signal   mac_tx_data  : std_logic_vector(60 * 8 - 1 downto 0);
  signal   mac_tx_last  : std_logic;
  signal   mac_tx_bytes : std_logic_vector(5 downto 0);

  signal   mac_user_start       : std_logic;
  signal   mac_user_src_address : std_logic_vector(47 downto 0);    -- MAC address
  signal   mac_user_dst_address : std_logic_vector(47 downto 0);    -- MAC address
  signal   mac_user_protocol    : std_logic_vector(15 downto 0);    -- MAC protocol
  signal   mac_user_established : std_logic;
  signal   mac_user_rx_ready    : std_logic;
  signal   mac_user_rx_valid    : std_logic;
  signal   mac_user_rx_data     : std_logic_vector(C_USER_BYTES * 8 - 1 downto 0);
  signal   mac_user_rx_bytes    : natural range 0 to C_USER_BYTES;
  signal   mac_user_rx_last     : std_logic;
  signal   mac_user_tx_ready    : std_logic;
  signal   mac_user_tx_valid    : std_logic;
  signal   mac_user_tx_data     : std_logic_vector(C_USER_BYTES * 8 - 1 downto 0);
  signal   mac_user_tx_bytes    : natural range 0 to C_USER_BYTES;
  signal   mac_user_tx_last     : std_logic;
  signal   mac_payload_rx_ready : std_logic;
  signal   mac_payload_rx_valid : std_logic;
  signal   mac_payload_rx_data  : std_logic_vector(C_ETH_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   mac_payload_rx_bytes : natural range 0 to C_ETH_PAYLOAD_BYTES;
  signal   mac_payload_rx_last  : std_logic;
  signal   mac_payload_tx_ready : std_logic;
  signal   mac_payload_tx_valid : std_logic;
  signal   mac_payload_tx_data  : std_logic_vector(C_ETH_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   mac_payload_tx_bytes : natural range 0 to C_ETH_PAYLOAD_BYTES;
  signal   mac_payload_tx_last  : std_logic;

begin

  --------------------------------------
  -- Instantiate Clock and Reset module
  --------------------------------------

  clk_rst_inst : entity work.clk_rst
    port map (
      sys_clk_i => clk_i,
      mac_clk_o => mac_clk,
      mac_rst_o => mac_rst,
      eth_clk_o => eth_clk,
      eth_rst_o => eth_rst
    ); -- clk_rst_inst


  --------------------------------------------------
  -- Instantiate Ethernet module
  --------------------------------------------------

  eth_inst : entity work.eth
    port map (
      mac_clk_i      => mac_clk,
      mac_rst_i      => mac_rst,
      mac_rx_valid_o => mac_rx_valid,
      mac_rx_data_o  => mac_rx_data,
      mac_rx_last_o  => mac_rx_last,
      mac_rx_bytes_o => mac_rx_bytes,
      mac_tx_valid_i => mac_tx_valid,
      mac_tx_data_i  => mac_tx_data,
      mac_tx_last_i  => mac_tx_last,
      mac_tx_bytes_i => mac_tx_bytes,
      eth_clk_i      => eth_clk,
      eth_rst_i      => eth_rst,
      eth_txd_o      => eth_txd_o,
      eth_txen_o     => eth_txen_o,
      eth_rxd_i      => eth_rxd_i,
      eth_rxerr_i    => eth_rxerr_i,
      eth_crsdv_i    => eth_crsdv_i,
      eth_intn_i     => eth_intn_i,
      eth_mdio_io    => eth_mdio_io,
      eth_mdc_o      => eth_mdc_o,
      eth_rstn_o     => eth_rstn_o,
      eth_refclk_o   => eth_refclk_o
    ); -- eth_inst

  mac_wrapper_inst : entity work.mac_wrapper
    generic map (
      G_SIM_NAME          => "",
      G_ETH_PAYLOAD_BYTES => 10,
      G_USER_BYTES        => 4
    )
    port map (
      clk_i                  => mac_clk,
      rst_i                  => mac_rst,
      user_start_i           => mac_user_start,
      user_src_address_i     => mac_user_src_address,
      user_dst_address_i     => mac_user_dst_address,
      user_protocol_i        => mac_user_protocol,
      user_established_o     => mac_user_established,
      user_rx_ready_i        => mac_user_rx_ready,
      user_rx_valid_o        => mac_user_rx_valid,
      user_rx_data_o         => mac_user_rx_data,
      user_rx_bytes_o        => mac_user_rx_bytes,
      user_rx_last_o         => mac_user_rx_last,
      user_tx_ready_o        => mac_user_tx_ready,
      user_tx_valid_i        => mac_user_tx_valid,
      user_tx_data_i         => mac_user_tx_data,
      user_tx_bytes_i        => mac_user_tx_bytes,
      user_tx_last_i         => mac_user_tx_last,
      eth_payload_rx_ready_o => mac_payload_rx_ready,
      eth_payload_rx_valid_i => mac_payload_rx_valid,
      eth_payload_rx_data_i  => mac_payload_rx_data,
      eth_payload_rx_bytes_i => mac_payload_rx_bytes,
      eth_payload_rx_last_i  => mac_payload_rx_last,
      eth_payload_tx_ready_i => mac_payload_tx_ready,
      eth_payload_tx_valid_o => mac_payload_tx_valid,
      eth_payload_tx_data_o  => mac_payload_tx_data,
      eth_payload_tx_bytes_o => mac_payload_tx_bytes,
      eth_payload_tx_last_o  => mac_payload_tx_last
    ); -- mac_wrapper_inst : entity work.mac_wrapper

end architecture structural;


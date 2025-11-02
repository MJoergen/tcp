library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity design is
  generic (
    G_ETH_BYTES : natural
  );
  port (
    clk_i          : in    std_logic;
    rst_i          : in    std_logic;
    eth_rx_ready_o : out   std_logic;
    eth_rx_valid_i : in    std_logic;
    eth_rx_data_i  : in    std_logic_vector(G_ETH_BYTES * 8 - 1 downto 0);
    eth_rx_last_i  : in    std_logic;
    eth_rx_bytes_i : in    natural range 0 to G_ETH_BYTES;
    eth_tx_ready_i : in    std_logic;
    eth_tx_valid_o : out   std_logic;
    eth_tx_data_o  : out   std_logic_vector(G_ETH_BYTES * 8 - 1 downto 0);
    eth_tx_last_o  : out   std_logic;
    eth_tx_bytes_o : out   natural range 0 to G_ETH_BYTES
  );
end entity design;

architecture synthesis of design is

  constant C_USER_BYTES : natural := 4;

  signal mac_user_start       : std_logic;
  signal mac_user_src_address : std_logic_vector(47 downto 0); -- MAC address
  signal mac_user_dst_address : std_logic_vector(47 downto 0); -- MAC address
  signal mac_user_protocol    : std_logic_vector(15 downto 0); -- MAC protocol
  signal mac_user_established : std_logic;
  signal mac_user_rx_ready    : std_logic;
  signal mac_user_rx_valid    : std_logic;
  signal mac_user_rx_data     : std_logic_vector(C_USER_BYTES * 8 - 1 downto 0);
  signal mac_user_rx_bytes    : natural range 0 to C_USER_BYTES;
  signal mac_user_rx_last     : std_logic;
  signal mac_user_tx_ready    : std_logic;
  signal mac_user_tx_valid    : std_logic;
  signal mac_user_tx_data     : std_logic_vector(C_USER_BYTES * 8 - 1 downto 0);
  signal mac_user_tx_bytes    : natural range 0 to C_USER_BYTES;
  signal mac_user_tx_last     : std_logic;

begin

  mac_wrapper_inst : entity work.mac_wrapper
    generic map (
      G_SIM_NAME          => "",
      G_ETH_PAYLOAD_BYTES => G_ETH_BYTES,
      G_USER_BYTES        => C_USER_BYTES
    )
    port map (
      clk_i              => clk_i,
      rst_i              => rst_i,
      user_start_i       => mac_user_start,
      user_src_address_i => mac_user_src_address,
      user_dst_address_i => mac_user_dst_address,
      user_protocol_i    => mac_user_protocol,
      user_established_o => mac_user_established,
      user_rx_ready_i    => mac_user_rx_ready,
      user_rx_valid_o    => mac_user_rx_valid,
      user_rx_data_o     => mac_user_rx_data,
      user_rx_bytes_o    => mac_user_rx_bytes,
      user_rx_last_o     => mac_user_rx_last,
      user_tx_ready_o    => mac_user_tx_ready,
      user_tx_valid_i    => mac_user_tx_valid,
      user_tx_data_i     => mac_user_tx_data,
      user_tx_bytes_i    => mac_user_tx_bytes,
      user_tx_last_i     => mac_user_tx_last,
      eth_rx_ready_o     => eth_rx_ready_o,
      eth_rx_valid_i     => eth_rx_valid_i,
      eth_rx_data_i      => eth_rx_data_i,
      eth_rx_bytes_i     => eth_rx_bytes_i,
      eth_rx_last_i      => eth_rx_last_i,
      eth_tx_ready_i     => eth_tx_ready_i,
      eth_tx_valid_o     => eth_tx_valid_o,
      eth_tx_data_o      => eth_tx_data_o,
      eth_tx_bytes_o     => eth_tx_bytes_o,
      eth_tx_last_o      => eth_tx_last_o
    ); -- mac_wrapper_inst : entity work.mac_wrapper

end architecture synthesis;


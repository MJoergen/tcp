library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

-- The packet flow is as follows:
-- TB -> Client -> Server -> User -> Loopback -> User -> Server -> Client -> TB

entity tb_mac_handler is
  generic (
    G_BYTES         : natural;
    G_MIN_LENGTH    : natural;
    G_MAX_LENGTH    : natural;
    G_CNT_SIZE      : natural;
    G_RANDOM        : boolean;
    G_FAST          : boolean;
    G_SHOW_PACKETS  : boolean
  );
end entity tb_mac_handler;

-- Connect a MAC client and a MAC server and send data back and forth.

architecture simulation of tb_mac_handler is

  constant C_ADDRESS_CLIENT : std_logic_vector(47 downto 0) := x"C713C7131234";
  constant C_ADDRESS_SERVER : std_logic_vector(47 downto 0) := x"535353535678";
  constant C_PROTOCOL       : std_logic_vector(15 downto 0) := x"0800";

  signal   clk : std_logic                                  := '1';
  signal   rst : std_logic                                  := '1';

  signal   client_user_established : std_logic;
  signal   server_user_established : std_logic;

  -- TB to Client
  signal   client_user_tx_ready : std_logic;
  signal   client_user_tx_valid : std_logic;
  signal   client_user_tx_data  : std_logic_vector(G_BYTES * 8 - 1 downto 0);
  signal   client_user_tx_last  : std_logic;
  signal   client_user_tx_bytes : natural range 0 to G_BYTES;

  -- Client to Server
  signal   tb_eth_payload_c2s_ready : std_logic;
  signal   tb_eth_payload_c2s_valid : std_logic;
  signal   tb_eth_payload_c2s_data  : std_logic_vector(G_BYTES * 8 - 1 downto 0);
  signal   tb_eth_payload_c2s_last  : std_logic;
  signal   tb_eth_payload_c2s_bytes : natural range 0 to G_BYTES;

  -- Server to User
  signal   server_user_rx_ready : std_logic;
  signal   server_user_rx_valid : std_logic;
  signal   server_user_rx_data  : std_logic_vector(G_BYTES * 8 - 1 downto 0);
  signal   server_user_rx_last  : std_logic;
  signal   server_user_rx_bytes : natural range 0 to G_BYTES;

  -- User to Server
  signal   server_user_tx_ready : std_logic;
  signal   server_user_tx_valid : std_logic;
  signal   server_user_tx_data  : std_logic_vector(G_BYTES * 8 - 1 downto 0);
  signal   server_user_tx_bytes : natural range 0 to G_BYTES;
  signal   server_user_tx_last  : std_logic;

  -- Server to Client
  signal   tb_eth_payload_s2c_ready : std_logic;
  signal   tb_eth_payload_s2c_valid : std_logic;
  signal   tb_eth_payload_s2c_data  : std_logic_vector(G_BYTES * 8 - 1 downto 0);
  signal   tb_eth_payload_s2c_bytes : natural range 0 to G_BYTES;
  signal   tb_eth_payload_s2c_last  : std_logic;

  -- Client to TB
  signal   client_user_rx_ready : std_logic;
  signal   client_user_rx_valid : std_logic;
  signal   client_user_rx_data  : std_logic_vector(G_BYTES * 8 - 1 downto 0);
  signal   client_user_rx_bytes : natural range 0 to G_BYTES;
  signal   client_user_rx_last  : std_logic;

begin

  ----------------------------------------------------------
  -- Clock and reset
  ----------------------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------------------
  -- Generate stimuli and verify response
  ----------------------------------------------------------

  axip_sim_inst : entity work.axip_sim
    generic map (
      G_DEBUG      => false,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_CNT_SIZE   => G_CNT_SIZE,
      G_DATA_BYTES => G_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_ready_i => client_user_tx_ready,
      m_valid_o => client_user_tx_valid,
      m_data_o  => client_user_tx_data,
      m_last_o  => client_user_tx_last,
      m_bytes_o => client_user_tx_bytes,
      s_ready_o => client_user_rx_ready,
      s_valid_i => client_user_rx_valid,
      s_data_i  => client_user_rx_data,
      s_last_i  => client_user_rx_last,
      s_bytes_i => client_user_rx_bytes
    ); -- axip_sim_inst : entity work.axip_sim


  ----------------------------------------------------------
  -- Instantiate DUT client (initiator)
  ----------------------------------------------------------

  mac_handler_client_inst : entity work.mac_handler
    generic map (
      G_SIM_NAME => "CLIENT",
      G_BYTES    => G_BYTES
    )
    port map (
      clk_i                  => clk,
      rst_i                  => rst,
      user_start_i           => '1',
      user_src_address_i     => C_ADDRESS_CLIENT,
      user_dst_address_i     => C_ADDRESS_SERVER,
      user_protocol_i        => C_PROTOCOL,
      user_established_o     => client_user_established,
      user_rx_ready_i        => client_user_rx_ready,
      user_rx_valid_o        => client_user_rx_valid,
      user_rx_data_o         => client_user_rx_data,
      user_rx_bytes_o        => client_user_rx_bytes,
      user_rx_last_o         => client_user_rx_last,
      user_tx_ready_o        => client_user_tx_ready,
      user_tx_valid_i        => client_user_tx_valid,
      user_tx_data_i         => client_user_tx_data,
      user_tx_bytes_i        => client_user_tx_bytes,
      user_tx_last_i         => client_user_tx_last,
      eth_payload_rx_ready_o => tb_eth_payload_s2c_ready,
      eth_payload_rx_valid_i => tb_eth_payload_s2c_valid,
      eth_payload_rx_data_i  => tb_eth_payload_s2c_data,
      eth_payload_rx_bytes_i => tb_eth_payload_s2c_bytes,
      eth_payload_rx_last_i  => tb_eth_payload_s2c_last,
      eth_payload_tx_ready_i => tb_eth_payload_c2s_ready,
      eth_payload_tx_valid_o => tb_eth_payload_c2s_valid,
      eth_payload_tx_data_o  => tb_eth_payload_c2s_data,
      eth_payload_tx_bytes_o => tb_eth_payload_c2s_bytes,
      eth_payload_tx_last_o  => tb_eth_payload_c2s_last
    ); -- mac_handler_client_inst : entity work.mac_handler


  ----------------------------------------------------------
  -- Instantiate DUT server (responder)
  ----------------------------------------------------------

  mac_handler_server_inst : entity work.mac_handler
    generic map (
      G_SIM_NAME => "SERVER",
      G_BYTES    => G_BYTES
    )
    port map (
      clk_i                  => clk,
      rst_i                  => rst,
      user_start_i           => '1',
      user_src_address_i     => C_ADDRESS_SERVER,
      user_dst_address_i     => C_ADDRESS_CLIENT,
      user_protocol_i        => C_PROTOCOL,
      user_established_o     => server_user_established,
      user_rx_ready_i        => server_user_rx_ready,
      user_rx_valid_o        => server_user_rx_valid,
      user_rx_data_o         => server_user_rx_data,
      user_rx_bytes_o        => server_user_rx_bytes,
      user_rx_last_o         => server_user_rx_last,
      user_tx_ready_o        => server_user_tx_ready,
      user_tx_valid_i        => server_user_tx_valid,
      user_tx_data_i         => server_user_tx_data,
      user_tx_bytes_i        => server_user_tx_bytes,
      user_tx_last_i         => server_user_tx_last,
      eth_payload_rx_ready_o => tb_eth_payload_c2s_ready,
      eth_payload_rx_valid_i => tb_eth_payload_c2s_valid,
      eth_payload_rx_data_i  => tb_eth_payload_c2s_data,
      eth_payload_rx_bytes_i => tb_eth_payload_c2s_bytes,
      eth_payload_rx_last_i  => tb_eth_payload_c2s_last,
      eth_payload_tx_ready_i => tb_eth_payload_s2c_ready,
      eth_payload_tx_valid_o => tb_eth_payload_s2c_valid,
      eth_payload_tx_data_o  => tb_eth_payload_s2c_data,
      eth_payload_tx_bytes_o => tb_eth_payload_s2c_bytes,
      eth_payload_tx_last_o  => tb_eth_payload_s2c_last
    ); -- mac_handler_server_inst : entity work.mac_handler


  ----------------------------------------------------------
  -- Loopback data from server to client
  ----------------------------------------------------------

  axip_fifo_sync_inst : entity work.axip_fifo_sync
    generic map (
      G_RAM_STYLE  => "auto",
      G_DATA_BYTES => G_BYTES,
      G_RAM_DEPTH  => 4
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => server_user_rx_ready,
      s_valid_i => server_user_rx_valid,
      s_data_i  => server_user_rx_data,
      s_last_i  => server_user_rx_last,
      s_bytes_i => server_user_rx_bytes,
      m_ready_i => server_user_tx_ready,
      m_valid_o => server_user_tx_valid,
      m_data_o  => server_user_tx_data,
      m_last_o  => server_user_tx_last,
      m_bytes_o => server_user_tx_bytes
    ); -- axi_fifo_sync_inst : entity work.axi_fifo_sync


  ----------------------------------------------------------
  -- Dump data packets
  ----------------------------------------------------------

  axip_logger_c2s_inst : entity work.axip_logger
    generic map (
      G_ENABLE        => G_SHOW_PACKETS,
      G_LOG_NAME      => "C2S", -- Client to Server
      G_BYTES_PER_ROW => G_BYTES,
      G_DATA_BYTES    => G_BYTES
    )
    port map (
      clk_i   => clk,
      rst_i   => rst,
      ready_i => tb_eth_payload_c2s_ready,
      valid_i => tb_eth_payload_c2s_valid,
      data_i  => tb_eth_payload_c2s_data,
      last_i  => tb_eth_payload_c2s_last,
      bytes_i => tb_eth_payload_c2s_bytes
    ); -- axip_logger_c2s_inst : entity work.axip_logger

  axip_logger_s2c_inst : entity work.axip_logger
    generic map (
      G_ENABLE        => G_SHOW_PACKETS,
      G_LOG_NAME      => "S2C", -- Server to Client
      G_BYTES_PER_ROW => G_BYTES,
      G_DATA_BYTES    => G_BYTES
    )
    port map (
      clk_i   => clk,
      rst_i   => rst,
      ready_i => tb_eth_payload_s2c_ready,
      valid_i => tb_eth_payload_s2c_valid,
      data_i  => tb_eth_payload_s2c_data,
      last_i  => tb_eth_payload_s2c_last,
      bytes_i => tb_eth_payload_s2c_bytes
    ); -- axip_logger_s2c_inst : entity work.axip_logger

end architecture simulation;


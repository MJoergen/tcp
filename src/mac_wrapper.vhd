library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This module strips away the 14 byte MAC header, and forwards the remaining.

entity mac_wrapper is
  generic (
    G_SIM_NAME          : string;  -- Used in simulation
    G_ETH_PAYLOAD_BYTES : natural; -- Width of Ethernet payload data interface
    G_USER_BYTES        : natural  -- Width of user data interface
  );
  port (
    clk_i                  : in    std_logic;
    rst_i                  : in    std_logic;

    -- User control interface
    user_start_i           : in    std_logic;
    user_src_address_i     : in    std_logic_vector(47 downto 0); -- MAC address
    user_dst_address_i     : in    std_logic_vector(47 downto 0); -- MAC address
    user_protocol_i        : in    std_logic_vector(15 downto 0); -- MAC protocol
    user_established_o     : out   std_logic;
    -- User data interface (packet oriented)
    user_rx_ready_i        : in    std_logic;
    user_rx_valid_o        : out   std_logic;
    user_rx_data_o         : out   std_logic_vector(G_USER_BYTES * 8 - 1 downto 0);
    user_rx_bytes_o        : out   natural range 0 to G_USER_BYTES;
    user_rx_last_o         : out   std_logic;
    --
    user_tx_ready_o        : out   std_logic;
    user_tx_valid_i        : in    std_logic;
    user_tx_data_i         : in    std_logic_vector(G_USER_BYTES * 8 - 1 downto 0);
    user_tx_bytes_i        : in    natural range 0 to G_USER_BYTES;
    user_tx_last_i         : in    std_logic;

    -- Interface to MAC handler (packet oriented)
    eth_payload_rx_ready_o : out   std_logic;
    eth_payload_rx_valid_i : in    std_logic;
    eth_payload_rx_data_i  : in    std_logic_vector(G_ETH_PAYLOAD_BYTES * 8 - 1 downto 0);
    eth_payload_rx_bytes_i : in    natural range 0 to G_ETH_PAYLOAD_BYTES;
    eth_payload_rx_last_i  : in    std_logic;
    --
    eth_payload_tx_ready_i : in    std_logic;
    eth_payload_tx_valid_o : out   std_logic;
    eth_payload_tx_data_o  : out   std_logic_vector(G_ETH_PAYLOAD_BYTES * 8 - 1 downto 0);
    eth_payload_tx_bytes_o : out   natural range 0 to G_ETH_PAYLOAD_BYTES;
    eth_payload_tx_last_o  : out   std_logic
  );
end entity mac_wrapper;

architecture synthesis of mac_wrapper is

  subtype  R_MAC_DST_ADDRESS is natural range 8 * 6 - 1 downto 8 * 0;
  subtype  R_MAC_SRC_ADDRESS is natural range 8 * 12 - 1 downto 8 * 6;
  subtype  R_MAC_PROTOCOL    is natural range 8 * 14 - 1 downto 8 * 12;
  constant C_MAC_HEADER_LENGTH : natural := 14;
  constant C_MAC_BROADCAST : std_logic_vector(47 downto 0) := (others => '1');

  -- Tx path
  type     tx_state_type is (TX_IDLE_ST, TX_DATA_ST);
  signal   tx_state : tx_state_type      := TX_IDLE_ST;

  signal   tx_m_ready : std_logic;
  signal   tx_m_valid : std_logic;
  signal   tx_m_data  : std_logic_vector(G_ETH_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   tx_m_bytes : natural range 0 to G_ETH_PAYLOAD_BYTES;
  signal   tx_m_last  : std_logic;

  -- Rx path
  type     rx_state_type is (RX_IDLE_ST, RX_DATA_ST);
  signal   rx_state : rx_state_type      := RX_IDLE_ST;

  signal   rx_s_ready : std_logic;
  signal   rx_s_valid : std_logic;
  signal   rx_s_data  : std_logic_vector(G_ETH_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   rx_s_start : natural range 0 to G_ETH_PAYLOAD_BYTES - 1;
  signal   rx_s_end   : natural range 0 to G_ETH_PAYLOAD_BYTES;
  signal   rx_s_last  : std_logic;

begin

  assert G_ETH_PAYLOAD_BYTES > C_MAC_HEADER_LENGTH;

  user_established_o <= user_start_i;


  -------------------------------------
  -- Tx Path
  -------------------------------------

  axi_pipe_flexible_tx_inst : entity work.axi_pipe_flexible
    generic map (
      G_S_DATA_BYTES => G_USER_BYTES,
      G_M_DATA_BYTES => G_ETH_PAYLOAD_BYTES
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => user_tx_ready_o,
      s_valid_i => user_tx_valid_i,
      s_data_i  => user_tx_data_i,
      s_start_i => 0,
      s_end_i   => user_tx_bytes_i,
      s_last_i  => user_tx_last_i,
      m_ready_i => tx_m_ready,
      m_bytes_i => G_ETH_PAYLOAD_BYTES,
      m_valid_o => tx_m_valid,
      m_data_o  => tx_m_data,
      m_bytes_o => tx_m_bytes,
      m_last_o  => tx_m_last
    ); -- axi_pipe_flexible_tx_inst : entity work.axi_pipe_flexible

  tx_m_ready             <= not eth_payload_tx_valid_o when tx_state = TX_DATA_ST else
                            '0';

  tx_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if eth_payload_tx_ready_i = '1' then
        eth_payload_tx_valid_o <= '0';
      end if;

      case tx_state is

        when TX_IDLE_ST =>
          if tx_m_valid = '1' and eth_payload_tx_valid_o = '0' then
            eth_payload_tx_data_o(R_MAC_SRC_ADDRESS) <= user_src_address_i;
            eth_payload_tx_data_o(R_MAC_DST_ADDRESS) <= user_dst_address_i;
            eth_payload_tx_data_o(R_MAC_PROTOCOL)    <= user_protocol_i;
            eth_payload_tx_valid_o                   <= '1';
            eth_payload_tx_bytes_o                   <= C_MAC_HEADER_LENGTH;
            eth_payload_tx_last_o                    <= '0';

            tx_state <= TX_DATA_ST;
          end if;

        when TX_DATA_ST =>
          if tx_m_valid = '1' and tx_m_ready = '1' then
            eth_payload_tx_valid_o <= '1';
            eth_payload_tx_data_o  <= tx_m_data;
            eth_payload_tx_bytes_o <= tx_m_bytes;
            eth_payload_tx_last_o  <= tx_m_last;

            if tx_m_last = '1' then
              tx_state <= TX_IDLE_ST;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        eth_payload_tx_valid_o <= '0';
        tx_state               <= TX_IDLE_ST;
      end if;
    end if;
  end process tx_proc;


  -------------------------------------
  -- Rx Path
  -------------------------------------

  eth_payload_rx_ready_o <= '1' when user_established_o = '1' and rx_s_valid = '0' else
                            '0';

  rx_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rx_s_ready = '1' then
        rx_s_valid <= '0';
      end if;

      case rx_state is

        when RX_IDLE_ST =>
          if eth_payload_rx_valid_i = '1' and eth_payload_rx_ready_o = '1' then
            -- Verify MAC header
            if eth_payload_rx_data_i(R_MAC_DST_ADDRESS) = C_MAC_BROADCAST or
               eth_payload_rx_data_i(R_MAC_DST_ADDRESS) = user_src_address_i then

              rx_s_valid <= '1';
              rx_s_data  <= eth_payload_rx_data_i;
              rx_s_start <= C_MAC_HEADER_LENGTH;
              rx_s_end   <= minimum(G_ETH_PAYLOAD_BYTES, eth_payload_rx_bytes_i);
              rx_s_last  <= eth_payload_rx_last_i;

              if eth_payload_rx_last_i = '0' then
                rx_state <= RX_DATA_ST;
              end if;
            end if;
          end if;

        when RX_DATA_ST =>
          if eth_payload_rx_valid_i = '1' and eth_payload_rx_ready_o = '1' then
            rx_s_valid <= '1';
            rx_s_data  <= eth_payload_rx_data_i;
            rx_s_start <= 0;
            rx_s_end   <= minimum(G_ETH_PAYLOAD_BYTES, eth_payload_rx_bytes_i);
            rx_s_last  <= eth_payload_rx_last_i;

            if eth_payload_rx_last_i = '1' then
              rx_state <= RX_IDLE_ST;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        rx_s_valid <= '0';
        rx_state   <= RX_IDLE_ST;
      end if;
    end if;
  end process rx_proc;

  axi_pipe_flexible_rx_inst : entity work.axi_pipe_flexible
    generic map (
      G_S_DATA_BYTES => G_ETH_PAYLOAD_BYTES,
      G_M_DATA_BYTES => G_USER_BYTES
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => rx_s_ready,
      s_valid_i => rx_s_valid,
      s_data_i  => rx_s_data,
      s_start_i => rx_s_start,
      s_end_i   => rx_s_end,
      s_last_i  => rx_s_last,
      m_ready_i => user_rx_ready_i,
      m_bytes_i => G_USER_BYTES,
      m_valid_o => user_rx_valid_o,
      m_data_o  => user_rx_data_o,
      m_bytes_o => user_rx_bytes_o,
      m_last_o  => user_rx_last_o
    ); -- axi_pipe_flexible_rx_inst : entity work.axi_pipe_flexible

end architecture synthesis;


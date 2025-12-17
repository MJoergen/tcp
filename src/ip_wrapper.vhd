library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This module strips away the 20 byte IP header, and forwards the remaining.

entity ip_wrapper is
  generic (
    G_SIM_NAME          : string;  -- Used in simulation
    G_MAC_PAYLOAD_BYTES : natural; -- Width of IP payload data interface
    G_USER_BYTES        : natural  -- Width of session data interface
  );
  port (
    clk_i                  : in    std_logic;
    rst_i                  : in    std_logic;

    -- User control interface
    user_start_i           : in    std_logic;
    user_src_address_i     : in    std_logic_vector(31 downto 0);
    user_dst_address_i     : in    std_logic_vector(31 downto 0);
    user_protocol_i        : in    std_logic_vector(7 downto 0);
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
    mac_payload_rx_ready_o : out   std_logic;
    mac_payload_rx_valid_i : in    std_logic;
    mac_payload_rx_data_i  : in    std_logic_vector(G_MAC_PAYLOAD_BYTES * 8 - 1 downto 0);
    mac_payload_rx_bytes_i : in    natural range 0 to G_MAC_PAYLOAD_BYTES;
    mac_payload_rx_last_i  : in    std_logic;
    --
    mac_payload_tx_ready_i : in    std_logic;
    mac_payload_tx_valid_o : out   std_logic;
    mac_payload_tx_data_o  : out   std_logic_vector(G_MAC_PAYLOAD_BYTES * 8 - 1 downto 0);
    mac_payload_tx_bytes_o : out   natural range 0 to G_MAC_PAYLOAD_BYTES;
    mac_payload_tx_last_o  : out   std_logic
  );
end entity ip_wrapper;

architecture synthesis of ip_wrapper is

  subtype  R_IP_VIHL is natural range 8 * 1 - 1 downto 8 * 0;

  subtype  R_IP_DSCP is natural range 8 * 2 - 1 downto 8 * 1;

  subtype  R_IP_LENGTH is natural range 8 * 4 - 1 downto 8 * 2;

  subtype  R_IP_ID is natural range 8 * 6 - 1 downto 8 * 4;

  subtype  R_IP_FRAGMENT is natural range 8 * 8 - 1 downto 8 * 6;

  subtype  R_IP_TTL is natural range 8 * 9 - 1 downto 8 * 8;

  subtype  R_IP_PROTOCOL is natural range 8 * 10 - 1 downto 8 * 9;

  subtype  R_IP_CHECKSUM is natural range 8 * 12 - 1 downto 8 * 10;

  subtype  R_IP_SRC_ADDRESS is natural range 8 * 16 - 1 downto 8 * 12;

  subtype  R_IP_DST_ADDRESS is natural range 8 * 20 - 1 downto 8 * 16;

  constant C_IP_HEADER_LENGTH : natural := 20;


  -- Connection state
  type     state_type is (IDLE_ST, ACTIVE_ST);
  signal   state : state_type           := IDLE_ST;

  signal   user_protocol    : std_logic_vector(7 downto 0);
  signal   user_src_address : std_logic_vector(31 downto 0);
  signal   user_dst_address : std_logic_vector(31 downto 0);


  -- Tx path
  signal   user_tx_ready : std_logic;
  signal   user_tx_valid : std_logic;

  type     tx_state_type is (TX_IDLE_ST, TX_DATA_ST);
  signal   tx_state : tx_state_type     := TX_IDLE_ST;

  signal   tx_m_ready : std_logic;
  signal   tx_m_valid : std_logic;
  signal   tx_m_data  : std_logic_vector(G_MAC_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   tx_m_bytes : natural range 0 to G_MAC_PAYLOAD_BYTES;
  signal   tx_m_last  : std_logic;


  -- Rx path
  type     rx_state_type is (RX_IDLE_ST, RX_DATA_ST);
  signal   rx_state : rx_state_type     := RX_IDLE_ST;

  signal   rx_s_ready : std_logic;
  signal   rx_s_valid : std_logic;
  signal   rx_s_data  : std_logic_vector(G_MAC_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   rx_s_start : natural range 0 to G_MAC_PAYLOAD_BYTES - 1;
  signal   rx_s_end   : natural range 0 to G_MAC_PAYLOAD_BYTES;
  signal   rx_s_last  : std_logic;

begin

  assert G_MAC_PAYLOAD_BYTES > C_IP_HEADER_LENGTH;


  -------------------------------------
  -- Connection state
  -------------------------------------

  state_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then

      case state is

        when IDLE_ST =>
          if user_start_i = '1' then
            user_protocol    <= user_protocol_i;
            user_src_address <= user_src_address_i;
            user_dst_address <= user_dst_address_i;
            state            <= ACTIVE_ST;
          end if;

        when ACTIVE_ST =>
          if user_start_i = '0' then
            user_protocol    <= (others => '0');
            user_src_address <= (others => '0');
            user_dst_address <= (others => '0');
            state            <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        user_protocol    <= (others => '0');
        user_src_address <= (others => '0');
        user_dst_address <= (others => '0');
        state            <= IDLE_ST;
      end if;
    end if;
  end process state_proc;

  user_established_o <= '1' when state = ACTIVE_ST else
                        '0';


  -------------------------------------
  -- Tx Path
  -------------------------------------

  user_tx_ready_o    <= user_tx_ready when state = ACTIVE_ST else
                        '0';
  user_tx_valid      <= user_tx_valid_i when state = ACTIVE_ST else
                        '0';

  axi_pipe_flexible_tx_inst : entity work.axi_pipe_flexible
    generic map (
      G_S_DATA_BYTES => G_USER_BYTES,
      G_M_DATA_BYTES => G_MAC_PAYLOAD_BYTES
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => user_tx_ready,
      s_valid_i => user_tx_valid,
      s_data_i  => user_tx_data_i,
      s_start_i => 0,
      s_end_i   => user_tx_bytes_i,
      s_last_i  => user_tx_last_i,
      m_ready_i => tx_m_ready,
      m_bytes_i => G_MAC_PAYLOAD_BYTES,
      m_valid_o => tx_m_valid,
      m_data_o  => tx_m_data,
      m_bytes_o => tx_m_bytes,
      m_last_o  => tx_m_last
    ); -- axi_pipe_flexible_tx_inst : entity work.axi_pipe_flexible

  tx_m_ready             <= (mac_payload_tx_ready_i or not mac_payload_tx_valid_o) when tx_state = TX_DATA_ST else
                            '0';


  tx_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if mac_payload_tx_ready_i = '1' then
        mac_payload_tx_valid_o <= '0';
      end if;

      case tx_state is

        when TX_IDLE_ST =>
          if tx_m_valid = '1' and (mac_payload_tx_ready_i = '1' or mac_payload_tx_valid_o = '0') then
            mac_payload_tx_data_o(R_IP_SRC_ADDRESS) <= user_src_address;
            mac_payload_tx_data_o(R_IP_DST_ADDRESS) <= user_dst_address;
            mac_payload_tx_data_o(R_IP_PROTOCOL)    <= user_protocol;
            mac_payload_tx_bytes_o                  <= C_IP_HEADER_LENGTH;
            mac_payload_tx_last_o                   <= '0';
            mac_payload_tx_valid_o                  <= '1';
            tx_state                                <= TX_DATA_ST;
          end if;

        when TX_DATA_ST =>
          if tx_m_valid = '1' and tx_m_ready = '1' then
            mac_payload_tx_data_o  <= tx_m_data;
            mac_payload_tx_bytes_o <= tx_m_bytes;
            mac_payload_tx_last_o  <= tx_m_last;
            mac_payload_tx_valid_o <= '1';
            if tx_m_last = '1' then
              tx_state <= TX_IDLE_ST;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        mac_payload_tx_data_o  <= (others => '0');
        mac_payload_tx_last_o  <= '0';
        mac_payload_tx_valid_o <= '0';
        tx_state               <= TX_IDLE_ST;
      end if;
    end if;
  end process tx_proc;


  -------------------------------------
  -- Rx Path
  -------------------------------------

  mac_payload_rx_ready_o <= (rx_s_ready or not rx_s_valid) when state = ACTIVE_ST else
                            '0';

  rx_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rx_s_ready = '1' then
        rx_s_valid <= '0';
      end if;

      case rx_state is

        when RX_IDLE_ST =>
          if mac_payload_rx_valid_i = '1' and mac_payload_rx_ready_o = '1' then
            if mac_payload_rx_data_i(R_IP_DST_ADDRESS) = user_src_address and
               mac_payload_rx_data_i(R_IP_PROTOCOL) = user_protocol then

              rx_s_valid <= '1';
              rx_s_data  <= mac_payload_rx_data_i;
              rx_s_start <= C_IP_HEADER_LENGTH;                                   -- TBD: Add options
              rx_s_end   <= minimum(G_IP_PAYLOAD_BYTES, mac_payload_rx_bytes_i);  -- TBD: Correct for IP packet length
              rx_s_last  <= mac_payload_rx_last_i;

              if mac_payload_rx_last_i = '0' then
                rx_state <= RX_DATA_ST;
              end if;
            end if;
          end if;

        when RX_DATA_ST =>
          if mac_payload_rx_valid_i = '1' and mac_payload_rx_ready_o = '1' then
            rx_s_valid <= '1';
            rx_s_data  <= mac_payload_rx_data_i;
            rx_s_start <= 0;
            rx_s_end   <= minimum(G_IP_PAYLOAD_BYTES, mac_payload_rx_bytes_i);    -- TBD: Correct for IP packet length
            rx_s_last  <= mac_payload_rx_last_i;

            if mac_payload_rx_last_i = '1' then
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
      G_S_DATA_BYTES => G_MAC_PAYLOAD_BYTES,
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


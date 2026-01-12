library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This module strips away the 14 byte MAC header, and forwards the remaining.
-- Data is left-aligned.
-- When 'last' is 0 then 'bytes' is ignored (i.e. assumed to be G_BYTES).

entity mac_handler is
  generic (
    G_SIM_NAME : string; -- Used in simulation
    G_BYTES    : natural -- Width of data interface
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
    user_rx_data_o         : out   std_logic_vector(G_BYTES * 8 - 1 downto 0);
    user_rx_last_o         : out   std_logic;
    user_rx_bytes_o        : out   natural range 0 to G_BYTES;
    --
    user_tx_ready_o        : out   std_logic;
    user_tx_valid_i        : in    std_logic;
    user_tx_data_i         : in    std_logic_vector(G_BYTES * 8 - 1 downto 0);
    user_tx_last_i         : in    std_logic;
    user_tx_bytes_i        : in    natural range 0 to G_BYTES;

    -- Interface to Ethernet handler (packet oriented)
    eth_payload_rx_ready_o : out   std_logic;
    eth_payload_rx_valid_i : in    std_logic;
    eth_payload_rx_data_i  : in    std_logic_vector(G_BYTES * 8 - 1 downto 0);
    eth_payload_rx_last_i  : in    std_logic;
    eth_payload_rx_bytes_i : in    natural range 0 to G_BYTES;
    --
    eth_payload_tx_ready_i : in    std_logic;
    eth_payload_tx_valid_o : out   std_logic;
    eth_payload_tx_data_o  : out   std_logic_vector(G_BYTES * 8 - 1 downto 0);
    eth_payload_tx_last_o  : out   std_logic;
    eth_payload_tx_bytes_o : out   natural range 0 to G_BYTES
  );
end entity mac_handler;

architecture synthesis of mac_handler is

  constant C_MAC_HEADER_LENGTH : natural                       := 14;
  constant C_MAC_BROADCAST     : std_logic_vector(47 downto 0) := x"FFFFFFFFFFFF";

  subtype  R_MAC_DST_ADDRESS is natural range 8 * C_MAC_HEADER_LENGTH - 1 downto 8 * (C_MAC_HEADER_LENGTH - 6);

  subtype  R_MAC_SRC_ADDRESS is natural range 8 * (C_MAC_HEADER_LENGTH - 6) - 1 downto 8 * (C_MAC_HEADER_LENGTH - 12);

  subtype  R_MAC_PROTOCOL is natural range 8 * (C_MAC_HEADER_LENGTH - 12) - 1 downto 8 * (C_MAC_HEADER_LENGTH - 14);


  -------------------------------------
  -- Connection state
  -------------------------------------

  type     state_type is (IDLE_ST, ACTIVE_ST);
  signal   state : state_type                                  := IDLE_ST;

  signal   user_protocol    : std_logic_vector(15 downto 0);
  signal   user_src_address : std_logic_vector(47 downto 0);
  signal   user_dst_address : std_logic_vector(47 downto 0);


  -------------------------------------
  -- Tx path
  -------------------------------------

  signal   user_tx_ready : std_logic;
  signal   user_tx_valid : std_logic;

  signal   tx_h_ready : std_logic;
  signal   tx_h_valid : std_logic;
  signal   tx_h_data  : std_logic_vector(C_MAC_HEADER_LENGTH * 8 - 1 downto 0);


  -------------------------------------
  -- Rx path
  -------------------------------------

  type     rx_state_type is (RX_IDLE_ST, RX_FORWARD_ST);
  signal   rx_state : rx_state_type                            := RX_IDLE_ST;

  signal   user_rx_ready : std_logic;
  signal   user_rx_valid : std_logic;

  signal   mac_rx_ready : std_logic;
  signal   mac_rx_valid : std_logic;
  signal   mac_rx_data  : std_logic_vector(C_MAC_HEADER_LENGTH * 8 - 1 downto 0);

begin

  assert G_BYTES > C_MAC_HEADER_LENGTH;


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

  user_established_o           <= '1' when state = ACTIVE_ST else
                                  '0';


  -------------------------------------
  -- Tx Path
  -------------------------------------

  user_tx_ready_o              <= user_tx_ready and user_established_o;
  user_tx_valid                <= user_tx_valid_i and user_established_o;

  tx_h_data(R_MAC_DST_ADDRESS) <= user_dst_address;
  tx_h_data(R_MAC_SRC_ADDRESS) <= user_src_address;
  tx_h_data(R_MAC_PROTOCOL)    <= user_protocol;
  tx_h_valid                   <= user_established_o;

  axip_insert_fixed_header_inst : entity work.axip_insert_fixed_header
    generic map (
      G_DATA_BYTES   => G_BYTES,
      G_HEADER_BYTES => C_MAC_HEADER_LENGTH
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      h_ready_o => tx_h_ready, -- ignore
      h_valid_i => tx_h_valid,
      h_data_i  => tx_h_data,
      s_ready_o => user_tx_ready,
      s_valid_i => user_tx_valid,
      s_data_i  => user_tx_data_i,
      s_last_i  => user_tx_last_i,
      s_bytes_i => user_tx_bytes_i,
      m_ready_i => eth_payload_tx_ready_i,
      m_valid_o => eth_payload_tx_valid_o,
      m_data_o  => eth_payload_tx_data_o,
      m_last_o  => eth_payload_tx_last_o,
      m_bytes_o => eth_payload_tx_bytes_o
    ); -- axip_insert_fixed_header_inst : entity work.axip_insert_fixed_header


  -------------------------------------
  -- Rx Path
  -------------------------------------

  axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header
    generic map (
      G_DATA_BYTES   => G_BYTES,
      G_HEADER_BYTES => C_MAC_HEADER_LENGTH
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => eth_payload_rx_ready_o,
      s_valid_i => eth_payload_rx_valid_i,
      s_data_i  => eth_payload_rx_data_i,
      s_last_i  => eth_payload_rx_last_i,
      s_bytes_i => eth_payload_rx_bytes_i,
      m_ready_i => user_rx_ready,
      m_valid_o => user_rx_valid,
      m_data_o  => user_rx_data_o,
      m_last_o  => user_rx_last_o,
      m_bytes_o => user_rx_bytes_o,
      h_ready_i => mac_rx_ready,
      h_valid_o => mac_rx_valid,
      h_data_o  => mac_rx_data
    ); -- axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header

  mac_rx_ready    <= '1';

  rx_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then

      case rx_state is

        when RX_IDLE_ST =>
          if mac_rx_valid = '1' and mac_rx_ready = '1' then
            -- Verify MAC header
            if mac_rx_data(R_MAC_DST_ADDRESS) = C_MAC_BROADCAST or
               mac_rx_data(R_MAC_DST_ADDRESS) = user_src_address_i then
              rx_state <= RX_FORWARD_ST;
            end if;
          end if;

        when RX_FORWARD_ST =>
          if user_rx_valid = '1' and user_rx_ready = '1' then
            if user_rx_last_o = '1' then
              rx_state <= RX_IDLE_ST;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        rx_state <= RX_IDLE_ST;
      end if;
    end if;
  end process rx_proc;

  user_rx_ready   <= user_rx_ready_i when rx_state = RX_FORWARD_ST else
                     '0';
  user_rx_valid_o <= user_rx_valid when rx_state = RX_FORWARD_ST else
                     '0';

end architecture synthesis;


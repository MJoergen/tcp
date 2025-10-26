library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This is a top level TCP handler.
-- If dst_port_i is 0 then it opens a LISTENING session.

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
    -- User data interface (byte oriented)
    user_rx_ready_i        : in    std_logic;
    user_rx_valid_o        : out   std_logic;
    user_rx_data_o         : out   std_logic_vector(G_USER_BYTES * 8 - 1 downto 0);
    user_rx_bytes_o        : out   natural range 0 to G_USER_BYTES;
    --
    user_tx_ready_o        : out   std_logic;
    user_tx_valid_i        : in    std_logic;
    user_tx_data_i         : in    std_logic_vector(G_USER_BYTES * 8 - 1 downto 0);
    user_tx_bytes_i        : in    natural range 0 to G_USER_BYTES;

    -- Interface to MAC handler (packet oriented)
    -- bits 7-0 is the first byte transferred.
    -- bytes = 0 means G_MAC_PAYLOAD_BYTES.
    mac_payload_rx_ready_o : out   std_logic;
    mac_payload_rx_valid_i : in    std_logic;
    mac_payload_rx_data_i  : in    std_logic_vector(G_MAC_PAYLOAD_BYTES * 8 - 1 downto 0);
    mac_payload_rx_bytes_i : in    natural range 0 to G_MAC_PAYLOAD_BYTES - 1;
    mac_payload_rx_last_i  : in    std_logic;
    --
    mac_payload_tx_ready_i : in    std_logic;
    mac_payload_tx_valid_o : out   std_logic;
    mac_payload_tx_data_o  : out   std_logic_vector(G_MAC_PAYLOAD_BYTES * 8 - 1 downto 0);
    mac_payload_tx_bytes_o : out   natural range 0 to G_MAC_PAYLOAD_BYTES - 1;
    mac_payload_tx_last_o  : out   std_logic
  );
end entity ip_wrapper;

architecture synthesis of ip_wrapper is

  type    state_type is (IDLE_ST, ACTIVE_ST);
  signal  state : state_type := IDLE_ST;

  signal  user_protocol    : std_logic_vector(7 downto 0);
  signal  user_src_address : std_logic_vector(31 downto 0);
  signal  user_dst_address : std_logic_vector(31 downto 0);

  subtype R_IP_SRC_ADDRESS is natural range 8 * 4 - 1 downto 8 * 0;

  subtype R_IP_DST_ADDRESS is natural range 8 * 8 - 1 downto 8 * 4;

  subtype R_IP_PROTOCOL is natural range 8 * 9 - 1 downto 8 * 8;

  constant C_IP_HEADER_LENGTH : natural := 20;

  signal  squash_s_ready : std_logic;
  signal  squash_s_valid : std_logic;
  signal  squash_s_data  : std_logic_vector(G_MAC_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal  squash_s_start : natural range 0 to G_MAC_PAYLOAD_BYTES-1;
  signal  squash_s_end   : natural range 0 to G_MAC_PAYLOAD_BYTES;
  signal  squash_s_push  : std_logic;  -- Force empty of internal buffer

begin

  state_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if mac_payload_tx_ready_i = '1' then
        mac_payload_tx_valid_o <= '0';
      end if;

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
        mac_payload_tx_valid_o <= '0';
        user_protocol          <= (others => '0');
        user_src_address       <= (others => '0');
        user_dst_address       <= (others => '0');
        state                  <= IDLE_ST;
      end if;
    end if;
  end process state_proc;


  user_tx_ready_o <= '1' when state = ACTIVE_ST else
                     '0';

  rx_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if user_rx_ready_i = '1' then
        user_rx_valid_o <= '0';
      end if;

      if squash_s_ready = '1' then
        squash_s_valid <= '0';
      end if;

      if mac_payload_rx_valid_i = '1' and mac_payload_rx_ready_o = '1' then
        if mac_payload_rx_data_i(R_IP_DST_ADDRESS) = user_src_address and
           mac_payload_rx_data_i(R_IP_PROTOCOL) = user_protocol then
          squash_s_valid <= '1';
          squash_s_data  <= mac_payload_rx_data_i;
          squash_s_start <= C_IP_HEADER_LENGTH;                             -- TBD: Add options
          squash_s_end   <= G_USER_BYTES;                                   -- TBD: Correct for IP packet length
          squash_s_push  <= '1';
        end if;
      end if;

      if rst_i = '1' then
        user_rx_valid_o <= '0';
      end if;
    end if;
  end process rx_proc;

  axi_fifo_squash_inst : entity work.axi_fifo_squash
    generic map (
      G_S_DATA_BYTES => G_MAC_PAYLOAD_BYTES,
      G_M_DATA_BYTES => G_USER_BYTES
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => squash_s_ready,
      s_valid_i => squash_s_valid,
      s_data_i  => squash_s_data,
      s_start_i => squash_s_start,
      s_end_i   => squash_s_end,
      s_push_i  => squash_s_push,
      m_ready_i => user_rx_ready_i,
      m_valid_o => user_rx_valid_o,
      m_data_o  => user_rx_data_o,
      m_bytes_o => user_rx_bytes_o,
      m_empty_o => open
    ); -- axi_fifo_squash_inst : entity work.axi_fifo_squash

end architecture synthesis;


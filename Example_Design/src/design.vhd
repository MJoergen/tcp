library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity design is
  port (
    clk_i           : in    std_logic;
    rst_i           : in    std_logic;
    uart_rx_ready_o : out   std_logic;
    uart_rx_valid_i : in    std_logic;
    uart_rx_data_i  : in    std_logic_vector(7 downto 0);
    uart_tx_ready_i : in    std_logic;
    uart_tx_valid_o : out   std_logic;
    uart_tx_data_o  : out   std_logic_vector(7 downto 0);
    key_num_i       : in    integer range 0 to 79;
    key_pressed_n_i : in    std_logic;
    eth_rx_ready_o  : out   std_logic;
    eth_rx_valid_i  : in    std_logic;
    eth_rx_data_i   : in    std_logic_vector(7 downto 0);
    eth_rx_last_i   : in    std_logic;
    eth_tx_ready_i  : in    std_logic;
    eth_tx_valid_o  : out   std_logic;
    eth_tx_data_o   : out   std_logic_vector(7 downto 0);
    eth_tx_last_o   : out   std_logic;
    vga_addr_o      : out   std_logic_vector(15 downto 0);
    vga_data_o      : out   std_logic_vector(23 downto 0);
    vga_wren_o      : out   std_logic
  );
end entity design;

architecture synthesis of design is

  constant C_ETH_BYTES  : natural   := 60;
  constant C_USER_BYTES : natural   := 46;

  signal   mac_user_start       : std_logic;
  signal   mac_user_src_address : std_logic_vector(47 downto 0); -- MAC address
  signal   mac_user_dst_address : std_logic_vector(47 downto 0); -- MAC address
  signal   mac_user_protocol    : std_logic_vector(15 downto 0); -- MAC protocol
  signal   mac_user_established : std_logic;

  signal   cmd_ready : std_logic;
  signal   cmd_valid : std_logic;
  signal   cmd_data  : std_logic_vector(7 downto 0);

  signal   mac_user_rx_ready : std_logic;
  signal   mac_user_rx_valid : std_logic;
  signal   mac_user_rx_data  : std_logic_vector(C_USER_BYTES * 8 - 1 downto 0);
  signal   mac_user_rx_bytes : natural range 0 to C_USER_BYTES;
  signal   mac_user_rx_last  : std_logic;
  signal   mac_user_tx_ready : std_logic;
  signal   mac_user_tx_valid : std_logic;
  signal   mac_user_tx_data  : std_logic_vector(C_USER_BYTES * 8 - 1 downto 0);
  signal   mac_user_tx_bytes : natural range 0 to C_USER_BYTES;
  signal   mac_user_tx_last  : std_logic;

  signal   eth_rx_wide_ready : std_logic;
  signal   eth_rx_wide_valid : std_logic;
  signal   eth_rx_wide_last  : std_logic;
  signal   eth_rx_wide_bytes : natural range 0 to C_ETH_BYTES;
  signal   eth_rx_wide_data  : std_logic_vector(C_ETH_BYTES * 8 - 1 downto 0);
  signal   eth_tx_wide_ready : std_logic;
  signal   eth_tx_wide_valid : std_logic;
  signal   eth_tx_wide_last  : std_logic;
  signal   eth_tx_wide_bytes : natural range 0 to C_ETH_BYTES;
  signal   eth_tx_wide_data  : std_logic_vector(C_ETH_BYTES * 8 - 1 downto 0);

  signal   mac_user_rx_byte_ready  : std_logic;
  signal   mac_user_rx_byte_valid  : std_logic;
  signal   mac_user_rx_byte_data   : std_logic_vector(7 downto 0);
  signal   mac_user_rx_byte_last   : std_logic;
  signal   mac_user_rx_byte_data_d : std_logic_vector(7 downto 0);
  signal   mac_user_rx_byte_last_d : std_logic;

  type     rx_state_type is (RX_IDLE_ST, RX_BUSY_ST, RX_LAST_ST, RX_CLEAR_ST);
  signal   rx_state : rx_state_type := RX_IDLE_ST;

begin

  --------------------------------------------------
  -- Instantiate controller
  --------------------------------------------------

  controller_inst : entity work.controller
    port map (
      clk_i           => clk_i,
      rst_i           => rst_i,
      uart_rx_ready_o => uart_rx_ready_o,
      uart_rx_valid_i => uart_rx_valid_i,
      uart_rx_data_i  => uart_rx_data_i,
      uart_tx_ready_i => uart_tx_ready_i,
      uart_tx_valid_o => uart_tx_valid_o,
      uart_tx_data_o  => uart_tx_data_o,
      key_num_i       => key_num_i,
      key_pressed_n_i => key_pressed_n_i,
      cmd_ready_i     => cmd_ready,
      cmd_valid_o     => cmd_valid,
      cmd_data_o      => cmd_data
    ); -- controller_inst : entity work.controller


  --------------------------------------------------
  -- Session processor
  --------------------------------------------------

  mac_user_start       <= '1';
  mac_user_src_address <= x"223344556677";
  mac_user_dst_address <= x"887766554433";
  mac_user_protocol    <= x"0800";


  --------------------------------------------------
  -- Command processor
  --------------------------------------------------

  cmd_ready            <= mac_user_established and (mac_user_tx_ready or not mac_user_tx_valid);

  cmd_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if mac_user_tx_ready = '1' then
        mac_user_tx_valid <= '0';
      end if;

      if cmd_valid = '1' and cmd_ready = '1' then
        mac_user_tx_valid <= '1';
        mac_user_tx_last  <= '1';
        mac_user_tx_bytes <= 46;
        mac_user_tx_data  <= x"1122334455667788" &
                             x"1122334455667789" &
                             x"112233445566778A" &
                             x"112233445566778B" &
                             x"112233445566778C" &
                             x"112233445566";
      end if;

      if rst_i = '1' then
        mac_user_tx_valid <= '0';
      end if;
    end if;
  end process cmd_proc;


  --------------------------------------------------
  -- MAC wrapper
  --------------------------------------------------

  mac_wrapper_inst : entity work.mac_wrapper
    generic map (
      G_SIM_NAME          => "DESIGN",
      G_ETH_PAYLOAD_BYTES => C_ETH_BYTES,
      G_USER_BYTES        => C_USER_BYTES
    )
    port map (
      clk_i                  => clk_i,
      rst_i                  => rst_i,
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
      eth_payload_rx_ready_o => eth_rx_wide_ready,
      eth_payload_rx_valid_i => eth_rx_wide_valid,
      eth_payload_rx_data_i  => eth_rx_wide_data,
      eth_payload_rx_bytes_i => eth_rx_wide_bytes,
      eth_payload_rx_last_i  => eth_rx_wide_last,
      eth_payload_tx_ready_i => eth_tx_wide_ready,
      eth_payload_tx_valid_o => eth_tx_wide_valid,
      eth_payload_tx_data_o  => eth_tx_wide_data,
      eth_payload_tx_bytes_o => eth_tx_wide_bytes,
      eth_payload_tx_last_o  => eth_tx_wide_last
    ); -- mac_wrapper_inst : entity work.mac_wrapper

  wide2byte_inst : entity work.wide2byte
    generic map (
      G_BYTES => C_ETH_BYTES
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => eth_tx_wide_ready,
      s_valid_i => eth_tx_wide_valid,
      s_last_i  => eth_tx_wide_last,
      s_bytes_i => eth_tx_wide_bytes,
      s_data_i  => eth_tx_wide_data,
      m_ready_i => eth_tx_ready_i,
      m_valid_o => eth_tx_valid_o,
      m_last_o  => eth_tx_last_o,
      m_data_o  => eth_tx_data_o
    ); -- wide2byte_inst : entity work.wide2byte

  byte2wide_inst : entity work.byte2wide
    generic map (
      G_BYTES => C_ETH_BYTES
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => eth_rx_ready_o,
      s_valid_i => eth_rx_valid_i,
      s_last_i  => eth_rx_last_i,
      s_data_i  => eth_rx_data_i,
      m_ready_i => eth_rx_wide_ready,
      m_valid_o => eth_rx_wide_valid,
      m_last_o  => eth_rx_wide_last,
      m_data_o  => eth_rx_wide_data,
      m_bytes_o => eth_rx_wide_bytes
    ); -- byte2wide_inst : entity work.byte2wide


  --------------------------------------------------
  -- Receive path
  --------------------------------------------------

  wide2byte_rx_inst : entity work.wide2byte
    generic map (
      G_BYTES => C_USER_BYTES
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => mac_user_rx_ready,
      s_valid_i => mac_user_rx_valid,
      s_last_i  => mac_user_rx_last,
      s_bytes_i => mac_user_rx_bytes,
      s_data_i  => mac_user_rx_data,
      m_ready_i => mac_user_rx_byte_ready,
      m_valid_o => mac_user_rx_byte_valid,
      m_last_o  => mac_user_rx_byte_last,
      m_data_o  => mac_user_rx_byte_data
    ); -- wide2byte_rx_inst : entity work.wide2byte

  mac_user_rx_byte_ready <= '1' when rx_state = RX_IDLE_ST else
                            '0';

  vga_proc : process (clk_i)
    --

    pure function to_hex (
      arg : std_logic_vector
    ) return std_logic_vector is
    begin
      if arg < 10 then
        return to_stdlogicvector(to_integer(arg) + character'pos('0'), 8);
      else
        return to_stdlogicvector(to_integer(arg) - 10 + character'pos('A'), 8);
      end if;
    end function to_hex;

  --
  begin
    if rising_edge(clk_i) then
      vga_wren_o <= '0';

      case rx_state is

        when RX_IDLE_ST =>
          if mac_user_rx_byte_valid = '1' then
            mac_user_rx_byte_data_d <= mac_user_rx_byte_data;
            mac_user_rx_byte_last_d <= mac_user_rx_byte_last;

            vga_data_o              <= x"CC44" & to_hex(mac_user_rx_byte_data(7 downto 4));
            vga_wren_o              <= '1';
            rx_state                <= RX_BUSY_ST;
          end if;

        when RX_BUSY_ST =>
          vga_addr_o <= vga_addr_o + 1;
          vga_data_o <= x"CC44" & to_hex(mac_user_rx_byte_data_d(3 downto 0));
          vga_wren_o <= '1';
          rx_state   <= RX_LAST_ST;

        when RX_LAST_ST =>
          if mac_user_rx_byte_last_d = '1' then
            vga_addr_o <= (vga_addr_o and x"FF00") + x"0200";
          elsif vga_addr_o(7 downto 0) = 159 then
            vga_addr_o <= (vga_addr_o and x"FF00") + x"0100";
          else
            vga_addr_o <= vga_addr_o + 1;
          end if;
          rx_state <= RX_IDLE_ST;

        when RX_CLEAR_ST =>
          vga_addr_o <= vga_addr_o + 1;
          vga_data_o <= x"FFFFFF";
          vga_wren_o <= '1';

          if vga_addr_o = x"FFFE" then
            vga_addr_o <= x"0000";
            rx_state   <= RX_IDLE_ST;
          end if;

      end case;

      if cmd_valid = '1' and cmd_ready = '1' and (cmd_data = x"43" or cmd_data = x"63") then
        vga_addr_o <= x"FFFF";
        rx_state   <= RX_CLEAR_ST;
      end if;

      if rst_i = '1' then
        mac_user_rx_byte_last_d <= '0';
        vga_addr_o              <= x"0000";
        vga_data_o              <= x"000000";
        vga_wren_o              <= '0';
        rx_state                <= RX_IDLE_ST;
      end if;
    end if;
  end process vga_proc;

end architecture synthesis;


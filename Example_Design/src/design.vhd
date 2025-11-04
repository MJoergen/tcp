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
    eth_rx_ready_o  : out   std_logic;
    eth_rx_valid_i  : in    std_logic;
    eth_rx_data_i   : in    std_logic_vector(7 downto 0);
    eth_rx_last_i   : in    std_logic;
    eth_tx_ready_i  : in    std_logic;
    eth_tx_valid_o  : out   std_logic;
    eth_tx_data_o   : out   std_logic_vector(7 downto 0);
    eth_tx_last_o   : out   std_logic;
    vga_addr_o      : out   std_logic_vector(15 downto 0);
    vga_data_o      : out   std_logic_vector(7 downto 0);
    vga_wren_o      : out   std_logic
  );
end entity design;

architecture synthesis of design is

  constant C_ETH_BYTES  : natural := 16;
  constant C_USER_BYTES : natural := 4;

  signal   mac_user_start       : std_logic;
  signal   mac_user_src_address : std_logic_vector(47 downto 0); -- MAC address
  signal   mac_user_dst_address : std_logic_vector(47 downto 0); -- MAC address
  signal   mac_user_protocol    : std_logic_vector(15 downto 0); -- MAC protocol
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

  signal   eth_rx_data : std_logic_vector(7 downto 0);
  signal   eth_rx_last : std_logic;

  type     state_type is (IDLE_ST, BUSY_ST, LAST_ST);
  signal   state : state_type     := IDLE_ST;

begin

  -- Loopback
  uart_rx_ready_o <= uart_tx_ready_i;
  uart_tx_valid_o <= uart_rx_valid_i;
  uart_tx_data_o  <= uart_rx_data_i;


  eth_tx_valid_o  <= '0';

  --  byte2wide_inst : entity work.byte2wide
  --    generic map (
  --      G_BYTES => C_ETH_BYTES
  --    )
  --    port map (
  --      clk_i     => clk_i,
  --      rst_i     => rst_i,
  --      s_ready_o => eth_rx_ready_o,
  --      s_valid_i => eth_rx_valid_i,
  --      s_last_i  => eth_rx_last_i,
  --      s_data_i  => eth_rx_data_i,
  --      m_ready_i => eth_rx_wide_ready,
  --      m_valid_o => eth_rx_wide_valid,
  --      m_last_o  => eth_rx_wide_last,
  --      m_data_o  => eth_rx_wide_data,
  --      m_bytes_o => eth_rx_wide_bytes
  --    ); -- byte2wide_inst : entity work.byte2wide
  --
  --  wide2byte_inst : entity work.wide2byte
  --    generic map (
  --      G_BYTES => C_ETH_BYTES
  --    )
  --    port map (
  --      clk_i     => clk_i,
  --      rst_i     => rst_i,
  --      s_ready_o => eth_tx_wide_ready,
  --      s_valid_i => eth_tx_wide_valid,
  --      s_last_i  => eth_tx_wide_last,
  --      s_bytes_i => eth_tx_wide_bytes,
  --      s_data_i  => eth_tx_wide_data,
  --      m_ready_i => eth_tx_ready_i,
  --      m_valid_o => eth_tx_valid_o,
  --      m_last_o  => eth_tx_last_o,
  --      m_data_o  => eth_tx_data_o
  --    ); -- wide2byte_inst : entity work.wide2byte
  --
  --  mac_wrapper_inst : entity work.mac_wrapper
  --    generic map (
  --      G_SIM_NAME          => "",
  --      G_ETH_PAYLOAD_BYTES => C_ETH_BYTES,
  --      G_USER_BYTES        => C_USER_BYTES
  --    )
  --    port map (
  --      clk_i                  => clk_i,
  --      rst_i                  => rst_i,
  --      user_start_i           => mac_user_start,
  --      user_src_address_i     => mac_user_src_address,
  --      user_dst_address_i     => mac_user_dst_address,
  --      user_protocol_i        => mac_user_protocol,
  --      user_established_o     => mac_user_established,
  --      user_rx_ready_i        => mac_user_rx_ready,
  --      user_rx_valid_o        => mac_user_rx_valid,
  --      user_rx_data_o         => mac_user_rx_data,
  --      user_rx_bytes_o        => mac_user_rx_bytes,
  --      user_rx_last_o         => mac_user_rx_last,
  --      user_tx_ready_o        => mac_user_tx_ready,
  --      user_tx_valid_i        => mac_user_tx_valid,
  --      user_tx_data_i         => mac_user_tx_data,
  --      user_tx_bytes_i        => mac_user_tx_bytes,
  --      user_tx_last_i         => mac_user_tx_last,
  --      eth_payload_rx_ready_o => eth_rx_wide_ready,
  --      eth_payload_rx_valid_i => eth_rx_wide_valid,
  --      eth_payload_rx_data_i  => eth_rx_wide_data,
  --      eth_payload_rx_bytes_i => eth_rx_wide_bytes,
  --      eth_payload_rx_last_i  => eth_rx_wide_last,
  --      eth_payload_tx_ready_i => eth_tx_wide_ready,
  --      eth_payload_tx_valid_o => eth_tx_wide_valid,
  --      eth_payload_tx_data_o  => eth_tx_wide_data,
  --      eth_payload_tx_bytes_o => eth_tx_wide_bytes,
  --      eth_payload_tx_last_o  => eth_tx_wide_last
  --    ); -- mac_wrapper_inst : entity work.mac_wrapper

  eth_rx_ready_o  <= '1' when state = IDLE_ST else
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

  begin
    if rising_edge(clk_i) then
      vga_wren_o <= '0';

      case state is

        when IDLE_ST =>
          if eth_rx_valid_i = '1' then
            eth_rx_data <= eth_rx_data_i;
            eth_rx_last <= eth_rx_last_i;

            vga_addr_o  <= vga_addr_o + 1;
            vga_data_o  <= to_hex(eth_rx_data_i(7 downto 4));
            vga_wren_o  <= '1';
            state       <= BUSY_ST;
          end if;

        when BUSY_ST =>
          vga_addr_o <= vga_addr_o + 1;
          vga_data_o <= to_hex(eth_rx_data(3 downto 0));
          vga_wren_o <= '1';
          state      <= LAST_ST;

        when LAST_ST =>
          if eth_rx_last = '1' then
            vga_addr_o <= (vga_addr_o and X"FF00") + X"0100";
          end if;
          state <= IDLE_ST;

      end case;

      if rst_i = '1' then
        eth_rx_last <= '0';
        vga_addr_o  <= X"0000";
        vga_data_o  <= X"00";
        vga_wren_o  <= '0';
        state       <= IDLE_ST;
      end if;
    end if;
  end process vga_proc;

end architecture synthesis;


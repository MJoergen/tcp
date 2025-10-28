library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This is a top level TCP handler.
-- If dst_port_i is 0 then it opens a LISTENING session.
--
-- This interface is byte based.

entity tcp_wrapper is
  generic (
    G_SHOW_PROTOCOL           : boolean;
    G_INITIAL_SEQUENCE_NUMBER : std_logic_vector(31 downto 0);
    G_SIM_NAME                : string;  -- Used in simulation
    G_IP_PAYLOAD_BYTES        : natural; -- Width of IP payload data interface
    G_SESSION_BYTES           : natural  -- Width of session data interface
  );
  port (
    clk_i                 : in    std_logic;
    rst_i                 : in    std_logic;
    ppms_i                : in    std_logic;

    -- Session control interface
    session_start_i       : in    std_logic;
    session_src_port_i    : in    std_logic_vector(15 downto 0);
    session_dst_port_i    : in    std_logic_vector(15 downto 0);
    session_established_o : out   std_logic;
    -- Session data interface (byte oriented)
    session_rx_ready_i    : in    std_logic;
    session_rx_valid_o    : out   std_logic;
    session_rx_data_o     : out   std_logic_vector(G_SESSION_BYTES * 8 - 1 downto 0);
    session_rx_bytes_o    : out   natural range 0 to G_SESSION_BYTES;
    --
    session_tx_ready_o    : out   std_logic;
    session_tx_valid_i    : in    std_logic;
    session_tx_data_i     : in    std_logic_vector(G_SESSION_BYTES * 8 - 1 downto 0);
    session_tx_bytes_i    : in    natural range 0 to G_SESSION_BYTES;

    -- Interface to IP handler (packet oriented)
    -- bits 7-0 is the first byte transferred.
    ip_payload_rx_ready_o : out   std_logic;
    ip_payload_rx_valid_i : in    std_logic;
    ip_payload_rx_data_i  : in    std_logic_vector(G_IP_PAYLOAD_BYTES * 8 - 1 downto 0);
    ip_payload_rx_bytes_i : in    natural range 0 to G_IP_PAYLOAD_BYTES;
    ip_payload_rx_last_i  : in    std_logic;
    --
    ip_payload_tx_ready_i : in    std_logic;
    ip_payload_tx_valid_o : out   std_logic;
    ip_payload_tx_data_o  : out   std_logic_vector(G_IP_PAYLOAD_BYTES * 8 - 1 downto 0);
    ip_payload_tx_bytes_o : out   natural range 0 to G_IP_PAYLOAD_BYTES;
    ip_payload_tx_last_o  : out   std_logic
  );
end entity tcp_wrapper;

architecture synthesis of tcp_wrapper is

  signal   rx_ready       : std_logic;
  signal   rx_valid       : std_logic;
  signal   rx_src_port    : std_logic_vector(15 downto 0);
  signal   rx_dst_port    : std_logic_vector(15 downto 0);
  signal   rx_seq_number  : std_logic_vector(31 downto 0);
  signal   rx_ack_number  : std_logic_vector(31 downto 0);
  signal   rx_data_offset : std_logic_vector(3 downto 0);
  signal   rx_flags       : std_logic_vector(7 downto 0);
  signal   rx_window      : std_logic_vector(15 downto 0);
  signal   rx_chksum      : std_logic_vector(15 downto 0);
  signal   rx_urgent_ptr  : std_logic_vector(15 downto 0);
  signal   rx_options     : std_logic_vector(319 downto 0);

  signal   tx_ready       : std_logic;
  signal   tx_valid       : std_logic;
  signal   tx_src_port    : std_logic_vector(15 downto 0);
  signal   tx_dst_port    : std_logic_vector(15 downto 0);
  signal   tx_seq_number  : std_logic_vector(31 downto 0);
  signal   tx_ack_number  : std_logic_vector(31 downto 0);
  signal   tx_data_offset : std_logic_vector(3 downto 0);
  signal   tx_flags       : std_logic_vector(7 downto 0);
  signal   tx_window      : std_logic_vector(15 downto 0);
  signal   tx_chksum      : std_logic_vector(15 downto 0);
  signal   tx_urgent_ptr  : std_logic_vector(15 downto 0);
  signal   tx_options     : std_logic_vector(319 downto 0);

  subtype  R_TCP_SRC_PORT is natural range 8 * 2 - 1 downto 8 * 0;

  subtype  R_TCP_DST_PORT is natural range 8 * 4 - 1 downto 8 * 2;

  subtype  R_TCP_SEQ_NUMBER is natural range 8 * 8 - 1 downto 8 * 4;

  subtype  R_TCP_ACK_NUMBER is natural range 8 * 12 - 1 downto 8 * 8;

  subtype  R_TCP_DATA_OFFSET is natural range 8 * 13 - 1 downto 8 * 12 + 4;

  subtype  R_TCP_RESERVED is natural range 8 * 12 + 3 downto 8 * 12;

  subtype  R_TCP_FLAGS is natural range 8 * 14 - 1 downto 8 * 13;

  subtype  R_TCP_WINDOW is natural range 8 * 16 - 1 downto 8 * 14;

  subtype  R_TCP_CHKSUM is natural range 8 * 18 - 1 downto 8 * 16;

  subtype  R_TCP_URGENT_PTR is natural range 8 * 20 - 1 downto 8 * 18;

  constant C_TCP_HEADER : natural := 20;

  pure function byte_reverse (
    arg : std_logic_vector
  ) return std_logic_vector is
    variable arg_v   : std_logic_vector(arg'length - 1 downto 0);
    variable res_v   : std_logic_vector(arg'length - 1 downto 0);
    variable bytes_v : natural;
  begin
    assert (arg'length mod 8) = 0;
    arg_v   := arg;
    bytes_v := arg_v'length / 8;

    for i in bytes_v - 1 downto 0 loop
      res_v(8 * i + 7 downto 8 * i) := arg_v(bytes_v * 8 - i * 8 - 1 downto bytes_v * 8 - i * 8 - 8);
    end loop;

    return res_v;
  end function byte_reverse;

begin

  assert G_IP_PAYLOAD_BYTES > C_TCP_HEADER;
  assert G_SESSION_BYTES > 0;

  session_tx_ready_o <= session_established_o and tx_valid and
                        (ip_payload_tx_ready_i or not ip_payload_tx_valid_o);

  tx_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if ip_payload_tx_ready_i = '1' then
        tx_ready              <= '1';
        ip_payload_tx_valid_o <= '0';
      end if;

      if (ip_payload_tx_valid_o = '0' or ip_payload_tx_ready_i = '1') and tx_valid = '1' then
        -- Prepare TCP header
        ip_payload_tx_data_o(R_TCP_SRC_PORT)    <= byte_reverse(tx_src_port);
        ip_payload_tx_data_o(R_TCP_DST_PORT)    <= byte_reverse(tx_dst_port);
        ip_payload_tx_data_o(R_TCP_SEQ_NUMBER)  <= byte_reverse(tx_seq_number);
        ip_payload_tx_data_o(R_TCP_ACK_NUMBER)  <= byte_reverse(tx_ack_number);
        ip_payload_tx_data_o(R_TCP_DATA_OFFSET) <= tx_data_offset;
        ip_payload_tx_data_o(R_TCP_RESERVED)    <= (others => '0');
        ip_payload_tx_data_o(R_TCP_FLAGS)       <= tx_flags;
        ip_payload_tx_data_o(R_TCP_WINDOW)      <= byte_reverse(tx_window);
        ip_payload_tx_data_o(R_TCP_CHKSUM)      <= byte_reverse(tx_chksum);
        ip_payload_tx_data_o(R_TCP_URGENT_PTR)  <= byte_reverse(tx_urgent_ptr);
        ip_payload_tx_bytes_o                   <= C_TCP_HEADER;
        ip_payload_tx_last_o                    <= '1';

        if session_established_o = '0' then
          -- Session being established, send TCP header.
          ip_payload_tx_valid_o <= '1';
          tx_ready              <= '0';
        end if;

        if session_tx_valid_i = '1' and session_tx_ready_o = '1' then
          if G_SHOW_PROTOCOL then
            report G_SIM_NAME & " : Send TCP header with " & to_string(session_tx_bytes_i) &
                   " bytes of data:" &
                   to_hstring(session_tx_data_i(session_tx_bytes_i * 8 - 1 downto 0));
          end if;
          -- Session is established, send TCP header with data.
          ip_payload_tx_data_o(C_TCP_HEADER * 8 + session_tx_bytes_i * 8 - 1 downto C_TCP_HEADER * 8)
                                <= session_tx_data_i(session_tx_bytes_i * 8 - 1 downto 0);

          ip_payload_tx_bytes_o <= C_TCP_HEADER + session_tx_bytes_i;
          ip_payload_tx_valid_o <= '1';
          tx_ready              <= '0';
        end if;
      end if;

      if rst_i = '1' then
        tx_ready              <= '0';
        ip_payload_tx_valid_o <= '0';
      end if;
    end if;
  end process tx_proc;

  rx_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rx_ready = '1' then
        rx_valid              <= '0';
        ip_payload_rx_ready_o <= '1';
      end if;
      if session_rx_ready_i = '1' then
        session_rx_valid_o <= '0';
      end if;

      if ip_payload_rx_valid_i = '1' then
        assert ip_payload_rx_bytes_i = 0 or ip_payload_rx_bytes_i >= C_TCP_HEADER;
        assert ip_payload_rx_last_i = '1';

        rx_src_port           <= byte_reverse(ip_payload_rx_data_i(R_TCP_SRC_PORT));
        rx_dst_port           <= byte_reverse(ip_payload_rx_data_i(R_TCP_DST_PORT));
        rx_seq_number         <= byte_reverse(ip_payload_rx_data_i(R_TCP_SEQ_NUMBER));
        rx_ack_number         <= byte_reverse(ip_payload_rx_data_i(R_TCP_ACK_NUMBER));
        rx_data_offset        <= ip_payload_rx_data_i(R_TCP_DATA_OFFSET);
        rx_flags              <= ip_payload_rx_data_i(R_TCP_FLAGS);
        rx_window             <= byte_reverse(ip_payload_rx_data_i(R_TCP_WINDOW));
        rx_chksum             <= byte_reverse(ip_payload_rx_data_i(R_TCP_CHKSUM));
        rx_urgent_ptr         <= byte_reverse(ip_payload_rx_data_i(R_TCP_URGENT_PTR));

        -- Process TCP header.
        rx_valid              <= '1';
        ip_payload_rx_ready_o <= '0';

        if ip_payload_rx_bytes_i > C_TCP_HEADER then
          session_rx_valid_o <= '1';
          session_rx_bytes_o <= ip_payload_rx_bytes_i - C_TCP_HEADER;
          if G_SESSION_BYTES + C_TCP_HEADER <= G_IP_PAYLOAD_BYTES then
            session_rx_data_o <= ip_payload_rx_data_i(G_SESSION_BYTES * 8 - 1 + C_TCP_HEADER * 8 downto C_TCP_HEADER * 8);
          else
            session_rx_data_o(G_IP_PAYLOAD_BYTES * 8 - 1 - C_TCP_HEADER * 8 downto 0)
              <= ip_payload_rx_data_i(G_IP_PAYLOAD_BYTES * 8 - 1 downto C_TCP_HEADER * 8);
          end if;
        end if;
      end if;

      if rst_i = '1' then
        session_rx_valid_o    <= '0';
        ip_payload_rx_ready_o <= '0';
        rx_valid              <= '0';
      end if;
    end if;
  end process rx_proc;

  tcp_protocol_inst : entity work.tcp_protocol
    generic map (
      G_DEBUG                   => G_SHOW_PROTOCOL,
      G_INITIAL_SEQUENCE_NUMBER => G_INITIAL_SEQUENCE_NUMBER,
      G_SIM_NAME                => G_SIM_NAME
    )
    port map (
      clk_i            => clk_i,
      rst_i            => rst_i,
      ppms_i           => ppms_i,
      start_i          => session_start_i,
      src_port_i       => session_src_port_i,
      dst_port_i       => session_dst_port_i,
      established_o    => session_established_o,
      rx_ready_o       => rx_ready,
      rx_valid_i       => rx_valid,
      rx_src_port_i    => rx_src_port,
      rx_dst_port_i    => rx_dst_port,
      rx_seq_number_i  => rx_seq_number,
      rx_ack_number_i  => rx_ack_number,
      rx_data_offset_i => rx_data_offset,
      rx_flags_i       => rx_flags,
      rx_window_i      => rx_window,
      rx_chksum_i      => rx_chksum,
      rx_urgent_ptr_i  => rx_urgent_ptr,
      rx_options_i     => rx_options,
      tx_ready_i       => tx_ready,
      tx_valid_o       => tx_valid,
      tx_src_port_o    => tx_src_port,
      tx_dst_port_o    => tx_dst_port,
      tx_seq_number_o  => tx_seq_number,
      tx_ack_number_o  => tx_ack_number,
      tx_data_offset_o => tx_data_offset,
      tx_flags_o       => tx_flags,
      tx_window_o      => tx_window,
      tx_chksum_o      => tx_chksum,
      tx_urgent_ptr_o  => tx_urgent_ptr,
      tx_options_o     => tx_options
    ); -- tcp_protocol_inst : entity work.tcp_protocol

end architecture synthesis;


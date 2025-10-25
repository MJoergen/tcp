library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- If dst_port_i is 0 then it opens a LISTENING session.

entity tcp_protocol is
  generic (
    G_DEBUG                   : boolean;
    G_INITIAL_SEQUENCE_NUMBER : std_logic_vector(31 downto 0);
    G_SIM_NAME                : string -- Used in simulation
  );
  port (
    clk_i            : in    std_logic;
    rst_i            : in    std_logic;
    ppms_i           : in    std_logic; -- 1 pulse per millisecond

    start_i          : in    std_logic;
    src_port_i       : in    std_logic_vector(15 downto 0);
    dst_port_i       : in    std_logic_vector(15 downto 0);
    established_o    : out   std_logic;

    rx_ready_o       : out   std_logic;
    rx_valid_i       : in    std_logic;
    rx_src_port_i    : in    std_logic_vector(15 downto 0);
    rx_dst_port_i    : in    std_logic_vector(15 downto 0);
    rx_seq_number_i  : in    std_logic_vector(31 downto 0);
    rx_ack_number_i  : in    std_logic_vector(31 downto 0);
    rx_data_offset_i : in    std_logic_vector(3 downto 0);
    rx_flags_i       : in    std_logic_vector(7 downto 0);
    rx_window_i      : in    std_logic_vector(15 downto 0);
    rx_chksum_i      : in    std_logic_vector(15 downto 0);
    rx_urgent_ptr_i  : in    std_logic_vector(15 downto 0);
    rx_options_i     : in    std_logic_vector(319 downto 0);

    tx_ready_i       : in    std_logic;
    tx_valid_o       : out   std_logic;
    tx_src_port_o    : out   std_logic_vector(15 downto 0);
    tx_dst_port_o    : out   std_logic_vector(15 downto 0);
    tx_seq_number_o  : out   std_logic_vector(31 downto 0);
    tx_ack_number_o  : out   std_logic_vector(31 downto 0);
    tx_data_offset_o : out   std_logic_vector(3 downto 0);
    tx_flags_o       : out   std_logic_vector(7 downto 0);
    tx_window_o      : out   std_logic_vector(15 downto 0);
    tx_chksum_o      : out   std_logic_vector(15 downto 0);
    tx_urgent_ptr_o  : out   std_logic_vector(15 downto 0);
    tx_options_o     : out   std_logic_vector(319 downto 0)
  );
end entity tcp_protocol;

architecture synthesis of tcp_protocol is

  constant C_FLAGS_CWR : natural                         := 7;
  constant C_FLAGS_ECE : natural                         := 6;
  constant C_FLAGS_URG : natural                         := 5;
  constant C_FLAGS_ACK : natural                         := 4;
  constant C_FLAGS_PSH : natural                         := 3;
  constant C_FLAGS_RST : natural                         := 2;
  constant C_FLAGS_SYN : natural                         := 1;
  constant C_FLAGS_FIN : natural                         := 0;

  constant C_OPTION_END   : natural                      := 0;      -- End of options list
  constant C_OPTION_NOP   : natural                      := 1;      -- No operation
  constant C_OPTION_MSS   : natural                      := 2;      -- Maximum segment size (SYN only)
  constant C_OPTION_WS    : natural                      := 3;      -- Window scale (SYN only)
  constant C_OPTION_SA    : natural                      := 4;      -- Selectice Acknowledgement permitted (SYN only)
  constant C_OPTION_SACK  : natural                      := 5;      -- Selectice ACKnowledgement (SACK)
  constant C_OPTION_TIME  : natural                      := 8;      -- Timestamp and echo of previous timestamp
  constant C_OPTION_USER  : natural                      := 28;     -- User Timeout Option
  constant C_OPTION_AO    : natural                      := 29;     -- TCP Authentication Option (TCP-AO)
  constant C_OPTION_MPTCP : natural                      := 30;     -- Multipath TCP (MPTCP)

  type     state_type is (
    LISTEN_ST, SYN_SENT_ST, SYN_RECEIVED_ST,
    ESTABLISHED_ST, FIN_WAIT_1_ST, FIN_WAIT_2_ST, CLOSE_WAIT_ST,
    CLOSING_ST, LAST_ACK_ST, TIME_WAIT_ST, CLOSED_ST, IDLE_ST
  );
  signal   state : state_type                            := IDLE_ST;

  signal   src_port      : std_logic_vector(15 downto 0) := (others => '0');
  signal   dst_port      : std_logic_vector(15 downto 0) := (others => '0');
  signal   tx_seq_number : std_logic_vector(31 downto 0) := (others => '0');
  signal   tx_ack_number : std_logic_vector(31 downto 0) := (others => '0');

  constant C_TIME_WAIT_MAX : natural                     := 60_000; -- 1 minute
  signal   time_wait_cnt   : natural range 0 to C_TIME_WAIT_MAX;

begin

  rx_ready_o <= '1' when state = ESTABLISHED_ST else
                tx_ready_i or not tx_valid_o;

  state_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if tx_ready_i = '1' then
        tx_valid_o <= '0';
      end if;

      if ppms_i = '1' and time_wait_cnt > 0 then
        time_wait_cnt <= time_wait_cnt - 1;
      end if;

      if tx_valid_o = '0' then
        -- Set default values
        tx_src_port_o    <= src_port;
        tx_dst_port_o    <= dst_port;
        tx_seq_number_o  <= tx_seq_number;
        tx_ack_number_o  <= tx_ack_number;
        tx_data_offset_o <= x"5";
        tx_flags_o       <= (others => '0');
        tx_window_o      <= (others => '0');
        tx_chksum_o      <= (others => '0');
        tx_urgent_ptr_o  <= (others => '0');
        tx_options_o     <= (others => '0');
      end if;

      if rx_valid_i = '1' and rx_ready_o = '1' and G_DEBUG then
        report G_SIM_NAME & ": Received packet";
      end if;

      case state is

        when LISTEN_ST =>
          -- Waiting for a connection request from any remote TCP end-point.
          if rx_valid_i = '1' and rx_ready_o = '1' then
            if rx_flags_i(C_FLAGS_SYN) = '1' and rx_flags_i(C_FLAGS_ACK) = '0' and rx_dst_port_i = src_port then
              if G_DEBUG then
                report G_SIM_NAME & ": LISTEN_ST: SYN received";
              end if;
              dst_port                <= rx_src_port_i;
              tx_ack_number           <= std_logic_vector(unsigned(rx_seq_number_i) + 1);

              -- Send SYN-ACK
              tx_dst_port_o           <= rx_src_port_i;
              tx_ack_number_o         <= std_logic_vector(unsigned(rx_seq_number_i) + 1);
              tx_flags_o(C_FLAGS_ACK) <= '1';
              tx_flags_o(C_FLAGS_SYN) <= '1';
              tx_valid_o              <= '1';
              state                   <= SYN_RECEIVED_ST;
            else
              if G_DEBUG then
                report G_SIM_NAME & ": LISTEN_ST: Sending RST";
              end if;
              -- Send RST
              tx_src_port_o           <= rx_dst_port_i;
              tx_dst_port_o           <= rx_src_port_i;
              tx_flags_o(C_FLAGS_RST) <= '1';
              tx_valid_o              <= '1';
            end if;
          end if;

        when SYN_SENT_ST =>
          -- Waiting for a matching connection request after having sent a connection
          -- request.
          if rx_valid_i = '1' and rx_ready_o = '1' then
            if rx_flags_i(C_FLAGS_SYN) = '1' and
               rx_flags_i(C_FLAGS_ACK) = '1' and
               rx_dst_port_i = src_port and
               rx_ack_number_i = std_logic_vector(unsigned(tx_seq_number) + 1) then
              if G_DEBUG then
                report G_SIM_NAME & ": SYN_SENT_ST: SYN-ACK received";
              end if;
              tx_seq_number           <= std_logic_vector(unsigned(tx_seq_number) + 1);
              tx_ack_number           <= std_logic_vector(unsigned(rx_seq_number_i) + 1);

              -- Send ACK
              tx_src_port_o           <= src_port;
              tx_dst_port_o           <= dst_port;
              tx_seq_number_o         <= std_logic_vector(unsigned(tx_seq_number) + 1);
              tx_ack_number_o         <= std_logic_vector(unsigned(rx_seq_number_i) + 1);
              tx_flags_o(C_FLAGS_ACK) <= '1';
              tx_valid_o              <= '1';
              state                   <= ESTABLISHED_ST;
            else
              if G_DEBUG then
                report G_SIM_NAME & ": SYN_SENT_ST: Sending RST";
              end if;
              -- Send RST
              tx_src_port_o           <= rx_src_port_i;
              tx_dst_port_o           <= rx_dst_port_i;
              tx_flags_o(C_FLAGS_RST) <= '1';
              tx_valid_o              <= '1';
            end if;
          end if;

        when SYN_RECEIVED_ST =>
          -- Waiting for a confirming connection request acknowledgment after having both
          -- received and sent a connection request.
          if rx_valid_i = '1' and rx_ready_o = '1' then
            if rx_flags_i(C_FLAGS_SYN) = '0' and rx_flags_i(C_FLAGS_ACK) = '1' and rx_dst_port_i = src_port then
              if G_DEBUG then
                report G_SIM_NAME & ": SYN_RECEIVED_ST: SYN-ACK received";
              end if;
              state <= ESTABLISHED_ST;
            else
              if G_DEBUG then
                report G_SIM_NAME & ": SYN_RECEIVED_ST: Sending RST";
              end if;
              -- Send RST
              tx_src_port_o           <= rx_src_port_i;
              tx_dst_port_o           <= rx_dst_port_i;
              tx_flags_o(C_FLAGS_RST) <= '1';
              tx_valid_o              <= '1';
            end if;
          end if;

        when ESTABLISHED_ST =>
          -- An open connection, data received can be delivered to the user. The normal
          -- state for the data transfer phase of the connection.
          if start_i = '0' then
            if G_DEBUG then
              report G_SIM_NAME & ": ESTABLISHED_ST: Closing down";
            end if;
            established_o           <= '0';
            -- Send FIN
            tx_flags_o(C_FLAGS_FIN) <= '1';
            tx_valid_o              <= '1';
            state                   <= FIN_WAIT_1_ST;
          else
            established_o           <= '1';
            tx_flags_o(C_FLAGS_ACK) <= '1';
            tx_valid_o              <= '1';
          end if;

          if rx_valid_i = '1' and rx_ready_o = '1' then
            if rx_flags_i(C_FLAGS_FIN) = '1' and rx_dst_port_i = src_port then
              if G_DEBUG then
                report G_SIM_NAME & ": ESTABLISHED_ST: FIN received";
              end if;
              established_o <= '0';
              state         <= CLOSE_WAIT_ST;
            end if;
          end if;

        when FIN_WAIT_1_ST =>
          -- Waiting for a connection termination request from the remote TCP, or an
          -- acknowledgment of the connection termination request previously sent.
          if rx_valid_i = '1' and rx_ready_o = '1' then
            if rx_flags_i(C_FLAGS_ACK) = '1' and rx_flags_i(C_FLAGS_FIN) = '0' and rx_dst_port_i = src_port then
              if G_DEBUG then
                report G_SIM_NAME & ": FIN_WAIT_1_ST: ACK received";
              end if;
              state <= FIN_WAIT_2_ST;
            elsif rx_flags_i(C_FLAGS_ACK) = '1' and rx_flags_i(C_FLAGS_FIN) = '1' and rx_dst_port_i = src_port then
              if G_DEBUG then
                report G_SIM_NAME & ": FIN_WAIT_1_ST: FIN-ACK received";
              end if;
              state <= TIME_WAIT_ST;
            else
              if G_DEBUG then
                report G_SIM_NAME & ": FIN_WAIT_1_ST: Sending RST";
              end if;
              -- Send RST
              tx_flags_o(C_FLAGS_RST) <= '1';
              tx_valid_o              <= '1';
            end if;
          end if;

        when FIN_WAIT_2_ST =>
          -- Waiting for a connection termination request from the remote TCP.
          if rx_valid_i = '1' and rx_ready_o = '1' then
            if rx_flags_i(C_FLAGS_FIN) = '1' and rx_dst_port_i = src_port then
              if G_DEBUG then
                report G_SIM_NAME & ": FIN_WAIT_2_ST: FIN received";
              end if;
              time_wait_cnt <= C_TIME_WAIT_MAX;
              state         <= TIME_WAIT_ST;
            end if;
          end if;

        when CLOSE_WAIT_ST =>
          -- Waiting for a connection termination request from the local user.
          if start_i = '0' then
            if G_DEBUG then
              report G_SIM_NAME & ": CLOSE_WAIT_ST: Closing down";
            end if;
            established_o           <= '0';
            -- Send FIN
            tx_flags_o(C_FLAGS_FIN) <= '1';
            tx_valid_o              <= '1';
            state                   <= LAST_ACK_ST;
          end if;

        when CLOSING_ST =>
          -- Waiting for a connection termination request acknowledgment from the remote
          -- TCP.
          state <= CLOSED_ST;

        when LAST_ACK_ST =>
          -- Waiting for an acknowledgment of the connection termination request
          -- previously sent to the remote TCP (which includes an acknowledgment of its
          -- connection termination request).
          state <= CLOSED_ST;

        when TIME_WAIT_ST =>
          -- Waiting for enough time to pass to be sure that all remaining packets on the
          -- connection have expired.
          if time_wait_cnt = 0 then
            state <= CLOSED_ST;
          end if;

        when CLOSED_ST =>
          -- No connection state at all.
          if start_i = '0' then
            state <= IDLE_ST;
          end if;

        when IDLE_ST =>
          if start_i = '1' then
            if unsigned(dst_port_i) = 0 then
              if G_DEBUG then
                report G_SIM_NAME & ": IDLE_ST: Listening on port " & to_hstring(src_port_i);
              end if;
              src_port <= src_port_i;
              state    <= LISTEN_ST;
            else
              if G_DEBUG then
                report G_SIM_NAME & ": IDLE_ST: Connecting to port " & to_hstring(dst_port_i) &
                       " from port " & to_hstring(src_port_i);
              end if;
              src_port                <= src_port_i;
              dst_port                <= dst_port_i;

              -- Send SYN
              tx_src_port_o           <= src_port_i;
              tx_dst_port_o           <= dst_port_i;
              tx_flags_o(C_FLAGS_SYN) <= '1';
              tx_valid_o              <= '1';
              state                   <= SYN_SENT_ST;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        tx_seq_number <= G_INITIAL_SEQUENCE_NUMBER;
        tx_ack_number <= (others => '0');
        tx_valid_o    <= '0';
        established_o <= '0';
        dst_port      <= (others => '0');
        state         <= IDLE_ST;
        time_wait_cnt <= 0;
      end if;
    end if;
  end process state_proc;

end architecture synthesis;


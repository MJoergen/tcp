library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity controller is
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
    cmd_ready_i     : in    std_logic;
    cmd_valid_o     : out   std_logic;
    cmd_data_o      : out   std_logic_vector(7 downto 0)
  );
end entity controller;

architecture synthesis of controller is

  -- MEGA65 key codes that kb_key_num_i is using while
  -- kb_key_pressed_n_i is signalling (low active) which key is pressed
  constant C_M65_INS_DEL     : integer := 0;
  constant C_M65_RETURN      : integer := 1;
  constant C_M65_HORZ_CRSR   : integer := 2;  -- means cursor right in C64 terminology
  constant C_M65_F7          : integer := 3;
  constant C_M65_F1          : integer := 4;
  constant C_M65_F3          : integer := 5;
  constant C_M65_F5          : integer := 6;
  constant C_M65_VERT_CRSR   : integer := 7;  -- means cursor down in C64 terminology
  constant C_M65_3           : integer := 8;
  constant C_M65_W           : integer := 9;
  constant C_M65_A           : integer := 10;
  constant C_M65_4           : integer := 11;
  constant C_M65_Z           : integer := 12;
  constant C_M65_S           : integer := 13;
  constant C_M65_E           : integer := 14;
  constant C_M65_LEFT_SHIFT  : integer := 15;
  constant C_M65_5           : integer := 16;
  constant C_M65_R           : integer := 17;
  constant C_M65_D           : integer := 18;
  constant C_M65_6           : integer := 19;
  constant C_M65_C           : integer := 20;
  constant C_M65_F           : integer := 21;
  constant C_M65_T           : integer := 22;
  constant C_M65_X           : integer := 23;
  constant C_M65_7           : integer := 24;
  constant C_M65_Y           : integer := 25;
  constant C_M65_G           : integer := 26;
  constant C_M65_8           : integer := 27;
  constant C_M65_B           : integer := 28;
  constant C_M65_H           : integer := 29;
  constant C_M65_U           : integer := 30;
  constant C_M65_V           : integer := 31;
  constant C_M65_9           : integer := 32;
  constant C_M65_I           : integer := 33;
  constant C_M65_J           : integer := 34;
  constant C_M65_0           : integer := 35;
  constant C_M65_M           : integer := 36;
  constant C_M65_K           : integer := 37;
  constant C_M65_O           : integer := 38;
  constant C_M65_N           : integer := 39;
  constant C_M65_PLUS        : integer := 40;
  constant C_M65_P           : integer := 41;
  constant C_M65_L           : integer := 42;
  constant C_M65_MINUS       : integer := 43;
  constant C_M65_DOT         : integer := 44;
  constant C_M65_COLON       : integer := 45;
  constant C_M65_AT          : integer := 46;
  constant C_M65_COMMA       : integer := 47;
  constant C_M65_GBP         : integer := 48;
  constant C_M65_ASTERISK    : integer := 49;
  constant C_M65_SEMICOLON   : integer := 50;
  constant C_M65_CLR_HOME    : integer := 51;
  constant C_M65_RIGHT_SHIFT : integer := 52;
  constant C_M65_EQUAL       : integer := 53;
  constant C_M65_ARROW_UP    : integer := 54; -- symbol, not cursor
  constant C_M65_SLASH       : integer := 55;
  constant C_M65_1           : integer := 56;
  constant C_M65_ARROW_LEFT  : integer := 57; -- symbol, not cursor
  constant C_M65_CTRL        : integer := 58;
  constant C_M65_2           : integer := 59;
  constant C_M65_SPACE       : integer := 60;
  constant C_M65_MEGA        : integer := 61;
  constant C_M65_Q           : integer := 62;
  constant C_M65_RUN_STOP    : integer := 63;
  constant C_M65_NO_SCRL     : integer := 64;
  constant C_M65_TAB         : integer := 65;
  constant C_M65_ALT         : integer := 66;
  constant C_M65_HELP        : integer := 67;
  constant C_M65_F9          : integer := 68;
  constant C_M65_F11         : integer := 69;
  constant C_M65_F13         : integer := 70;
  constant C_M65_ESC         : integer := 71;
  constant C_M65_CAPSLOCK    : integer := 72;
  constant C_M65_UP_CRSR     : integer := 73; -- cursor up
  constant C_M65_LEFT_CRSR   : integer := 74; -- cursor left
  constant C_M65_RESTORE     : integer := 75;
  constant C_M65_NONE        : integer := 79;

  signal   key_num      : integer range 0 to 79;
  signal   key_pressed  : std_logic;
  signal   key_released : std_logic;

  constant C_W2B_BYTES : natural       := 10;
  signal   w2b_ready   : std_logic;
  signal   w2b_valid   : std_logic;
  signal   w2b_last    : std_logic;
  signal   w2b_bytes   : natural range 0 to C_W2B_BYTES;
  signal   w2b_data    : std_logic_vector(C_W2B_BYTES * 8 - 1 downto 0);

  signal   initialized : std_logic;

begin

  uart_rx_ready_o <= (not cmd_valid_o) and (not w2b_valid);

  w2b_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if w2b_ready = '1' then
        w2b_valid <= '0';
      end if;

      if initialized = '0' then
        w2b_valid   <= '1';
        w2b_last    <= '1';
        w2b_bytes   <= C_W2B_BYTES;
        w2b_data    <= X"41424344454647480D0A";
        initialized <= '1';
      end if;

      if initialized = '1' then
        if uart_rx_valid_i = '1' and uart_rx_ready_o = '1' then
          w2b_valid                                                <= '1';
          w2b_last                                                 <= '1';
          w2b_bytes                                                <= 1;
          w2b_data(C_W2B_BYTES * 8 - 1 downto C_W2B_BYTES * 8 - 8) <= uart_rx_data_i;
        end if;
      end if;

      if rst_i = '1' then
        w2b_valid   <= '0';
        initialized <= '0';
      end if;
    end if;
  end process w2b_proc;

  wide2byte_inst : entity work.wide2byte
    generic map (
      G_BYTES => C_W2B_BYTES
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => w2b_ready,
      s_valid_i => w2b_valid,
      s_last_i  => w2b_last,
      s_bytes_i => w2b_bytes,
      s_data_i  => w2b_data,
      m_ready_i => uart_tx_ready_i,
      m_valid_o => uart_tx_valid_o,
      m_last_o  => open,
      m_data_o  => uart_tx_data_o
    ); -- wide2byte_inst : entity work.wide2byte

  key_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      key_pressed <= '0';

      if key_pressed_n_i = '0' then
        if key_num /= key_num_i or key_released = '1' then
          key_num      <= key_num_i;
          key_pressed  <= '1';
          key_released <= '0';
        end if;
      end if;

      if key_pressed_n_i = '1' then
        if key_num = key_num_i then
          key_released <= '1';
        end if;
      end if;

      if rst_i = '1' then
        key_pressed  <= '0';
        key_released <= '1';
        key_num      <= C_M65_NONE;
      end if;
    end if;
  end process key_proc;


  cmd_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if cmd_ready_i = '1' then
        cmd_valid_o <= '0';
      end if;

      if uart_rx_valid_i = '1' and uart_rx_ready_o = '1' then
        if uart_rx_data_i >= X"61" and uart_rx_data_i <= X"7A" then
          cmd_data_o  <= uart_rx_data_i - X"20";
          cmd_valid_o <= '1';
        else
          cmd_data_o  <= uart_rx_data_i;
          cmd_valid_o <= '1';
        end if;
      end if;

      if key_pressed = '1' then
        cmd_valid_o <= '1';

        case key_num is

          when C_M65_A =>
            cmd_data_o <= X"41";

          when C_M65_B =>
            cmd_data_o <= X"42";

          when C_M65_C =>
            cmd_data_o <= X"43";

          when C_M65_D =>
            cmd_data_o <= X"44";

          when C_M65_E =>
            cmd_data_o <= X"45";

          when C_M65_F =>
            cmd_data_o <= X"46";

          when C_M65_G =>
            cmd_data_o <= X"47";

          when C_M65_H =>
            cmd_data_o <= X"48";

          when C_M65_I =>
            cmd_data_o <= X"49";

          when C_M65_J =>
            cmd_data_o <= X"4A";

          when C_M65_K =>
            cmd_data_o <= X"4B";

          when C_M65_L =>
            cmd_data_o <= X"4C";

          when C_M65_M =>
            cmd_data_o <= X"4D";

          when C_M65_N =>
            cmd_data_o <= X"4E";

          when C_M65_O =>
            cmd_data_o <= X"4F";

          when C_M65_P =>
            cmd_data_o <= X"50";

          when C_M65_Q =>
            cmd_data_o <= X"51";

          when C_M65_R =>
            cmd_data_o <= X"52";

          when C_M65_S =>
            cmd_data_o <= X"53";

          when C_M65_T =>
            cmd_data_o <= X"54";

          when C_M65_U =>
            cmd_data_o <= X"55";

          when C_M65_V =>
            cmd_data_o <= X"56";

          when C_M65_W =>
            cmd_data_o <= X"57";

          when C_M65_X =>
            cmd_data_o <= X"58";

          when C_M65_Y =>
            cmd_data_o <= X"59";

          when C_M65_Z =>
            cmd_data_o <= X"5A";

          when others =>
            cmd_valid_o <= '0';

        end case;

      end if;
    end if;
  end process cmd_proc;

end architecture synthesis;


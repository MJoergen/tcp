library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity tb_axi_stim_verf is
  generic (
    G_DEBUG        : boolean;
    G_SHOW_PACKETS : boolean;
    G_RANDOM       : boolean;
    G_FAST         : boolean;
    G_MAX_LENGTH   : natural;
    G_CNT_SIZE     : natural
  );
end entity tb_axi_stim_verf;

architecture simulation of tb_axi_stim_verf is

  constant C_DATA_BYTES : natural     := 8;

  signal   clk : std_logic            := '1';
  signal   rst : std_logic            := '1';

  constant C_RAM_DEPTH : natural      := 8;
  signal   tb_fill     : natural range 0 to C_RAM_DEPTH - 1;

  signal   tb_m_ready     : std_logic;
  signal   tb_m_valid     : std_logic;
  signal   tb_m_data      : std_logic_vector(C_DATA_BYTES * 8 - 1 downto 0);
  signal   tb_m_bytes     : natural range 0 to C_DATA_BYTES;
  signal   tb_m_bytes_slv : std_logic_vector(7 downto 0);
  signal   tb_m_last      : std_logic;

  signal   tb_s_ready     : std_logic;
  signal   tb_s_valid     : std_logic;
  signal   tb_s_data      : std_logic_vector(C_DATA_BYTES * 8 - 1 downto 0);
  signal   tb_s_bytes     : natural range 0 to C_DATA_BYTES;
  signal   tb_s_bytes_slv : std_logic_vector(7 downto 0);
  signal   tb_s_last      : std_logic;

  subtype  R_DATA is natural range C_DATA_BYTES * 8 - 1 downto 0;
  subtype  R_BYTES is natural range C_DATA_BYTES * 8 + 7 downto C_DATA_BYTES * 8;
  constant C_LAST           : natural := C_DATA_BYTES * 8 + 8;
  constant C_FIFO_DATA_SIZE : natural := C_DATA_BYTES * 8 + 8 + 1;

begin

  ----------------------------------------------------------
  -- Clock and reset
  ----------------------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------------------
  -- Generate stimuli and verify response
  ----------------------------------------------------------

  axi_stim_verf_inst : entity work.axi_stim_verf
    generic map (
      G_DEBUG        => G_DEBUG,
      G_RANDOM       => G_RANDOM,
      G_FAST         => G_FAST,
      G_MAX_LENGTH   => G_MAX_LENGTH,
      G_CNT_SIZE     => G_CNT_SIZE,
      G_M_DATA_BYTES => C_DATA_BYTES,
      G_S_DATA_BYTES => C_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_ready_i => tb_m_ready,
      m_valid_o => tb_m_valid,
      m_data_o  => tb_m_data,
      m_bytes_o => tb_m_bytes,
      m_last_o  => tb_m_last,
      s_ready_o => tb_s_ready,
      s_valid_i => tb_s_valid,
      s_data_i  => tb_s_data,
      s_bytes_i => tb_s_bytes,
      s_last_i  => tb_s_last
    ); -- axi_stim_verf_inst : entity work.axi_stim_verf


  ----------------------------------------------------------
  -- Loop back through FIFO
  ----------------------------------------------------------

  axi_fifo_sync_inst : entity work.axi_fifo_sync
    generic map (
      G_RAM_STYLE => "auto",
      G_DATA_SIZE => C_FIFO_DATA_SIZE,
      G_RAM_DEPTH => C_RAM_DEPTH
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      fill_o            => tb_fill,
      s_ready_o         => tb_m_ready,
      s_valid_i         => tb_m_valid,
      s_data_i(R_DATA)  => tb_m_data,
      s_data_i(R_BYTES) => tb_m_bytes_slv,
      s_data_i(C_LAST)  => tb_m_last,
      m_ready_i         => tb_s_ready,
      m_valid_o         => tb_s_valid,
      m_data_o(R_DATA)  => tb_s_data,
      m_data_o(R_BYTES) => tb_s_bytes_slv,
      m_data_o(C_LAST)  => tb_s_last
    ); -- axi_fifo_sync_inst : entity work.axi_fifo_sync

  tb_m_bytes_slv <= to_stdlogicvector(tb_m_bytes, 8);
  tb_s_bytes     <= to_integer(tb_s_bytes_slv);


  ----------------------------------------------------------
  -- Dump data packets
  ----------------------------------------------------------

  data_logger_m_inst : entity work.data_logger
    generic map (
      G_ENABLE    => G_SHOW_PACKETS,
      G_LOG_NAME  => "TB ",
      G_DATA_SIZE => C_DATA_BYTES * 8
    )
    port map (
      clk_i   => clk,
      rst_i   => rst,
      ready_i => tb_m_ready,
      valid_i => tb_m_valid,
      data_i  => tb_m_data,
      bytes_i => tb_m_bytes,
      last_i  => tb_m_last
    ); -- data_logger_m_inst : entity work.data_logger

end architecture simulation;


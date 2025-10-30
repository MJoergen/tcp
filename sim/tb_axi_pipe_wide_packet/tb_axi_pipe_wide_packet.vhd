library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

entity tb_axi_pipe_wide_packet is
  generic (
    G_START_ZERO   : boolean;
    G_DEBUG        : boolean;
    G_MAX_LENGTH   : natural;
    G_CNT_SIZE     : natural;
    G_FAST         : boolean;
    G_RANDOM       : boolean;
    G_S_DATA_BYTES : natural;
    G_M_DATA_BYTES : natural
  );
end entity tb_axi_pipe_wide_packet;

architecture simulation of tb_axi_pipe_wide_packet is

  signal clk     : std_logic := '1';
  signal rst     : std_logic := '1';

  signal s_ready : std_logic;
  signal s_valid : std_logic;
  signal s_data  : std_logic_vector(G_S_DATA_BYTES * 8 - 1 downto 0);
  signal s_start : natural range 0 to G_S_DATA_BYTES-1;
  signal s_end   : natural range 0 to G_S_DATA_BYTES;
  signal s_last  : std_logic;

  signal m_ready         : std_logic;
  signal m_bytes_consume : natural range 0 to G_M_DATA_BYTES;
  signal m_valid         : std_logic;
  signal m_data          : std_logic_vector(G_M_DATA_BYTES * 8 - 1 downto 0);
  signal m_bytes_avail   : natural range 0 to G_M_DATA_BYTES;
  signal m_last          : std_logic;

  signal rand : std_logic_vector(63 downto 0);

begin

  --------------------------------------------
  -- Clock and reset
  --------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------------------
  -- Generate stimuli and verify response
  --------------------------------------------

  axi_stim_verf_inst : entity work.axi_stim_verf
    generic map (
      G_START_ZERO   => G_START_ZERO,
      G_DEBUG        => G_DEBUG,
      G_MAX_LENGTH   => G_MAX_LENGTH,
      G_CNT_SIZE     => G_CNT_SIZE,
      G_RANDOM       => G_RANDOM,
      G_FAST         => G_FAST,
      G_M_DATA_BYTES => G_S_DATA_BYTES,
      G_S_DATA_BYTES => G_M_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_ready_i => s_ready,
      m_valid_o => s_valid,
      m_data_o  => s_data,
      m_start_o => s_start,
      m_end_o   => s_end,
      m_last_o  => s_last,
      s_ready_o => m_ready,
      s_valid_i => m_valid,
      s_data_i  => m_data,
      s_bytes_i => minimum(m_bytes_consume, m_bytes_avail),
      s_last_i  => m_last
    ); -- axi_stim_verf : entity work.axi_stim_verf


  --------------------------------------------
  -- Randomize number of bytes consumed
  --------------------------------------------

  random_inst : entity work.random
    generic map (
      G_SEED => X"BEAFDEADC007BABE"
    )
    port map (
      clk_i    => clk,
      rst_i    => rst,
      update_i => '1',
      output_o => rand
    ); -- random_inst : entity work.random

  m_bytes_consume <= to_integer(rand(40 downto 20)) mod (G_M_DATA_BYTES + 1);


  --------------------------------------------
  -- Instantiate DUT
  --------------------------------------------

  axi_pipe_wide_inst : entity work.axi_pipe_wide
    generic map (
      G_S_DATA_BYTES => G_S_DATA_BYTES,
      G_M_DATA_BYTES => G_M_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => s_ready,
      s_valid_i => s_valid,
      s_data_i  => s_data,
      s_start_i => s_start,
      s_end_i   => s_end,
      s_last_i  => s_last,
      m_ready_i => m_ready,
      m_bytes_i => m_bytes_consume,
      m_valid_o => m_valid,
      m_data_o  => m_data,
      m_bytes_o => m_bytes_avail,
      m_last_o  => m_last
    ); -- axi_pipe_wide_inst : entity work.axi_pipe_wide

end architecture simulation;


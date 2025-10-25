library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

entity tb_axi_fifo_squash_stress is
  generic (
    G_FAST   : boolean;
    G_RANDOM : boolean
  );
end entity tb_axi_fifo_squash_stress;

architecture simulation of tb_axi_fifo_squash_stress is

  constant C_DATA_BYTES : natural := 8;

  signal   clk     : std_logic    := '1';
  signal   rst     : std_logic    := '1';
  signal   running : std_logic    := '1';

  signal   s_ready : std_logic;
  signal   s_valid : std_logic;
  signal   s_data  : std_logic_vector(C_DATA_BYTES * 8 - 1 downto 0);
  signal   s_start : natural range 0 to C_DATA_BYTES;
  signal   s_end   : natural range 0 to C_DATA_BYTES;
  signal   s_push  : std_logic;

  signal   m_ready : std_logic;
  signal   m_valid : std_logic;
  signal   m_data  : std_logic_vector(C_DATA_BYTES * 8 - 1 downto 0);
  signal   m_bytes : natural range 0 to C_DATA_BYTES;
  signal   m_empty : std_logic;

  signal   rand       : std_logic_vector(63 downto 0);
  signal   stim_cnt   : std_logic_vector(9 downto 0);
  signal   verify_cnt : std_logic_vector(9 downto 0);

  signal   do_valid : std_logic;
  signal   do_push  : std_logic;

begin

  -------------------------------------
  -- Clock and reset
  -------------------------------------

  clk <= running and not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  -------------------------------------
  -- Generate randomness
  -------------------------------------

  random_inst : entity work.random
    generic map (
      G_SEED => X"DEADBEAFC007BABE"
    )
    port map (
      clk_i    => clk,
      rst_i    => rst,
      update_i => '1',
      output_o => rand
    ); -- random_inst : entity work.random


  -------------------------------------
  -- Generate stimuli
  -------------------------------------

  do_valid <= or(rand(42 downto 40)) when G_RANDOM else
              '1';
  do_push  <= and(rand(22 downto 20));


  stimuli_proc : process (clk)
    variable start_v : natural range 0 to C_DATA_BYTES;
    variable end_v   : natural range 0 to C_DATA_BYTES;
  begin
    if rising_edge(clk) then
      if s_ready = '1' then
        s_valid <= '0';
        s_data  <= (others => '0');
        s_start <= 0;
        s_end   <= 0;
        s_push  <= '0';
      end if;

      if s_valid = '0' or (G_FAST and s_ready = '1') then
        if do_valid = '1' then
          start_v  := to_integer(rand(15 downto 0)) mod (C_DATA_BYTES + 1);
          end_v    := to_integer(rand(15 downto 0)) mod (C_DATA_BYTES + 1 - start_v) + start_v;

          stim_cnt <= stim_cnt + end_v - start_v;

          for i in start_v to end_v - 1 loop
            s_data(i * 8 + 7 downto i * 8) <= stim_cnt(7 downto 0) + i - start_v;
          end loop;

          s_valid <= '1';
          s_start <= start_v;
          s_end   <= end_v;
          s_push  <= do_push;
        end if;
      end if;

      if rst = '1' then
        s_valid  <= '0';
        stim_cnt <= (others => '0');
      end if;
    end if;
  end process stimuli_proc;


  -------------------------------------
  -- Verify output
  -------------------------------------

  m_ready  <= or(rand(32 downto 30)) when G_RANDOM else
              '1';

  verify_proc : process (clk)
  begin
    if rising_edge(clk) then
      if m_valid = '1' and m_ready = '1' then

        for i in 0 to m_bytes - 1 loop
          assert m_data(i * 8 + 7 downto i * 8) = verify_cnt(7 downto 0) + i
            report "Verify byte " & to_string(i) &
                   ". Received " & to_hstring(m_data(i * 8 + 7 downto i * 8)) &
                   ", expected " & to_hstring(verify_cnt(7 downto 0) + i);
        end loop;

        verify_cnt <= verify_cnt + m_bytes;

        -- Check for wrap-around
        if verify_cnt > verify_cnt + m_bytes then
          stop;
        end if;
      end if;

      if rst = '1' then
        verify_cnt <= (others => '0');
      end if;
    end if;
  end process verify_proc;


  -------------------------------------
  -- Instantiate DUT
  -------------------------------------

  axi_fifo_squash_inst : entity work.axi_fifo_squash
    generic map (
      G_DATA_BYTES => C_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => s_ready,
      s_valid_i => s_valid,
      s_data_i  => s_data,
      s_start_i => s_start,
      s_end_i   => s_end,
      s_push_i  => s_push,
      m_ready_i => m_ready,
      m_valid_o => m_valid,
      m_data_o  => m_data,
      m_bytes_o => m_bytes,
      m_empty_o => m_empty
    ); -- axi_fifo_squash_inst : entity work.axi_fifo_squash

end architecture simulation;


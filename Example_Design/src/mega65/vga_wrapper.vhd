library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library work;
  use work.video_modes_pkg.all;

library xpm;
  use xpm.vcomponents.all;

library unisim;
  use unisim.vcomponents.all;

entity vga_wrapper is
  port (
    --------------------------------------------------------
    -- Connect to design (everything in user_clk domain)
    --------------------------------------------------------

    user_clk_i      : in    std_logic;  -- 100 MHz
    user_rst_i      : in    std_logic;

    -- VGA frame buffer
    user_vga_addr_i : in    std_logic_vector(15 downto 0);
    user_vga_data_i : in    std_logic_vector(23 downto 0);
    user_vga_wren_i : in    std_logic;

    --------------------------------------------------------
    -- Connect to MEGA65 I/O ports
    --------------------------------------------------------

    -- VGA interface
    vga_clk_i       : in    std_logic;
    vga_rst_i       : in    std_logic;
    vdac_blank_n_o  : out   std_logic;
    vdac_clk_o      : out   std_logic;
    vdac_psave_n_o  : out   std_logic;
    vdac_sync_n_o   : out   std_logic;
    vga_blue_o      : out   std_logic_vector(7 downto 0);
    vga_green_o     : out   std_logic_vector(7 downto 0);
    vga_hs_o        : out   std_logic;
    vga_red_o       : out   std_logic_vector(7 downto 0);
    vga_vs_o        : out   std_logic
  );

  attribute keep : string;
  attribute keep of vga_blue_o  : signal is "true";
  attribute keep of vga_green_o : signal is "true";
  attribute keep of vga_red_o   : signal is "true";

end entity vga_wrapper;

architecture synthesis of vga_wrapper is

  -- VGA
  constant C_VIDEO_MODE : video_modes_type := C_VIDEO_MODE_1280_720_60;

  signal   vga_vs     : std_logic;
  signal   vga_hs     : std_logic;
  signal   vga_de     : std_logic;
  signal   vga_hcount : std_logic_vector(C_VIDEO_MODE.PIX_SIZE - 1 downto 0);
  signal   vga_vcount : std_logic_vector(C_VIDEO_MODE.PIX_SIZE - 1 downto 0);

  signal   vga_rgb    : std_logic_vector(7 downto 0);
  signal   vga_x      : std_logic_vector(7 downto 0);
  signal   vga_y      : std_logic_vector(7 downto 0);
  signal   vga_char   : std_logic_vector(7 downto 0);
  signal   vga_colors : std_logic_vector(15 downto 0);

  signal   vga_addr    : std_logic_vector(15 downto 0);
  signal   vga_rd_data : std_logic_vector(23 downto 0);

begin

  tdp_ram_inst : entity work.tdp_ram
    generic map (
      G_A_LATENCY => 1,
      G_B_LATENCY => 1,
      G_INIT_FILE => "",
      G_RAM_STYLE => "block",
      G_ADDR_SIZE => 16,
      G_DATA_SIZE => 24
    )
    port map (
      a_clk_i     => user_clk_i,
      a_rst_i     => user_rst_i,
      a_addr_i    => user_vga_addr_i,
      a_wr_en_i   => user_vga_wren_i,
      a_wr_data_i => user_vga_data_i,
      a_rd_en_i   => '0',
      a_rd_data_o => open,
      b_clk_i     => vga_clk_i,
      b_rst_i     => vga_rst_i,
      b_addr_i    => vga_addr,
      b_wr_en_i   => '0',
      b_wr_data_i => X"000000",
      b_rd_en_i   => '1',
      b_rd_data_o => vga_rd_data
    ); -- tdp_ram_inst : entity work.tdp_ram

  video_sync_inst : entity work.video_sync
    generic map (
      G_VIDEO_MODE => C_VIDEO_MODE
    )
    port map (
      clk_i     => vga_clk_i,
      rst_i     => vga_rst_i,
      vs_o      => vga_vs,
      hs_o      => vga_hs,
      de_o      => vga_de,
      pixel_x_o => vga_hcount,
      pixel_y_o => vga_vcount
    ); -- video_sync_inst : entity work.video_sync

  video_chars_inst : entity work.video_chars
    generic map (
      G_SCALING    => 3,
      G_FONT_FILE  => "font8x8.txt",
      G_VIDEO_MODE => C_VIDEO_MODE
    )
    port map (
      video_clk_i    => vga_clk_i,
      video_hcount_i => vga_hcount,
      video_vcount_i => vga_vcount,
      video_blank_i  => not vga_de,
      video_rgb_o    => vga_rgb,
      video_x_o      => vga_x,
      video_y_o      => vga_y,
      video_char_i   => vga_char,
      video_colors_i => vga_colors
    ); -- video_chars_inst : entity work.video_chars

  vga_addr       <= vga_y & vga_x;
  vga_char       <= vga_rd_data(7 downto 0);
  vga_colors     <= vga_rd_data(23 downto 8);

  vga_proc : process (vga_clk_i)
  begin
    if rising_edge(vga_clk_i) then
      vga_vs_o    <= vga_vs;
      vga_hs_o    <= vga_hs;
      vga_blue_o  <= (others => '0');
      vga_green_o <= (others => '0');
      vga_red_o   <= (others => '0');

      if vga_de = '1' then
        vga_blue_o  <= vga_rgb(1 downto 0) & vga_rgb(1 downto 0) & vga_rgb(1 downto 0) & vga_rgb(1 downto 0);
        vga_green_o <= vga_rgb(4 downto 2) & vga_rgb(4 downto 2) & vga_rgb(4 downto 3);
        vga_red_o   <= vga_rgb(7 downto 5) & vga_rgb(7 downto 5) & vga_rgb(7 downto 6);
      end if;
    end if;
  end process vga_proc;

  oddr_inst : component oddr
    port map (
      c  => vga_clk_i,
      ce => '1',
      d1 => '1',
      d2 => '0',
      r  => '0',
      s  => '0',
      q  => vdac_clk_o
    ); -- oddr_inst : component oddr

  vdac_blank_n_o <= '1';
  vdac_psave_n_o <= '1';
  vdac_sync_n_o  <= '0';

end architecture synthesis;


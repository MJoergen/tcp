library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library xpm;
  use xpm.vcomponents.all;

library unisim;
  use unisim.vcomponents.all;

entity vga_wrapper is
  port (
    --------------------------------------------------------
    -- Connect to design (everything in user_clk domain)
    --------------------------------------------------------

    user_clk_i      : in   std_logic;  -- 100 MHz
    user_rst_i      : in   std_logic;

    -- VGA frame buffer
    user_vga_addr_i : in    std_logic_vector(15 downto 0);
    user_vga_data_i : in    std_logic_vector(7 downto 0);
    user_vga_wren_i : in    std_logic;

    --------------------------------------------------------
    -- Connect to MEGA65 I/O ports
    --------------------------------------------------------

    -- VGA interface
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
end entity vga_wrapper;

architecture synthesis of vga_wrapper is

  -- VGA
  constant C_VIDEO_MODE : video_modes_type := C_VIDEO_MODE_720_576_50;

begin

  video_sync_inst : entity work.video_sync
    generic map (
      G_VIDEO_MODE => C_VIDEO_MODE
    )
    port map (
      clk_i     => vga_clk,
      rst_i     => vga_rst,
      vs_o      => vga_vs,
      hs_o      => vga_hs,
      de_o      => vga_de,
      pixel_x_o => vga_hcount,
      pixel_y_o => vga_vcount
    ); -- video_sync_inst : entity work.video_sync

  video_chars_inst : entity work.video_chars
    generic map (
      G_SCALING    => 4,
      G_FONT_FILE  => "font8x8.txt",
      G_VIDEO_MODE => C_VIDEO_MODE
    )
    port map (
      video_clk_i    => vga_clk,
      video_hcount_i => vga_hcount,
      video_vcount_i => vga_vcount,
      video_blank_i  => not vga_de,
      video_rgb_o    => vga_rgb,
      video_x_o      => vga_x,
      video_y_o      => vga_y,
      video_char_i   => vga_char,
      video_colors_i => vga_colors
    ); -- video_chars_inst : entity work.video_chars

  vga_proc : process (vga_clk)
  begin
    if rising_edge(vga_clk) then
      vga_vs_o    <= vga_vs;
      vga_hs_o    <= vga_hs;
      vga_blue_o  <= (others => '0');
      vga_green_o <= (others => '0');
      vga_red_o   <= (others => '0');

      if vga_de = '1' then
        vga_blue_o  <= vga_rgb;
        vga_green_o <= vga_rgb;
        vga_red_o   <= vga_rgb;
      end if;
    end if;
  end process vga_proc;

  vga_char_proc : process (vga_clk)
    constant C_POS_X : natural := 10;
    constant C_POS_Y : natural := 10;
    variable col_v   : natural range 0 to 7;
    variable row_v   : natural range 0 to G_DEBUG_LINES - 1;
    variable idx_v   : natural range 0 to G_DEBUG_LINES * 8 - 1;

    pure function to_ascii (
      arg : std_logic_vector(3 downto 0)
    ) return std_logic_vector is
    begin
      if arg < 10 then
        return to_stdlogicvector(character'pos('0') + to_integer(arg), 8);
      else
        return to_stdlogicvector(character'pos('A') + to_integer(arg) - 10, 8);
      end if;
    end function to_ascii;

  --
  begin
    if rising_edge(vga_clk) then
      vga_char   <= x"20";
      vga_colors <= x"AA55";
      if vga_x >= C_POS_X and vga_x < C_POS_X + 8 and
         vga_y >= C_POS_Y and vga_y < C_POS_Y + G_DEBUG_LINES then
        col_v      := 7 - to_integer(vga_x - C_POS_X);
        row_v      := to_integer(vga_y - C_POS_Y);
        idx_v      := row_v * 8 + col_v;
        vga_colors <= x"44BB";
        vga_char   <= to_ascii(vga_lines(idx_v * 4 + 3 downto idx_v * 4));
      elsif vga_invert = '1' then
        vga_char   <= x"21";
        vga_colors <= x"2288";
      end if;
    end if;
  end process vga_char_proc;

  oddr_inst : component oddr
    port map (
      c  => vga_clk,
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


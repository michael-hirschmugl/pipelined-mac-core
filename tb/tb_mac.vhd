library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_mac is
  generic (
    A_WIDTH   : integer := 8;
    B_WIDTH   : integer := 8;
    OUT_WIDTH : integer := 18
  );
end tb_mac;

architecture tb of tb_mac is

  component mac
    generic (
      A_WIDTH   : integer := 8;
      B_WIDTH   : integer := 8;
      OUT_WIDTH : integer := 18
    );
    port (
      a         : in  signed(A_WIDTH-1 downto 0);
      b         : in  signed(B_WIDTH-1 downto 0);
      clk       : in  std_logic;
      reset     : in  std_logic;
      eof       : in  std_logic;
      result    : out signed(OUT_WIDTH-1 downto 0);
      valid_in  : in  std_logic;
      valid_out : out std_logic;
      enable    : in  std_logic
    );
  end component;

  signal a         : signed(A_WIDTH-1 downto 0) := (others => '0');
  signal b         : signed(B_WIDTH-1 downto 0) := (others => '0');
  signal clk       : std_logic := '0';
  signal reset     : std_logic := '0';
  signal eof       : std_logic := '0';
  signal result    : signed(OUT_WIDTH-1 downto 0);
  signal valid_in  : std_logic := '0';
  signal valid_out : std_logic;
  signal enable    : std_logic := '0';

  constant CLK_PERIOD : time := 10 ns;

begin

  dut : mac
    generic map (
      A_WIDTH   => A_WIDTH,
      B_WIDTH   => B_WIDTH,
      OUT_WIDTH => OUT_WIDTH
    )
    port map (
      a         => a,
      b         => b,
      clk       => clk,
      reset     => reset,
      eof       => eof,
      result    => result,
      valid_in  => valid_in,
      valid_out => valid_out,
      enable    => enable
    );

  clk <= not clk after CLK_PERIOD/2;

  stim : process
  begin
    -- Reset/Init
    enable   <= '0';
    reset    <= '1';
    valid_in <= '0';
    eof      <= '0';
    a        <= (others => '0');
    b        <= (others => '0');

    wait until rising_edge(clk);
    wait until rising_edge(clk);

    -- Start
    reset  <= '0';
    enable <= '1';

    -- 1. Paar
    wait until rising_edge(clk);
    valid_in <= '1';
    eof      <= '0';
    a        <= to_signed(1, A_WIDTH);
    b        <= to_signed(1, B_WIDTH);

    -- 2. Paar
    wait until rising_edge(clk);
    eof      <= '0';
    a        <= to_signed(2, A_WIDTH);
    b        <= to_signed(2, B_WIDTH);

    -- 3. Paar
    wait until rising_edge(clk);
    eof      <= '0';
    a        <= to_signed(3, A_WIDTH);
    b        <= to_signed(3, B_WIDTH);

    -- 4. Paar
    wait until rising_edge(clk);
    eof      <= '1';
    a        <= to_signed(4, A_WIDTH);
    b        <= to_signed(4, B_WIDTH);

    -- 1. Paar
    wait until rising_edge(clk);
    valid_in <= '1';
    eof      <= '0';
    a        <= to_signed(1, A_WIDTH);
    b        <= to_signed(1, B_WIDTH);

    -- 2. Paar
    wait until rising_edge(clk);
    eof      <= '0';
    a        <= to_signed(2, A_WIDTH);
    b        <= to_signed(2, B_WIDTH);

    -- 3. Paar
    wait until rising_edge(clk);
    eof      <= '0';
    a        <= to_signed(3, A_WIDTH);
    b        <= to_signed(3, B_WIDTH);

    -- 4. Paar
    wait until rising_edge(clk);
    eof      <= '1';
    a        <= to_signed(4, A_WIDTH);
    b        <= to_signed(4, B_WIDTH);

    -- Inputs aus
    wait until rising_edge(clk);
    valid_in <= '0';
    eof      <= '0';
    a        <= (others => '0');
    b        <= (others => '0');

    while valid_out /= '1' loop
      wait until rising_edge(clk);
    end loop;

    wait until rising_edge(clk);

    wait;
  end process;

end tb;

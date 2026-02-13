library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library std;
use std.env.all;

entity tb_mac is
  generic (
    A_WIDTH              : integer := 8;
    B_WIDTH              : integer := 8;
    OUT_WIDTH            : integer := 18;
    N_SAMPLES            : positive := 15; -- number of sequential value pairs per frame
    EOF_TO_RESULT_CYCLES : natural  := 3   -- cycles to wait AFTER sending the EOF-marked sample
  );
end tb_mac;

architecture tb of tb_mac is

  component mac
    generic (
      A_WIDTH   : positive := 8;
      B_WIDTH   : positive := 8;
      OUT_WIDTH : positive := 17
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

  -- Helper: compute expected sum for the default stimulus pattern
  function expected_sum(n : positive) return signed is
    variable acc : integer := 0;
    variable i   : integer;
  begin
    -- default pattern: a=i, b=i => sum i*i
    for k in 1 to n loop
      i := k;
      acc := acc + (i * i);
    end loop;
    return to_signed(acc, OUT_WIDTH);
  end function;

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
    variable exp : signed(OUT_WIDTH-1 downto 0);
  begin
    exp := expected_sum(N_SAMPLES);

    -- Reset/Init
    enable   <= '0';
    reset    <= '1';
    valid_in <= '0';
    eof      <= '0';
    a        <= (others => '0');
    b        <= (others => '0');

    -- hold reset for 2 cycles
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    -- Start
    reset  <= '0';
    enable <= '1';

    -- Feed N sequential pairs (a=i, b=i), eof on last one
    for i in 1 to N_SAMPLES loop
      wait until rising_edge(clk);
      valid_in <= '1';
      a        <= to_signed(i, A_WIDTH);
      b        <= to_signed(i, B_WIDTH);

      if i = N_SAMPLES then
        eof <= '1';   -- this is the EOF-marked sample
      else
        eof <= '0';
      end if;
    end loop;

    -- Optional: deassert inputs on the next cycle (does not affect the EOF reference point)
    wait until rising_edge(clk);
    valid_in <= '0';
    eof      <= '0';
    a        <= (others => '0');
    b        <= (others => '0');

    -- Wait EXACTLY N cycles after the EOF sample was sent
    -- (Definition: cycles counted in rising edges AFTER the EOF-marked cycle)
    for k in 1 to EOF_TO_RESULT_CYCLES loop
      wait until rising_edge(clk);
    end loop;

    -- Now result must be final for the frame (per chosen offset)
    assert result = exp
      report "FAIL: MAC final result mismatch. Expected=" &
             integer'image(to_integer(exp)) &
             " Got=" &
             integer'image(to_integer(result))
      severity failure;

    report "PASS: MAC final result matched. Expected=" &
           integer'image(to_integer(exp)) &
           " Got=" &
           integer'image(to_integer(result))
      severity note;

    std.env.stop;
    wait;
  end process;

end tb;

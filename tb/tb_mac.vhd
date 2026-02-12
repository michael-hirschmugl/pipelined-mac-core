library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library std;
use std.env.all;

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

  -- ------------------------------------------------------------
  -- Model signals (mirror DUT internal state, but in TB)
  -- ------------------------------------------------------------
  signal m_a_r      : signed(A_WIDTH-1 downto 0) := (others => '0');
  signal m_b_r      : signed(B_WIDTH-1 downto 0) := (others => '0');
  signal m_prod_r   : signed(A_WIDTH+B_WIDTH-1 downto 0) := (others => '0');
  signal m_sum_r    : signed(OUT_WIDTH-1 downto 0) := (others => '0');
  signal m_valid_r1 : std_logic := '0';
  signal m_valid_r2 : std_logic := '0';
  signal m_eof_r1   : std_logic := '0';
  signal m_eof_r2   : std_logic := '0';
  signal m_eof_r3   : std_logic := '1';

  -- "Sample on next clock is valid" => check result when previous cycle had valid_out
  -- We emulate that with a 1-cycle delayed version of m_valid_r2:
  signal m_sample_now : std_logic := '0';

  -- ------------------------------------------------------------
  -- Check counters
  -- ------------------------------------------------------------
  signal checks_ok       : integer := 0;
  signal checks_err      : integer := 0;
  signal checked_samples : integer := 0;

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

  -- ------------------------------------------------------------
  -- Model process: mirrors DUT sequential logic with SIGNAL semantics
  -- ------------------------------------------------------------
  model_proc : process(clk)
    variable prod_resized : signed(OUT_WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then
      if reset = '1' then
        m_sum_r      <= (others => '0');
        m_valid_r1   <= '0';
        m_valid_r2   <= '0';
        m_eof_r1     <= '0';
        m_eof_r2     <= '0';
        m_eof_r3     <= '1';
        m_a_r        <= (others => '0');
        m_b_r        <= (others => '0');
        m_prod_r     <= (others => '0');
        m_sample_now <= '0';

      elsif enable = '1' then
        -- Stage 0
        m_a_r      <= a;
        m_b_r      <= b;
        m_valid_r1 <= valid_in;
        m_eof_r1   <= eof;

        -- Stage 1 (uses old m_a_r/m_b_r just like DUT uses old a_r/b_r)
        m_prod_r   <= m_a_r * m_b_r;
        m_valid_r2 <= m_valid_r1;
        m_eof_r2   <= m_eof_r1;

        -- Stage 2 (uses old m_valid_r2 / old m_prod_r / old m_eof_r3 / old m_sum_r)
        if m_valid_r2 = '1' then
          prod_resized := resize(m_prod_r, OUT_WIDTH);

          if m_eof_r3 = '1' then
            m_sum_r <= prod_resized;
          else
            m_sum_r <= m_sum_r + prod_resized;
          end if;

          m_eof_r3 <= m_eof_r2;
        end if;

        -- This becomes '1' exactly in the cycle when result should be sampled
        -- because RHS uses OLD m_valid_r2 (signal semantics).
        m_sample_now <= m_valid_r2;

      else
        -- enable=0: everything holds; also no sampling should happen
        m_sample_now <= '0';
      end if;
    end if;
  end process;

  -- ------------------------------------------------------------
  -- Postponed checker: runs AFTER signal updates of the clock edge
  -- ------------------------------------------------------------
  check_proc : postponed process(clk)
  begin
    if rising_edge(clk) then
      -- Avoid checking during reset; also avoids initial 'U' surprises
      if reset = '0' then

        -- 1) valid_out should match model valid_r2
        assert (valid_out = m_valid_r2)
          report "valid_out mismatch. Expected=" & std_logic'image(m_valid_r2) &
                 " Got=" & std_logic'image(valid_out)
          severity error;

        -- 2) result should be checked when model says "sample now"
        if m_sample_now = '1' then
          checked_samples <= checked_samples + 1;

          if result = m_sum_r then
            checks_ok <= checks_ok + 1;
          else
            checks_err <= checks_err + 1;
            assert false
              report "RESULT mismatch (sampled when expected). Expected=" &
                     integer'image(to_integer(m_sum_r)) &
                     " Got=" &
                     integer'image(to_integer(result))
              severity error;
          end if;
        end if;

      end if;
    end if;
  end process;

  -- ------------------------------------------------------------
  -- Stimulus: identical structure to your original TB
  -- ------------------------------------------------------------
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

    -- 1. Pair
    wait until rising_edge(clk);
    valid_in <= '1';
    eof      <= '0';
    a        <= to_signed(1, A_WIDTH);
    b        <= to_signed(1, B_WIDTH);

    -- 2. Pair
    wait until rising_edge(clk);
    eof      <= '0';
    a        <= to_signed(2, A_WIDTH);
    b        <= to_signed(2, B_WIDTH);

    -- 3. Pair
    wait until rising_edge(clk);
    eof      <= '0';
    a        <= to_signed(3, A_WIDTH);
    b        <= to_signed(3, B_WIDTH);

    -- 4. Pair (EOF)
    wait until rising_edge(clk);
    eof      <= '1';
    a        <= to_signed(4, A_WIDTH);
    b        <= to_signed(4, B_WIDTH);

    -- 1. Pair
    wait until rising_edge(clk);
    valid_in <= '1';
    eof      <= '0';
    a        <= to_signed(1, A_WIDTH);
    b        <= to_signed(1, B_WIDTH);

    -- 2. Pair
    wait until rising_edge(clk);
    eof      <= '0';
    a        <= to_signed(2, A_WIDTH);
    b        <= to_signed(2, B_WIDTH);

    -- 3. Pair
    wait until rising_edge(clk);
    eof      <= '0';
    a        <= to_signed(3, A_WIDTH);
    b        <= to_signed(3, B_WIDTH);

    -- 4. Pair (EOF)
    wait until rising_edge(clk);
    eof      <= '1';
    a        <= to_signed(4, A_WIDTH);
    b        <= to_signed(4, B_WIDTH);

    -- Inputs off
    wait until rising_edge(clk);
    valid_in <= '0';
    eof      <= '0';
    a        <= (others => '0');
    b        <= (others => '0');

    -- Expect: 8 valid samples total => 8 checks (m_sample_now pulses)
    while checked_samples < 8 loop
      wait until rising_edge(clk);
    end loop;

    assert checks_err = 0
      report "FAIL: MAC mismatches detected. OK=" &
             integer'image(checks_ok) & " ERR=" &
             integer'image(checks_err)
      severity failure;

    report "PASS: All MAC checks matched. OK=" &
           integer'image(checks_ok) & " ERR=" &
           integer'image(checks_err)
      severity note;

    std.env.stop;
    wait;
  end process;

end tb;

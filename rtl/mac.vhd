-- based on https://github.com/michael-hirschmugl/open-hw-cnn/blob/main/src/hdl/LG_MAC_layer1.vhd

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mac is
  generic (
    A_WIDTH   : positive := 8;
    B_WIDTH   : positive := 8;
    OUT_WIDTH : positive := 17
  );
  port (
    a         : in  signed (A_WIDTH-1 downto 0);
    b         : in  signed (B_WIDTH-1 downto 0);
    clk       : in  std_logic;
    reset     : in  std_logic;  -- reset valids and acc
    eof       : in  std_logic;  -- mark last frame sample (clear-on-next-valid after eof)
    result    : out signed (OUT_WIDTH-1 downto 0);
    valid_in  : in  std_logic;  -- inputs can be used
    valid_out : out std_logic;  -- sample on next clock is valid
    enable    : in  std_logic  -- clock enable (streaming ready)
  );
end mac;

architecture behave of mac is
  signal a_r      : signed (A_WIDTH-1 downto 0);
  signal b_r      : signed (B_WIDTH-1 downto 0);
  signal prod_r   : signed (A_WIDTH+B_WIDTH-1 downto 0);
  signal sum_r    : signed (OUT_WIDTH-1 downto 0);
  signal valid_r1 : std_logic;
  signal valid_r2 : std_logic;  -- product ready for accumulator
  signal eof_r1   : std_logic;
  signal eof_r2   : std_logic;
  signal eof_r3   : std_logic;  -- pending "clear between frames"
begin

  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        sum_r    <= (others => '0');
        valid_r1 <= '0';
        valid_r2 <= '0';
        eof_r1 <= '0';
        eof_r2 <= '0';
        eof_r3 <= '1'; -- first valid sample starts fresh
      elsif enable = '1' then
        -- Stage 0: register inputs + valid
        a_r <= a;
        b_r <= b;
        valid_r1 <= valid_in;
        eof_r1 <= eof;

        -- Stage 1: register product + valid
        prod_r <= a_r * b_r;
        valid_r2 <= valid_r1;
        eof_r2 <= eof_r1;

        -- Stage 2: accumulate
        if valid_r2 = '1' then
          if eof_r3 = '1' then
            sum_r <= resize(prod_r, OUT_WIDTH);              -- new frame starts here
          else
            sum_r <= sum_r + resize(prod_r, OUT_WIDTH);      -- keep accumulating
          end if;
          eof_r3 <= eof_r2;
        end if;
      end if;
    end if;
  end process;

  result    <= sum_r;
  valid_out <= valid_r2;
end behave;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TriviumRegs is
    Generic ( DATA_LENGTH : integer := 80 );
    Port( 
        z      : out std_logic;
        clk : in std_logic;
        load  : in std_logic;
            
        K  : in STD_LOGIC_VECTOR (DATA_LENGTH-1 downto 0);
        IV : in STD_LOGIC_VECTOR (DATA_LENGTH-1 downto 0)
        );
end TriviumRegs;

architecture Behavioral of TriviumRegs is

    -----------------------------
    --------- CONSTANTS ---------
    -----------------------------
    constant INIT_STATE_LENGTH : integer := 288;

    -----------------------------
    ---------- SIGNALS ----------
    -----------------------------
    
    attribute srl_style     : string;
    attribute dont_touch    : string;
    
    signal s : std_logic_vector (INIT_STATE_LENGTH-1 downto 0);
    signal t1, t2, t3 : std_logic;
    signal a1, a2,a3 : std_logic;
    
    attribute srl_style of s    : signal is "register";
--    attribute dont_touch of t1  : signal is "true";
--    attribute dont_touch of t2  : signal is "true";
--    attribute dont_touch of t3  : signal is "true";
    
begin
    
    process(clk, load)
    begin
    
    if rising_edge(clk) then
       if (load = '1') then
            s(INIT_STATE_LENGTH-1 downto 0) <= (others => '0');
            s(79  downto 0)   <= K(79 downto 0);
            s(172 downto 93)  <= IV(79 downto 0);
            s(287 downto 285) <= (others => '1');
       else
            s(92 downto 0) <= s(91 downto 0) & t3;
            s(176 downto 93) <= s(175 downto 93) & t1;
            s(287 downto 177) <= s(286 downto 177) & t2;
       end if;
    end if;
    end process;

--f[i] = a4&a5 | (1^a4)&(a1&a2 ^ a3);       // LUT A
--f[i] = (1^a6)&(a4&a5^a1^a2^a3);           // LUT B
--f[i] = a6&a5 | (1^a5)&(a1&a2 ^ a3 ^ a4);  // LUT C

    t1 <= s(65) xor (s(90) and s(91)) xor s(92) xor s(170);
    t2 <= s(161) xor (s(174) and s(175)) xor s(176) xor s(263); 
    t3 <= s(242) xor (s(285) and s(286)) xor s(287) xor s(68);
    
    
--    a1 <= s(90) and s(91);
--    a2 <= s(174) and s(175);
--    a3 <= s(285) and s(286);

--    t1 <= s(65) xor (a1) xor s(92) xor s(170);
--    t2 <= s(161) xor (a2) xor s(176) xor s(263); 
--    t3 <= s(242) xor (a3) xor s(287) xor s(68);

    z <= (s(65) xor s(92)) xor (s(161) xor s(176)) xor (s(242) xor s(287));

end Architecture;
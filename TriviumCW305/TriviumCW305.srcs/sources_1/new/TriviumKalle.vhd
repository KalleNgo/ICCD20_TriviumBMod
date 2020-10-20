----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/27/2019 02:13:27 PM
-- Design Name: 
-- Module Name: TriviumKalle - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--library work;
--use work.TriviumPackage.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TriviumKalle is
    Generic ( DATA_LENGTH : integer := 80 );
    Port( 
        KeyStream   : out std_logic;
        reset       : in std_logic;
        clk         : in std_logic;
        load        : in std_logic;
        init_done   : out std_logic;
        K  : in STD_LOGIC_VECTOR (DATA_LENGTH-1 downto 0);
        IV : in STD_LOGIC_VECTOR (DATA_LENGTH-1 downto 0)
          );
end TriviumKalle;

architecture Behavioral of TriviumKalle is

component TriviumRegs is
    Generic ( DATA_LENGTH : integer := 80 );
    Port( 
        z      : out std_logic;
        clk : in std_logic;
        load  : in std_logic;
            
        K  : in STD_LOGIC_VECTOR (DATA_LENGTH-1 downto 0);
        IV : in STD_LOGIC_VECTOR (DATA_LENGTH-1 downto 0)
        );
end component;

type statetype is (st_idle, st_load, st_init, st_run);

signal current_state, next_state : statetype;
signal init_counter : unsigned(10 downto 0);
signal Output_En    : std_logic;
signal Load_En      : std_logic;
signal z_muxed      : std_logic;

begin

process(clk) 
begin 
    if rising_edge(clk) then
        if (current_state /= st_init) then 
            init_counter <= (others=>'0');
        else 
            init_counter <= init_counter + 1; 
    end if;
  end if; 
end process;

process (current_state, load, init_counter)
begin

case (current_state) is

    when st_idle =>
        Output_En <= '0';
        Load_En <= '0';
        if (load = '1') then
            next_state <= st_load;
        else
            next_state <= current_state;
        end if;
        
    when st_load =>
        Output_En <= '0';
        Load_En <= '1';
        next_state <= st_init;
        
    when st_init =>
        Output_En <= '0';
        Load_En <= '0';
        if (init_counter >= 4*288) then
            next_state <= st_run;
        else
            next_state <= current_state;
        end if;
        
    when st_run =>
        Output_En <= '1';
        Load_En <= '0';
        next_state <= st_run;
end case;

end process;



process (clk, reset)
begin
    if (reset = '1') then
        current_state <= st_idle;
    elsif rising_edge(clk) then
        current_state <= next_state;
    end if;
end process;

TriviumLFSR: TriviumRegs
    Generic map(DATA_LENGTH => DATA_LENGTH )
    Port map( 
        z => z_muxed,
        clk => clk,
        load => Load_EN,
        K => K,
        IV => IV
        );

KeyStream <= z_muxed when Output_EN = '1' else '0';
init_done <= Output_EN;

end Architecture;
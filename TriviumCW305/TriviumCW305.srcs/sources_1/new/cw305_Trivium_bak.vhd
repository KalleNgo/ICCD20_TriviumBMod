------------------------------------------------------------------------------
-- Trivium Cipher for CW305 Target 
--
-- Author:      Kalle Ngo (kngo@kth.se)
--              KTH Royal Institute of Technology, Sweden
-- Date:        Janurary 2nd, 2020
-- Notes:       
--
-- THIS CODE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES OF
-- ANY KIND, EXPRESSED OR IMPLIED. THE FOLLOWING CODE PROBRABLY DOESN'T EVEN
-- WORK, LET ALONE COMPILE.. USE AT YOUR OWN RISK! TLDR:Please don't sue me =)
------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.math_real.all;
--use IEEE.math_real."log2";

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity cw305_top is
  Generic(
    CHALLENGE_WIDTH     : integer:=128;
    CRYPTO_TEXT_WIDTH   : integer:=80;
    CRYPTO_KEY_WIDTH    : integer:=80;
    CRYPTO_CIPHER_WIDTH : integer:=1024
  );
  Port (
    -- USB Interface
    usb_clk     : in std_logic;
    usb_data    : inout std_logic_vector(7 downto 0);
    usb_addr    : in std_logic_vector(20 downto 0);
    usb_rdn     : in std_logic;
    usb_wrn     : in std_logic;
    usb_cen     : in std_logic;
    usb_trigger : in std_logic;
    
    -- Buttons/LEDs on Board
    sw1         : in std_logic;     -- DIP switch J16 
    sw2         : in std_logic;     -- DIP switch K16 
    sw3         : in std_logic;     -- DIP switch K15 
    sw4         : in std_logic;     -- DIP Switch L14 
    
    pushbutton  : in std_logic;     -- Pushbutton SW4, connected to R1
    
    led1        : out std_logic;    -- red LED
    led2        : out std_logic;    -- green LED
    led3        : out std_logic;    -- blue LED
    
    -- PLL
    pll_clk1    : in std_logic;     -- PLL Clock Channel #1
    --pll_clk2    : in std_logic;     -- PLL Clock Channel #2
    
    -- 20-Pin Connector Stuff 
    tio_trigger : out std_logic;
    tio_clkout  : out std_logic;
    tio_clkin   : in std_logic
  );
end cw305_top;

architecture Behavioral of cw305_top is

    component usb_module
        generic(                        -- Default memory width = 256 bytes (0x100)
            MEMORY_WIDTH    : integer;  -- 2^8
            MEMORY_BYTES    : integer;  -- 256 bytes
            MEMORY_MASK     : integer   -- 0xFF mask
        );
        port(
            clk_usb         : in std_logic;
            data            : inout std_logic_vector(7 downto 0);
            addr            : in std_logic_vector(20 downto 0);
            rd_en           : in std_logic;
            wr_en           : in std_logic;
            cen             : in std_logic;
            trigger         : in std_logic;
            clk_sys         : out std_logic;                    -- Memory bus clock (buffered)
            memory_input    : out std_logic_vector(MEMORY_BYTES*8-1 downto 0);   -- Memory bus for input from serial. Upper half of memory
            memory_output   : in std_logic_vector(MEMORY_BYTES*8-1 downto 0)     -- Memory bus for output to serial.  Lower half of memory
        );
    end component;
    
    component registers is
        generic (
            MEMORY_WIDTH        : integer; -- 2^8
            MEMORY_BYTES        : integer; -- 256 bytes
            KEY_WIDTH           : integer;
            PT_WIDTH            : integer;
            CT_WIDTH            : integer;
            done_edge_sensitive : integer
        );
        port (
            -- Interface to Memory Bus
            mem_clk         : in std_logic;
            mem_output      : out std_logic_vector(MEMORY_BYTES*8-1 downto 0);
            mem_input       : in std_logic_vector(MEMORY_BYTES*8-1 downto 0);
            -- LEDs
            user_led        : out std_logic;
            kalle_rst       : out std_logic;
            -- DIP Switches
            dipsw_1         : in std_logic;
            dipsw_2         : in std_logic;
            -- Other Hardware
            exttrigger_in   : in std_logic;
            -- Clock Sources
            pll_clk1        : in std_logic;
            cw_clkin        : in std_logic;
            cw_clkout       : out std_logic;
            -- Module Type
            crypt_type      : in std_logic_vector(7 downto 0);
            crypt_rev       : in std_logic_vector(7 downto 0);
            -- Interface to Crypto Core
            cryptoclk       : out std_logic;
            key             : out std_logic_vector(KEY_WIDTH-1 downto 0);
            textin          : out std_logic_vector(PT_WIDTH-1 downto 0);
            textout         : in std_logic_vector(PT_WIDTH-1 downto 0);
            cipherin        : out std_logic_vector(CT_WIDTH-1 downto 0);
            cipherout       : in std_logic_vector(CT_WIDTH-1 downto 0);
            -- Init wire doesn't work
            init            : out std_logic; -- High for one cryptoclk cycle, key valid (i.e.: do init stuff) */
            ready           : in std_logic; -- Crypto core ready. Tie to '1' if not used. */
            start           : out std_logic; -- High for one cryptoclk cycle, indicates text ready. */
            done            : in std_logic -- Crypto done. Can be high for one cryptoclk cycle or longer. */
        );
    end component;
        
--    component aes_core is
--        port (
--            clk     : in std_logic;
--            load_i  : in std_logic;
--            key_i   : in std_logic_vector(255 downto 0);
--            data_i  : in std_logic_vector(127 downto 0);
--            size_i  : in std_logic_vector(1 downto 0);
--            dec_i   : in std_logic;
--            data_o  : out std_logic_vector(127 downto 0);
--            busy_o  : out std_logic
--        );
--    end component;
    
--    component puf_challenge is
--        port(
--            clk         : in std_logic;
--            start       : in std_logic;
--            reset       : in std_logic;
--            Chall_i     : in std_logic_vector(127 downto 0);
--            Response_o  : out std_logic;
--            busy_o      : out std_logic
--        );
--        end component;
    
    component TriviumKalle is
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
    end component;

    
    signal usb_clk_buf : std_logic;
    signal usb_timer_heartbeat : std_logic_vector(24 downto 0);    -- USB CLK Heartbeat
    signal crypt_clk_heartbeat : std_logic_vector(22 downto 0);    -- CRYPT CLK Heartbeat
   
                   
    -- Connections between crypto module & registers
    signal crypt_clk        : std_logic;
    signal crypt_key        : std_logic_vector(CRYPTO_TEXT_WIDTH-1 downto 0);
    signal crypt_textin     : std_logic_vector(CRYPTO_TEXT_WIDTH-1 downto 0);
    signal crypt_textout    : std_logic_vector(CRYPTO_KEY_WIDTH-1 downto 0);
    signal crypt_cipherin   : std_logic_vector(CRYPTO_CIPHER_WIDTH-1 downto 0); 
    signal crypt_init       : std_logic;
    signal crypt_ready      : std_logic;
    signal crypt_start      : std_logic;
    signal crypt_done       : std_logic;
    
    -- USB Interface
    signal memory_input : std_logic_vector(1024*8-1 downto 0);
    signal memory_output : std_logic_vector(1024*8-1 downto 0);
    
    -- AES Core 
    signal aes_clk      : std_logic;
    signal aes_key      : std_logic_vector(127 downto 0);
    signal aes_pt       : std_logic_vector(127 downto 0);
    signal aes_ct       : std_logic_vector(127 downto 0);
    signal aes_load     : std_logic;
    signal aes_busy     : std_logic;
    signal kalle        : std_logic;
    
    -- Trivium Core
    signal Triv_rst     : std_logic;
    signal Triv_clk     : std_logic;
    signal Triv_initDone: std_logic;
    signal Triv_buffer  : std_logic_vector(1024-1 downto 0);
    signal Triv_count   : integer;
    signal Triv_status  : std_logic;
    signal Triv_load    : std_logic;
    signal count_EN     : std_logic;
    
     type statetype is (st_reset, st_load, st_init, st_run, st_store, st_stop);
     signal current_state, next_state : statetype;    
    
    -- PUF Core 
    
    signal puf_rst      : std_logic;
    signal puf_Chall    : std_logic_vector(127 downto 0);
    signal puf_Rsp      : std_logic_vector(127 downto 0);
    signal puf_start    : std_logic;
    signal puf_busy     : std_logic;

    function reverse_any_vector (a: in std_logic_vector)
    return std_logic_vector is
      variable result: std_logic_vector(a'RANGE);
      alias aa: std_logic_vector(a'REVERSE_RANGE) is a;
    begin
      for i in aa'RANGE loop
        result(i) := aa(i);
      end loop;
      return result;
    end; -- function reverse_any_vector

begin

    led1 <= usb_timer_heartbeat(24);
    led2 <= crypt_clk_heartbeat(22);
    
    -- Set up USB with memory registers
    my_usb: usb_module
        generic map( 
            MEMORY_WIDTH => 10, --2^10 = 1024 = 0x400 bytes each for input and output memory
            MEMORY_BYTES => 1024,
            MEMORY_MASK => 1024-1
            )
        port map(
            clk_usb     => usb_clk,
            data        => usb_data,
            addr        => usb_addr,
            rd_en       => usb_rdn,
            wr_en       => usb_wrn,
            cen         => usb_cen,
            trigger     => usb_trigger,
            clk_sys     => usb_clk_buf,
            memory_input => memory_input,
            memory_output => memory_output
    );   
    
    -- REGISTERS
    reg_inst: registers
        generic map( 
            MEMORY_WIDTH        => 10,  -- 2^10 = 1024 = 0x400 bytes each for input and output memory
            MEMORY_BYTES        => 1024,
            KEY_WIDTH           => 80, -- was 128
            PT_WIDTH            => 80, -- PlainText was 128
            CT_WIDTH            => 1024, -- CipherText -- was 128
            done_edge_sensitive => 1
            )
        port map(
            -- Interface to Memory Bus
            mem_clk         => usb_clk_buf,
            mem_input       => memory_input,
            mem_output      => memory_output,
            -- LEDs
            user_led        => open, --led3,
            -- DIP Switches
            dipsw_1         => sw1,
            dipsw_2         => sw2,
            -- Other Hardware
            exttrigger_in   => usb_trigger,
            -- Clock Sources
            pll_clk1        => pll_clk1,
            cw_clkin        => tio_clkin,
            cw_clkout       => tio_clkout,
            -- Module Type
            crypt_type      => std_logic_vector(to_unsigned(2,8)),
            crypt_rev       => std_logic_vector(to_unsigned(3,8)),
            -- Interface to Crypto Core
            cryptoclk       => crypt_clk,
            kalle_rst       => puf_rst,
            key             => crypt_key,
            textin          => crypt_textout,
            textout         => crypt_textin, -- not in my python
            cipherout       => crypt_cipherin,
            init            => crypt_init,
            ready           => crypt_ready,
            start           => crypt_start,
            done            => crypt_done
    );
    
   

    
-- The example test AES Core will replace with PUF stuff -------------
    
--    kalle <= aes_key & std_logic_vector(to_unsigned(0,128));
--    google_aes: aes_core
--        port map (
--        clk         => aes_clk,
--        load_i      => aes_load,
--        key_i       => kalle,
--        data_i      => aes_pt,
--        size_i      => (others => '0'), -- AES128
--        dec_i       => '0', -- enc mode
--        data_o      => aes_ct,
--        busy_o      => aes_busy
--    );
    
--    aes_clk <= crypt_clk;
--    aes_key <= crypt_key;
--    aes_pt <= crypt_textout;
--    crypt_cipherin <= aes_ct;
--    aes_load <= crypt_start;
--    crypt_ready <= '1';
--    crypt_done <= not aes_busy;
--    tio_trigger <= aes_busy;
    
 -- END test AES Core ----------------------------------------------
 
 
 
 -- START PUF Core ---------------------------------------------
--     PUF_ARB: puf_challenge 
--        port map (
--            clk => puf_clk,
--            start => puf_start,
--            reset => puf_rst,
--            Chall_i => puf_Chall,
--            Response_o => kalle,
--            busy_o => puf_busy
--        );
     
--     crypt_cipherin <= std_logic_vector(to_unsigned(0,127)) & kalle;
--     puf_clk <= crypt_clk;
--     puf_Chall <= crypt_textout;
----     puf_Rsp <= crypt_textout;
----     crypt_cipherin <= puf_Rsp;
--     puf_start <= crypt_start;
--     crypt_ready <= '1';
--     crypt_done <= not puf_busy; -- should go to '0' when done
--     tio_trigger <= puf_busy;
 -- END PUF Core ----------------------------------------------
 
 
  -- START Trivium Core ---------------------------------------------
     Triv_Core: TriviumKalle
    Generic map( DATA_LENGTH => 80 )
    Port map( 
        KeyStream => kalle,
        reset     => Triv_rst,
        clk       => crypt_clk,
        load      => Triv_load,
        init_done => Triv_initDone,
        K         => crypt_key,
        IV        => crypt_textout
        
          );
--     crypt_start,
     

--     led3 <=crypt_start;
    process(crypt_clk) 
    begin 
        if rising_edge(crypt_clk) then
            if (current_state /= st_run) then 
                Triv_count <= 0;
                
            else
                Triv_count <= Triv_count + 1; 
                Triv_buffer(Triv_count) <= Kalle;
            end if;
      end if; 
    end process;


    process (crypt_clk, crypt_start)
    begin
        if (crypt_start = '0') then
            current_state <= st_reset;
        elsif rising_edge(crypt_clk) then
            current_state <= next_state;
        end if;
    end process;

     process (all) --current_state,Triv_count,crypt_clk)
     begin
     led3<='0';
     Triv_load<='0';
    Triv_status<='0';
    Triv_rst <='0';
    count_EN <='0';
    next_state <= current_state;
    crypt_cipherin <= (others =>'0');
    
    case (current_state) is

    when st_reset =>
        led3 <='0';
--        Triv_count <= 0;
        Triv_status <= '1';
        Triv_load <= '0';
        Triv_rst <= '1';
        next_state <= st_load;
        
    when st_load =>
        led3 <='0';
        Triv_status <= '0';
        Triv_load <= '1';
        Triv_rst <= '0';
        next_state <= st_init;
        
    when st_init =>
        Triv_status <= '0';
        Triv_load <= '0';
        Triv_rst <= '0';     
--        led3 <='1';   
        if (Triv_initDone = '1') then
            count_EN <='1';
--            Triv_buffer(0) <= Kalle;
            next_state <= st_run;
        else 
            next_state <= st_init;
        end if;
        
    when st_run =>
        led3 <='1';
        Triv_status <= '0';
        Triv_load <= '0';
        count_EN <='1';
--        if (Triv_count <=1023) then
--            Triv_buffer(Triv_count) <= Kalle;
--            Triv_count <= Triv_count + 1;
--        els
--        if (Triv_count <= -1) then
--        Triv_buffer(Triv_count) <= Kalle;
        if (Triv_count >= 1022) then
            next_state <= st_store;
        end if;
     when st_store =>
        led3 <='0';
        Triv_status <= '0';
        crypt_cipherin <= reverse_any_vector(Triv_buffer);
        next_state <= st_stop;
        
     when st_stop =>
        led3 <='0';
        Triv_status <= '1';
        next_state <= st_stop;
     end case;
     
     end process;
     


--     process (crypt_clk, kalle,Triv_rst)
     
--     begin
--        if (crypt_start = '0') then
--            Triv_count <= 0;
--            Triv_status <= '0';
--        elsif (rising_edge(crypt_clk)) then
--            Triv_status <='0';
--            if (Triv_initDone = '1') then
----                if (Triv_count <= 1024) then
--                    Triv_buffer(Triv_count) <= Kalle;
--                    Triv_count <= Triv_count + 1;
----                end if;
--            end if;
--            if (Triv_count >= 1024) then
--                crypt_cipherin <= Triv_buffer;
--                Triv_status <='1';
--                Triv_count <= 0;
--            end if;
--        end if;
--     end process;
     
     

     
--     crypt_cipherin <= std_logic_vector(to_unsigned(0,127)) & kalle;
--     Triv_clk <= crypt_clk;
--     puf_Chall <= crypt_textout;
--     puf_Rsp <= crypt_textout;
--     crypt_cipherin <= puf_Rsp;
--     puf_start <= crypt_start;
     crypt_ready <= '1';
     crypt_done <= not Triv_status; -- should go to '0' when done
     tio_trigger <= Triv_status;
  
  
  
  ---- END Trivium Core ---------------------------------------------
  
  
  
  
    process (usb_clk_buf)
    begin
        if rising_edge(usb_clk_buf) then
            usb_timer_heartbeat <= std_logic_vector(unsigned(usb_timer_heartbeat) + 1);
        end if;
    end process;
  
    process (crypt_clk)
    begin
        if rising_edge(crypt_clk) then
            crypt_clk_heartbeat <= std_logic_vector(unsigned(crypt_clk_heartbeat) + 1);
        end if;
    end process;
    

end Behavioral;

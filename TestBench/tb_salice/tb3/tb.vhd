library IEEE;

use IEEE.NUMERIC_STD.ALL; 	-- tipi signed e unsigned
use IEEE.STD_LOGIC_1164.ALL;

-- nome entità e porte da NON modificare
entity project_reti_logiche is
	port (
		i_clk		: in std_logic; 			              -- segnale di clock
		i_rst		: in std_logic; 			              -- segnale di reset
		i_start		: in std_logic; 			              -- segnale di inizio
		i_add		: in std_logic_vector(15 downto 0); 	  -- indirizzo di partenza
		i_k		    : in std_logic_vector(9 downto 0);     	  -- numero di valori da computare

		o_done		: out std_logic; 			              -- segnale di fine ciclo

		o_mem_addr	: out std_logic_vector(15 downto 0); 	  -- indirizzo della RAM
		i_mem_data	: in std_logic_vector(7 downto 0); 	      -- dato letto dalla RAM
		o_mem_data	: out std_logic_vector(7 downto 0); 	  -- dato da scrivere nella RAM
		o_mem_we 	: out std_logic; 			              -- WRITE enable
		o_mem_en 	: out std_logic 			              -- RAM enable
	     );
end project_reti_logiche;

architecture project_reti_logiche_arch of project_reti_logiche is

component fsm is
	port(
		i_clk		      : in std_logic; 	  -- segnale di clock
		i_rst		      : in std_logic; 	  -- segnale di reset: porta nello stato iniziale
		
		i_start 		  : in std_logic; 	  -- segnale di start
		
		i_end             : in std_logic;     -- segnale di fine ciclo (confronto positivo)
		i_zero            : in std_logic;     -- read zero from ram

		o_done		      : out std_logic;	  -- segnale di uscita

		o_mux_addr		  : out std_logic;    -- segnale di selezione indirizzo ram: indirizzo da leggere o da scrivere
        o_mux_write       : out std_logic;    -- seleziona se scrivere aff o val
		o_mux_aff         : out std_logic;    -- seleziona se salvare 31 o il vecchio valore - 1 nel registro
		
		o_en_reg_aff      : out std_logic;    -- segnale di enable registro affidabilità
		o_en_reg_val      : out std_logic;    -- segnale di enable registro lettura memoria
		o_en_counter   	  : out std_logic;	  -- contatore
		o_en_ram	      : out std_logic; 	  -- segnale di enable ram

		o_rw_ram	      : out std_logic; 	  -- segnale di lettura/scrittura ram
		
		fsm_rst           : out std_logic     -- segnale di reset dato dalla macchina a stati
	);
end component;

component extension is
    -- A <= B
    generic(
        A : integer := 16;      -- lunghezza input
        B : integer := 16       -- lunghezza output
    );
    port(
        i_ext : in std_logic_vector((A - 1) downto 0);
        o_ext : out std_logic_vector((B - 1) downto 0)
    );
 end component;
 
 component shifter is
    generic (N : integer := 10);
    port(
        i_shift : in std_logic_vector((N - 1) downto 0);
        o_shift : out std_logic_vector((N - 1) downto 0)
    );
end component;

component comparator is
    generic(N : integer := 8);					             -- lunghezza valore input
	port(
		i_a	    : in std_logic_vector((N - 1) downto 0);	 -- primo valore
		i_b 	: in std_logic_vector((N - 1) downto 0);	 -- secondo valore

		o_comp	: out std_logic					             -- risultato
	);
end component;

component adder is
    generic(N : integer := 8); 					                -- lunghezza valori in ingresso
	port(
		i_a 	: in std_logic_vector((N - 1) downto 0); 	    -- primo valore
		i_b 	: in std_logic_vector((N - 1) downto 0); 	    -- secondo valore
		
		i_sel   : in std_logic;                                 -- scelta operazione

		o_add 	: out std_logic_vector((N - 1) downto 0) 	    -- valore di uscita

	);
end component;

component mux is
    generic(N : integer := 8); 					            -- input len: 16, 8, 1
	port(
		i_a 	: in std_logic_vector((N - 1) downto 0); 	-- first value in input
		i_b 	: in std_logic_vector((N - 1) downto 0); 	-- second value in input
		
		o_mux 	: out std_logic_vector((N - 1) downto 0); 	-- output

		i_sel 	: in std_logic	 				            -- select bit
	);
end component;

component counter is
generic(N : natural := 10);
    port(
        i_clk  :    in std_logic;	                      -- segnale di clock
        i_en   :	in std_logic;                         -- segnale di enable
	    i_rst  :	in std_logic;                         -- segnale di reset

	    o_count  :	out std_logic_vector(n-1 downto 0)    -- valore di uscita
);
end component;

component reg is
    generic(N : integer := 8); 					            -- es: reg16, reg8, ...
	port(		
		i_clk	: in std_logic; 				            -- segnale di clock
		i_rst	: in std_logic; 				            -- segnale di reset
		i_en	: in std_logic;	 				            -- segnale di enable

		i_val	: in std_logic_vector((N - 1) downto 0); 	-- valore letto in ingresso
		o_val	: out std_logic_vector((N - 1) downto 0) 	-- valore letto in uscita
	);
end component;

component or_gate is
    port(
        i_a     : in std_logic;
        i_b     : in std_logic;
        o_or    : out std_logic
    );
end component;

-- segnali di uscita dai comparatori
signal s_end        : std_logic;        -- contatore = K 
signal s_zero       : std_logic;        -- lettura di uno zero dalla memoria
-- segnali di controllo dei mux
signal mux_addr     : std_logic;        -- indirizzo memoria
signal mux_write    : std_logic;        -- data input memoria
signal mux_aff      : std_logic;        -- data input registro affidabilità
-- segnali di enable
signal en_reg_aff   : std_logic;
signal en_reg_val   : std_logic;
signal en_counter   : std_logic;
-- segnale di uscita dal counter
signal count        : std_logic_vector(9 downto 0);
-- segnale di uscita extension
signal ext          : std_logic_vector(15 downto 0); 
-- segnale di uscita shifter
signal shift        : std_logic_vector(15 downto 0);
-- indirizzi memoria
signal val_addr     : std_logic_vector(15 downto 0);
signal aff_addr     : std_logic_vector(15 downto 0);
-- segnali val e aff in uscita dai due rispettivi registri
signal val          : std_logic_vector(7 downto 0);
signal aff          : std_logic_vector(7 downto 0);
-- segnali logica calcolo affidabilità
signal aff_less_one : std_logic_vector(7 downto 0); -- valore registro - 1
signal new_aff      : std_logic_vector(7 downto 0); -- input registo
signal aff_sel      : std_logic_vector(7 downto 0);
signal aff_zero     : std_logic; -- segnale aff = 0
-- segnale di reset interno
signal rst          : std_logic;
signal fsm_rst      : std_logic;

begin

fsm_controller : fsm 
    port map(
        i_clk           => i_clk,
        i_rst           => i_rst,
        
        i_start         => i_start,     -- segnale di inizio
        
        i_end           => s_end,
        i_zero          => s_zero,
        
        o_done          => o_done,      -- segnale di fine
        
        o_mux_addr      => mux_addr,
        o_mux_write     => mux_write,
        o_mux_aff       => mux_aff,
        
        o_en_reg_aff    => en_reg_aff,
        o_en_reg_val    => en_reg_val,
        o_en_counter    => en_counter,
        
        o_en_ram        => o_mem_en,
        o_rw_ram        => o_mem_we,
        
        fsm_rst         => fsm_rst
    );
    
counter_controller : counter
    generic map(10)
    port map(
        i_clk   => i_clk,
        i_en    => en_counter,
        i_rst   => rst,
        o_count => count
    );
    
counter_comparator : comparator
    generic map(10)
    port map(
        i_a     => i_k,
        i_b     => count,
        o_comp  => s_end        -- flag uguaglianza
    ); 

extension_controller : extension
    generic map(10, 16)     -- input len = 10, output len = 16 ( A < B !!)
    port map(
        i_ext => count,
        o_ext => ext            -- valore esteso
    );

shifter_controller : shifter
    generic map(16)
    port map(
        i_shift => ext,
        o_shift => shift        -- input * 2
    );

first_address_adder : adder
    generic map(16)
    port map(
        i_a     => i_add,
        i_b     => shift,
        i_sel   => '0',         -- somma
        o_add   => val_addr
    );
    
second_address_adder : adder
    generic map(16)
    port map(
        i_a     => val_addr,
        i_b     => "0000000000000001",
        i_sel   => '0',
        o_add   => aff_addr
    );
    
mux_address : mux
    generic map(16)
    port map(
        i_a     => val_addr,
        i_b     => aff_addr,
        o_mux   => o_mem_addr,
        i_sel   => mux_addr
    );
       
val_read_comparator : comparator
    generic map(8)
    port map(
        i_a     => i_mem_data,
        i_b     => (others => '0'), -- valore 0
        o_comp  => s_zero
    );
    
val_register : reg
    generic map(8)
    port map(
        i_clk   => i_clk,
        i_rst   => rst,
        i_en    => en_reg_val,
        i_val   => i_mem_data,
        o_val   => val
    );
    
mux_aff_controller : mux
    generic map(8)
    port map(
        i_a     => "00011111",      -- 31 = 0x1f
        i_b     => aff_sel,
        o_mux   => new_aff,
        i_sel   => mux_aff
    ); 
    
aff_register : reg
    generic map(8)
    port map(
        i_clk   => i_clk,
        i_rst   => rst,
        i_en    => en_reg_aff,
        i_val   => new_aff,
        o_val   => aff
    );
    
reg_aff_adder : adder
    generic map(8)
    port map(
        i_a     => aff,
        i_b     => "00000001",
        i_sel   => '1',             -- sottrazione
        o_add   => aff_less_one
    );
    
check_zero_controller : comparator
    generic map(8)
    port map(
        i_a => aff,
        i_b => "00000000",
        o_comp => aff_zero
    );
    
mux_aff_add : mux
    generic map(8)
    port map(
        i_a => aff_less_one,
        i_b => "00000000",
        i_sel => aff_zero,
        o_mux => aff_sel
    );
  
mux_write_ram : mux
    generic map(8)
    port map(
        i_a     => val,
        i_b     => aff,
        o_mux   => o_mem_data,
        i_sel   => mux_write
    );

or_gate_controller : or_gate
    port map(
        i_a => i_rst,
        i_b => fsm_rst,
        o_or => rst
    );
end architecture;

-----------------------------------------------------------------------------

-----------------------
-- Registro generale --
-----------------------

library IEEE;

library ieee ;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity reg is
    generic(N : integer := 8); 					            -- es: reg16, reg8, ...
	port(		
		i_clk	: in std_logic; 				            -- segnale di clock
		i_rst	: in std_logic; 				            -- segnale di reset
		i_en	: in std_logic;	 				            -- segnale di enable

		i_val	: in std_logic_vector((N - 1) downto 0); 	-- valore letto in ingresso
		o_val	: out std_logic_vector((N - 1) downto 0) 	-- valore letto in uscita
	);
end reg;

architecture reg_arh of reg is
	signal stored_val : std_logic_vector((N - 1) downto 0); -- valore memorizzato
begin
	o_val <= stored_val; 						            --in uscita il valore salvato nel registro

	reg_process : process(i_clk, i_rst, i_en) 
	begin
		if i_rst = '1' then 					            -- segnale di reset asincrono
			stored_val <= (others => '0');			        -- azzera il valore nel registro

		elsif (i_clk = '1' and i_clk'event) then 		    -- fronte di salita del clock
			if i_en = '1' then 				                -- segnale di enable attivo
				stored_val <= i_val; 			            -- salva il nuovo valore in ingresso
		    end if;
		end if;
	end process;
end architecture;

-----------------------------------------------------------------------------------------

-------------
-- Counter --
-------------

library ieee ;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity counter is
generic(N : natural := 10);
    port(
        i_clk  :    in std_logic;	                      -- segnale di clock
        i_en   :	in std_logic;                         -- segnale di enable
	    i_rst  :	in std_logic;                         -- segnale di reset

	    o_count  :	out std_logic_vector(n-1 downto 0)    -- valore di uscita
);
end counter;

architecture counter_arch of counter is		 	  
signal saved_val : std_logic_vector((N - 1) downto 0);
--signal temp : std_logic_vector((N -1) downto 0);
begin
    counter_process : process(i_en, i_clk, i_rst)
    begin
        if i_rst = '1' then
            saved_val <= (others => '0');     -- reset asincrono
            
        elsif (i_clk = '1' and i_clk'event) then
            if i_en = '1' then
              saved_val <= saved_val + 1;
            end if;
        end if;
    end process;	
	
    o_count <= saved_val;                 -- valore in uscita

end counter_arch;

--------------------------------------------------------------------------------

--------------------------------
-- Multiplexer a due ingressi --
--------------------------------

library IEEE;

use IEEE.STD_LOGIC_1164.ALL;

entity mux is
    generic(N : integer := 8); 					            -- input len: 16, 8, 1
	port(
		i_a 	: in std_logic_vector((N - 1) downto 0); 	    -- first value in input
		i_b 	: in std_logic_vector((N - 1) downto 0); 	    -- second value in input
		
		o_mux 	: out std_logic_vector((N - 1) downto 0); 	-- output

		i_sel 	: in std_logic	 				            -- select bit
	);
end mux;

architecture mux_arc of mux is
begin
    o_mux <= i_a when i_sel = '0' else
             i_b when i_sel = '1' else
             (others => 'Z');
end architecture;

------------------------------------------------------------------------------------

-----------
-- Adder --
-----------

library IEEE;

use IEEE.NUMERIC_STD.ALL; 	-- tipi signed e unsigned
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith;

entity adder is
    generic(N : integer := 8); 					            -- lunghezza valori in ingresso
	port(
		i_a 	: in std_logic_vector((N - 1) downto 0); 	    -- primo valore
		i_b 	: in std_logic_vector((N - 1) downto 0); 	    -- secondo valore
		
		i_sel   : in std_logic;                           -- scelta operazione

		o_add 	: out std_logic_vector((N - 1) downto 0) 	-- valore di uscita

	);
end adder;

architecture adder_arch of adder is
	signal sum 	: UNSIGNED((N - 1) downto 0);			-- variabile temporanea per la somma
begin
    o_add <= std_logic_vector(sum);				-- cast esplicito
    
   
    with i_sel select
        sum <=  UNSIGNED(i_a) + UNSIGNED(i_b) when '0',
                UNSIGNED(i_a) - UNSIGNED(i_b) when '1',
                (others => '0') when others;

end architecture;

-----------------------------------------------------------------------------------------

---------------------------
-- Confronta uguaglianza --
---------------------------
library IEEE;

use IEEE.STD_LOGIC_1164.ALL;

entity comparator is
    generic(N : integer := 8);					         -- lunghezza valore input
	port(
		i_a	    : in std_logic_vector((N - 1) downto 0);	 -- primo valore
		i_b 	: in std_logic_vector((N - 1) downto 0);	 -- secondo valore

		o_comp	: out std_logic					         -- risultato
	);
end comparator;

architecture comparator_arch of comparator is
begin
    o_comp <= '1' when i_a = i_b else
              '0';
end architecture;

-----------------------------------------------------------------------------------------------

-------------
-- Shifter --
-------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity shifter is
    generic (N : integer := 10);
    port(
        i_shift : in std_logic_vector((N - 1) downto 0);
        o_shift : out std_logic_vector((N - 1) downto 0)
    );
end shifter;

architecture shifter_arch of shifter is
begin
    o_shift <= i_shift((N - 2) downto 0) & '0';     -- moltiplica per due
end architecture;

-----------------------------------------------------------------------------------------

----------------
-- Estensione --
----------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity extension is
    -- A <= B
    generic(
        A : integer := 16;      -- lunghezza input
        B : integer := 16       -- lunghezza output
    );
    port(
        i_ext : in std_logic_vector((A - 1) downto 0);
        o_ext : out std_logic_vector((B - 1) downto 0)
    );
 end extension;
 
 architecture extension_arch of extension is
 begin
    o_ext((A - 1) downto 0) <= i_ext;
    o_ext((B - 1) downto A) <= (others => '0');
end architecture;

--------------------------------------------------------------------------------------------------------

------------------------------------------------------
-- FSM che gestisce gli stati e i segnali di enable --
------------------------------------------------------
library IEEE;

use IEEE.NUMERIC_STD.ALL; 	-- tipi signed e unsigned
use IEEE.STD_LOGIC_1164.ALL;

entity fsm is
	port(
		i_clk		      : in std_logic; 	  -- segnale di clock
		i_rst		      : in std_logic; 	  -- segnale di reset: porta nello stato iniziale
		
		i_start 		  : in std_logic; 	  -- segnale di start
		
		i_end             : in std_logic;     -- segnale di fine ciclo (confronto positivo)
		i_zero            : in std_logic;     -- read zero from ram

		o_done		      : out std_logic;	  -- segnale di uscita

		o_mux_addr		  : out std_logic;    -- segnale di selezione indirizzo ram: indirizzo da leggere o da scrivere
        o_mux_write       : out std_logic;    -- seleziona se scrivere aff o val
		o_mux_aff         : out std_logic;    -- seleziona se salvare 31 o il vecchio valore - 1 nel registro
		
		o_en_reg_aff      : out std_logic;    -- segnale di enable registro affidabilità
		o_en_reg_val      : out std_logic;    -- segnale di enable registro lettura memoria
		o_en_counter   	  : out std_logic;	  -- contatore
		o_en_ram	      : out std_logic; 	  -- segnale di enable ram

		o_rw_ram	      : out std_logic; 	  -- segnale di lettura/scrittura ram
		
		fsm_rst           : out std_logic     -- reset della macchina
	);
end fsm;

architecture fsm_arch of fsm is
	type state_type is (IDLE, CONTA, LEGGI_MEM, CHECK, SCRIVI_VAL, SCRIVI_AFF, DONE);
	signal CURRENT_STATE, NEXT_STATE: state_type;
begin
	process(CURRENT_STATE, i_start, i_end, i_zero)
	begin
		case CURRENT_STATE is
            when IDLE =>
                -- segnali di enable off
                o_en_counter <= '0';
                o_mux_addr <= '0';
                o_mux_write <= '0';
                o_mux_aff <= '0';
                o_en_reg_aff <= '0';
                o_en_reg_val <= '0';
                o_en_ram <= '0';
                o_rw_ram <= '0';
                o_done <= '0';
                fsm_rst <= '0';
                
                if i_start = '1' then
                    NEXT_STATE <= CONTA;    -- inizia
                else
                    NEXT_STATE <= IDLE;
                end if;		
			   
            when CONTA => 
                -- controlla esito confronto tra il contatore e K
                -- e scegli se proseguire
                o_mux_addr <= '0';
                o_mux_write <= '0';
                o_mux_aff <= '0';
                o_en_reg_aff <= '0';
                o_en_reg_val <= '0';
                o_en_ram <= '0';
                o_rw_ram <= '0';
                o_done <= '0';
                fsm_rst <= '0';
                o_en_counter <= '0';
                -- ho già finito, non fare nulla
                if i_end = '1' then
                    
                    NEXT_STATE <= DONE;
                else
                    -- incrementa contatore
                    --o_en_counter <= '1';
                    NEXT_STATE <= LEGGI_MEM;
                end if;
			     
            when LEGGI_MEM =>
                -- leggi VAL dalla memoria
			    o_en_counter <= '0';    -- ferma contatore
                o_mux_addr <= '0';      -- seleziona primo indirizzo
                o_mux_write <= '0';      
                o_mux_aff <= '0';
                o_en_reg_aff <= '0';
                o_en_reg_val <= '0';
                o_en_ram <= '1';        -- abilita la memoria
                o_rw_ram <= '0';        -- lettura
                o_done <= '0';
                fsm_rst <= '0';
                
                NEXT_STATE <= CHECK;

            when CHECK =>
                -- controlla se il valore letto è zero
                o_en_counter <= '0';
                o_mux_addr <= '0';
                o_mux_write <= '0';
                o_en_reg_aff <= '1';    -- calcola nuova affidabilità
                o_en_ram <= '0';        -- memoria disabilitata
                o_rw_ram <= '0';
                o_done <= '0';
                fsm_rst <= '0';
                
                -- il valore letto è 0, scrivilo in memoria prima di continuare
                if i_zero = '1' then
                    o_en_reg_val <= '0';                    
                    o_mux_aff <= '1';           -- aff <= aff - 1
                    NEXT_STATE <= SCRIVI_VAL;
                else
                    o_en_reg_val <= '1';        -- salva il nuovo valore
                    o_mux_aff <= '0';           -- aff <= 31
                    NEXT_STATE <= SCRIVI_AFF;
                end if;
 
            when SCRIVI_VAL =>
                -- scrivi il vecchio valore al posto dello zero
                o_en_counter <= '0';
                o_mux_addr <= '0';      -- indirizzo di val
                o_mux_write <= '0';     -- scrivi val
                o_mux_aff <= '0';
                o_en_reg_aff <= '0';
                o_en_reg_val <= '0';
                o_en_ram <= '1';        -- attiva memoria
                o_rw_ram <= '1';        -- scrittura
                o_done <= '0';
                fsm_rst <= '0';
                
                NEXT_STATE <= SCRIVI_AFF;
			   
            when SCRIVI_AFF =>
                -- scrivi affidabilità del valore
                o_en_counter <= '1';
                o_mux_addr <= '1';      -- indirizzo aff
                o_mux_write <= '1';     -- scrivi aff
                o_mux_aff <= '0';
                o_en_reg_aff <= '0';    -- disabilita registro
                o_en_reg_val <= '0';
                o_en_ram <= '1';
                o_rw_ram <= '1';
                o_done <= '0';
			    fsm_rst <= '0';
			    
			    NEXT_STATE <= CONTA;
			     
            when DONE =>
                -- segnale di uscita a 1 in attesa di start = 0
                o_en_counter <= '0';
                o_mux_addr <= '0';
                o_mux_write <= '0';
                o_mux_aff <= '0';
                o_en_reg_aff <= '0';
                o_en_reg_val <= '0';
                o_en_ram <= '0';
                o_rw_ram <= '0';
                o_done <= '1';
                
                if i_start = '0' then
                    fsm_rst <= '1';         -- reset di contatore e registri
                    NEXT_STATE <= IDLE;
                else
                    fsm_rst <= '0';
                    NEXT_STATE <= DONE;
                end if;
                 			     
		end case;
	end process;
	
	
	fsm_process : process (i_clk, i_rst)
	begin
		if (i_rst = '1') then					-- reset asincrono
			CURRENT_STATE <= IDLE;
		elsif (i_clk = '1' and i_clk'event) then			-- passa allo stato successivo ogni clock
			CURRENT_STATE <= NEXT_STATE;
		end if;
	end process;
end architecture;

--------------------------------------------------------------------------

---------------
-- Blocco OR --
---------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity or_gate is
port(
    i_a     : in std_logic;
    i_b     : in std_logic;
    
    o_or    : out std_logic
);
end or_gate;

architecture or_gate_arch of or_gate is
begin
    o_or <= i_a or i_b;
end architecture;





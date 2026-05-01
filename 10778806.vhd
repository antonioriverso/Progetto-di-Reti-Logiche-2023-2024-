
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


-- REGISTRO C
entity c_reg is
    port(
            decrement: in std_logic;
            clk : in std_logic;
            rst: in std_logic;
            def: in std_logic;
            output: out std_logic_vector(7 downto 0)
        );
end c_reg;

architecture Behavioral of c_reg is
    signal count: unsigned(7 downto 0);
begin
    process(clk, rst, def, decrement)
    begin
        if rst = '1' then
            count <= (others => '0');
        end if;
       if rising_edge(clk) then
            if def = '1' then
                count <= "00011111";
            elsif decrement = '1' then
                if count /= "00000000" then
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;

    output <= std_logic_vector(count);
end Behavioral;

--- Registro DATA
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity data_reg is
    port(
        input: in std_logic_vector(7 downto 0);
        clk : in std_logic;
        rst: in std_logic;
        enable: in std_logic;
        output: out std_logic_vector(7 downto 0)
    );
end data_reg;

architecture data_reg_arch of data_reg is

begin
    process(clk, rst, enable)
    begin
        if rst = '1' then
            output <= ( others=> '0');
        end if;
        if rising_edge(clk) then
            if enable = '1' then
                output <=  input;
            end if;
        end if;
   end process;
end data_reg_arch;

--- Registro K
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity k_reg is
    port(
            input: in std_logic_vector(9 downto 0);
            enable: in std_logic;
            decrement: in std_logic;

            clk : in std_logic;
            rst: in std_logic;

            output: out std_logic_vector(9 downto 0)
        );
end k_reg;

architecture Behavioral of k_reg is
signal temp1 : unsigned(9 downto 0);
begin
    process(clk, rst, enable, decrement)
    begin
        if rst = '1' then
            temp1 <= (others => '0');
            
        end if;
        if rising_edge(clk) then
            if enable = '1' then
                temp1 <= unsigned(input);
            elsif decrement = '1' and temp1 > 0 then
                temp1 <= temp1 - 1;
            end if;
            
        end if;
    end process;

output <= std_logic_vector(temp1);


end Behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

--- Registro ADD
entity addr_reg is
    port(
            input: in std_logic_vector(15 downto 0);
            enable: in std_logic;
            increment: in std_logic;
            rst: in std_logic;
            clk : in std_logic;

            output: out std_logic_vector(15 downto 0)
        );
end addr_reg;

architecture Behavioral of addr_reg is
signal temp : unsigned(15 downto 0);

begin
    process(clk, rst, increment, enable)
    begin
        if rst = '1' then
            temp <= "0000000000000000";
        end if;
        if rising_edge(clk) then
            if enable = '1' then
                temp <= unsigned(input);
            elsif increment = '1' then
                temp <= temp + 1;
            end if;
        end if;
    end process;

output <= std_logic_vector(temp);


end Behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

--- MULTIPLEXER
entity mux is
    generic(
        L : integer := 7 
    );
    port(
            in1: in std_logic_vector(L downto 0);
            in0: in std_logic_vector(L downto 0);
            sel: in std_logic;

            output: out std_logic_vector(L downto 0)
        );
end mux;

architecture Behavioral of mux is

begin
    output <= in1 when sel = '1' else
              in0    when sel = '0';


end Behavioral;



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;



entity project_reti_logiche is
    port(
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_add : in std_logic_vector(15 downto 0);
        i_k : in std_logic_vector(9 downto 0);

        o_done : out std_logic;

        o_mem_addr : out std_logic_vector(15 downto 0 );
        i_mem_data : in std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we : out std_logic;
        o_mem_en : out std_logic
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is



type state_type is (S0, S1, S2,  S3, S4, S5);
signal current_state, next_state: state_type;

signal data_enable: std_logic;

signal k_enable, k_decrement: std_logic;
signal k_output: std_logic_vector(9 downto 0);
signal k_empty: std_logic;

signal c_decrement, c_def: std_logic;

signal addr_increment, addr_enable: std_logic;

signal data_in: std_logic;
signal c_connect, data_connect: std_logic_vector(7 downto 0);

signal data_reset, c_reset, k_reset, addr_reset: std_logic;
begin

U1: entity work.data_reg
port map(
    input => i_mem_data,
    clk => i_clk,
    rst => data_reset,
    enable => data_enable,
    output => data_connect
);

U2: entity work.k_reg
port map(
    input => i_k,
    clk => i_clk,
    rst => k_reset,
    enable => k_enable,
    decrement => k_decrement,
    output => k_output
    --empty => k_empty
);


U3: entity work.c_reg
port map(
    clk => i_clk,
    rst => c_reset,
    def => c_def,
    decrement => c_decrement,
    output => c_connect
);

U4: entity work.addr_reg
port map(
    input => i_add,
    clk => i_clk,
    rst => addr_reset,
    enable => addr_enable,
    increment => addr_increment,
    output => o_mem_addr
);

U5: entity work.mux
generic map(
 L => 7
)
port map(
    in1 => data_connect,
    in0 => c_connect,
    sel => data_in,
    output => o_mem_data

);



update_state: process(i_clk,i_rst)
    begin
        if(i_rst='1') then
            current_state <= S0;
        elsif(rising_edge(i_clk)) then
            current_state <= next_state;
        end if;
end process;

fsm: process(current_state, i_start, i_k, i_mem_data)
        begin
            --azzerati tutti i segnali in uscita        
            o_done <= '0';
            o_mem_we <= '0';
            o_mem_en <= '0';
           --azzerati tutti i segnali interni   
            c_decrement <= '0';
            c_def <= '0';
            c_reset<= '0';
            k_enable <= '0';
            k_decrement <= '0';
            k_reset<= '0';
            data_in <= '0';
            data_reset<= '0'; 
            data_enable <= '0';  
            addr_reset <= '0';
            addr_enable <= '0';
            addr_increment <= '0';
            

            case current_state is
               when S0 =>
                --impostati i valori di default nei registri
                   data_reset<= '1'; c_reset<= '1'; k_reset<= '1'; addr_reset <= '1';
                    if i_start = '1' then
                        o_mem_en <= '1';
                        --si scrive l'addr nel registro
                        addr_enable <= '1';
                        --si scrive k nel registro
                        k_enable <= '1';
                        if i_k = "0000000000" then
                           next_state <= S5;
                        else
                           next_state <= S1;
                        end if;
                    else
                        next_state <= S0;
                    end if;
   
                --stato necessario per consentire correttamente la lettura da memoria del prossimo elemento
                when S1 =>
                    o_mem_en <= '1';
                    next_state <= S2;
                when S2 =>
                --si legge dalla memoria
                    o_mem_en <= '1';  
                --se il dato dalla memoria non è nullo
                    if i_mem_data /= "00000000" then
                     --il dato viene salvato nel registro
                        data_enable <= '1';
                        c_def <= '1';
                --altrimenti
                    else                       
                     --nel registro rimane il vecchio dato
                        data_enable <= '0';
                     --viene decrementato c 
                        c_decrement <= '1';
                    end if;
                    next_state <= S3;
               when S3 =>
               --si scrive il dato in memoria dal registro
                    data_in <= '1';
                    o_mem_en <= '1';
                    o_mem_we <= '1';
               --viene decrementato k
                    k_decrement <= '1';
               --viene incrementato addr
                    addr_increment <= '1';
                    next_state <= S4;
                                 
               when S4 =>
                    addr_increment <= '1';
               --si scrive il valore di credibilita (c) in memoria
                    data_in <= '0';
                    o_mem_en <= '1';
                    o_mem_we <= '1';
               --si controlla se siamo arrivati alla fine della sequenza
               if k_output = "0000000000" then
                    next_state <= S5; 
               else
                    next_state <= S1;
               end if;

               when S5 =>
                    o_done <= '1';
                    if i_start = '1' then
                        next_state <= S5;
                    else
                        next_state <= S0;
                    end if;

            end case;
  end process;

end Behavioral;
--============================================================================
-- alu_tb.vhd - self-checking testbench for the VHDL ALU
--
-- Mirrors the directed cases in tb/alu_tb.v so that the two implementations
-- are held to the same contract. If the Verilog and the VHDL ever disagree,
-- one of these two testbenches fails and says which case.
--
-- Run:
--   ghdl -a --std=08 --workdir=sim/ghdl vhdl/alu.vhd vhdl/alu_tb.vhd
--   ghdl -r --std=08 --workdir=sim/ghdl alu_tb
--============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu_tb is
end entity alu_tb;

architecture sim of alu_tb is

    constant WIDTH : positive := 8;

    signal a, b      : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal opcode    : std_logic_vector(3 downto 0)       := (others => '0');
    signal result    : std_logic_vector(WIDTH-1 downto 0);
    signal zero      : std_logic;
    signal negative  : std_logic;
    signal carry     : std_logic;
    signal overflow  : std_logic;

    signal errors : natural := 0;
    signal checks : natural := 0;

    constant OP_ADD : std_logic_vector(3 downto 0) := "0000";
    constant OP_SUB : std_logic_vector(3 downto 0) := "0001";
    constant OP_AND : std_logic_vector(3 downto 0) := "0010";
    constant OP_OR  : std_logic_vector(3 downto 0) := "0011";
    constant OP_XOR : std_logic_vector(3 downto 0) := "0100";
    constant OP_NOT : std_logic_vector(3 downto 0) := "0101";
    constant OP_SLL : std_logic_vector(3 downto 0) := "0110";
    constant OP_SRL : std_logic_vector(3 downto 0) := "0111";
    constant OP_SLT : std_logic_vector(3 downto 0) := "1000";

begin

    dut : entity work.alu
        generic map (WIDTH => WIDTH)
        port map (
            a => a, b => b, opcode => opcode,
            result => result, zero => zero, negative => negative,
            carry => carry, overflow => overflow
        );

    stimulus : process
        -- One directed check. The procedure drives the inputs, waits for the
        -- combinational logic to settle, and compares every output.
        procedure check (
            constant ta, tb   : in integer;
            constant top      : in std_logic_vector(3 downto 0);
            constant exp_res  : in integer;
            constant exp_c    : in std_logic;
            constant exp_v    : in std_logic;
            constant exp_z    : in std_logic;
            constant exp_n    : in std_logic;
            constant note     : in string
        ) is
        begin
            a      <= std_logic_vector(to_unsigned(ta, WIDTH));
            b      <= std_logic_vector(to_unsigned(tb, WIDTH));
            opcode <= top;
            wait for 1 ns;

            checks <= checks + 1;

            if to_integer(unsigned(result)) /= exp_res
               or carry    /= exp_c
               or overflow /= exp_v
               or zero     /= exp_z
               or negative /= exp_n then
                errors <= errors + 1;
                report "FAIL  " & note
                     & " : got result=" & integer'image(to_integer(unsigned(result)))
                     & " c=" & std_logic'image(carry)
                     & " v=" & std_logic'image(overflow)
                     & " z=" & std_logic'image(zero)
                     & " n=" & std_logic'image(negative)
                     & " | expected result=" & integer'image(exp_res)
                    severity warning;
            end if;
            wait for 1 ns;
        end procedure;
    begin
        report "=== VHDL ALU testbench, WIDTH=8 ===";

        -- Addition
        check(10,  15,  OP_ADD, 25,  '0','0','0','0', "ADD 10+15");
        check(0,   0,   OP_ADD, 0,   '0','0','1','0', "ADD zero flag");
        check(200, 100, OP_ADD, 44,  '1','0','0','0', "ADD unsigned carry-out");
        check(100, 50,  OP_ADD, 150, '0','1','0','1', "ADD signed overflow without carry");
        check(255, 1,   OP_ADD, 0,   '1','0','1','0', "ADD -1+1 carry with zero result");

        -- Subtraction
        check(20, 5,   OP_SUB, 15,  '1','0','0','0', "SUB no borrow");
        check(5,  20,  OP_SUB, 241, '0','0','0','1', "SUB borrow, negative");
        check(7,  7,   OP_SUB, 0,   '1','0','1','0', "SUB equal operands");
        check(128, 1,  OP_SUB, 127, '1','1','0','0', "SUB signed overflow at -128");

        -- Logic
        check(202, 172, OP_AND, 136, '0','0','0','1', "AND");
        check(192, 3,   OP_OR,  195, '0','0','0','1', "OR");
        check(240, 255, OP_XOR, 15,  '0','0','0','0', "XOR");
        check(170, 0,   OP_NOT, 85,  '0','0','0','0', "NOT");
        check(255, 255, OP_XOR, 0,   '0','0','1','0', "XOR equal sets zero");

        -- Shifts
        check(17,  0, OP_SLL, 34, '0','0','0','0', "SLL no bit lost");
        check(129, 0, OP_SLL, 2,  '1','0','0','0', "SLL MSB into carry");
        check(130, 0, OP_SRL, 65, '0','0','0','0', "SRL no bit lost");
        check(3,   0, OP_SRL, 1,  '1','0','0','0', "SRL LSB into carry");

        -- Signed set-on-less-than
        check(5,   10,  OP_SLT, 1, '0','0','0','0', "SLT 5 < 10");
        check(10,  5,   OP_SLT, 0, '0','0','1','0', "SLT 10 not < 5");
        check(251, 5,   OP_SLT, 1, '0','0','0','0', "SLT -5 < 5");
        check(5,   251, OP_SLT, 0, '0','0','1','0', "SLT 5 not < -5");
        check(128, 127, OP_SLT, 1, '0','0','0','0', "SLT -128 < 127 with overflow");

        -- Unknown opcode
        check(170, 85, "1111", 0, '0','0','1','0', "unknown opcode is defined");

        wait for 1 ns;
        report "---------------------------------------------";
        if errors = 0 then
            report "PASS  " & integer'image(checks) & " checks, 0 failures";
        else
            report "FAIL  " & integer'image(errors) & " failures" severity failure;
        end if;
        report "---------------------------------------------";

        wait;
    end process;

end architecture sim;

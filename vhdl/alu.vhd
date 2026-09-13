--============================================================================
-- alu.vhd - the same ALU expressed in VHDL
--
-- Functionally identical to rtl/alu.v. Kept alongside it deliberately: the two
-- languages force different habits, and reading one design in both makes the
-- language-specific parts obvious.
--
-- Differences worth noticing against the Verilog version:
--   * numeric_std gives explicit signed/unsigned types, so the intent of each
--     arithmetic operation is written down instead of inferred from context.
--   * std_logic_vector carries no numeric meaning, so conversions are explicit.
--     VHDL will not silently reinterpret a vector as a number.
--   * process(all) declares a complete sensitivity list by construction. A
--     hand-written list that misses a signal simulates differently from the
--     hardware it synthesises to, and that class of bug disappears here.
--============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
    generic (
        WIDTH : positive := 8
    );
    port (
        a        : in  std_logic_vector(WIDTH-1 downto 0);
        b        : in  std_logic_vector(WIDTH-1 downto 0);
        opcode   : in  std_logic_vector(3 downto 0);
        result   : out std_logic_vector(WIDTH-1 downto 0);
        zero     : out std_logic;
        negative : out std_logic;
        carry    : out std_logic;
        overflow : out std_logic
    );
end entity alu;

architecture rtl of alu is

    constant OP_ADD : std_logic_vector(3 downto 0) := "0000";
    constant OP_SUB : std_logic_vector(3 downto 0) := "0001";
    constant OP_AND : std_logic_vector(3 downto 0) := "0010";
    constant OP_OR  : std_logic_vector(3 downto 0) := "0011";
    constant OP_XOR : std_logic_vector(3 downto 0) := "0100";
    constant OP_NOT : std_logic_vector(3 downto 0) := "0101";
    constant OP_SLL : std_logic_vector(3 downto 0) := "0110";
    constant OP_SRL : std_logic_vector(3 downto 0) := "0111";
    constant OP_SLT : std_logic_vector(3 downto 0) := "1000";

    -- One extra bit so the carry-out falls out of the addition naturally,
    -- exactly as in the Verilog version.
    signal is_sub   : boolean;
    signal add_b    : unsigned(WIDTH downto 0);
    signal carry_in : unsigned(WIDTH downto 0);
    signal sum      : unsigned(WIDTH downto 0);

    signal sign_a, sign_b, sign_sum   : std_logic;
    signal add_overflow, sub_overflow : boolean;

    -- std_logic mirrors of the overflow conditions, plus the set-less-than
    -- bit. A conditional expression is not legal inside an aggregate, so the
    -- value is computed here and simply referenced in the case below.
    signal sub_ovf_sl : std_logic;
    signal slt_bit    : std_logic;

    -- Internal copy: VHDL-93 forbids reading an out port, and the status flags
    -- are derived from the result.
    signal result_i : std_logic_vector(WIDTH-1 downto 0);

begin

    is_sub <= (opcode = OP_SUB) or (opcode = OP_SLT);

    -- Subtraction is a + (not b) + 1, so one adder serves both operations.
    add_b    <= '0' & unsigned(not b) when is_sub else '0' & unsigned(b);
    carry_in <= to_unsigned(1, WIDTH+1) when is_sub else to_unsigned(0, WIDTH+1);
    sum      <= ('0' & unsigned(a)) + add_b + carry_in;

    sign_a   <= a(WIDTH-1);
    sign_b   <= b(WIDTH-1);
    sign_sum <= sum(WIDTH-1);

    -- Signed overflow: the operand signs must allow it and the result sign
    -- must contradict them. The carry-out is the unsigned indicator and says
    -- nothing about the signed range.
    add_overflow <= (sign_a = sign_b)  and (sign_sum /= sign_a);
    sub_overflow <= (sign_a /= sign_b) and (sign_sum /= sign_a);

    sub_ovf_sl <= '1' when sub_overflow else '0';

    -- The signed difference is negative exactly when a < b, except that a
    -- signed overflow inverts the sign bit, so the two are XORed to recover
    -- the true comparison.
    slt_bit <= sign_sum xor sub_ovf_sl;

    --------------------------------------------------------------------------
    -- Result and arithmetic flags.
    --
    -- Defaults are assigned before the case so every signal is driven on every
    -- path. An unassigned signal in one branch is how a latch appears in a
    -- process that was meant to be purely combinational.
    --------------------------------------------------------------------------
    process(all)
    begin
        result_i <= (others => '0');
        carry    <= '0';
        overflow <= '0';

        case opcode is
            when OP_ADD =>
                result_i <= std_logic_vector(sum(WIDTH-1 downto 0));
                carry    <= sum(WIDTH);
                overflow <= '1' when add_overflow else '0';

            when OP_SUB =>
                result_i <= std_logic_vector(sum(WIDTH-1 downto 0));
                -- For subtraction the carry-out means "no borrow", i.e.
                -- a >= b read as unsigned.
                carry    <= sum(WIDTH);
                overflow <= '1' when sub_overflow else '0';

            when OP_AND => result_i <= a and b;
            when OP_OR  => result_i <= a or  b;
            when OP_XOR => result_i <= a xor b;
            when OP_NOT => result_i <= not a;

            when OP_SLL =>
                result_i <= a(WIDTH-2 downto 0) & '0';
                carry    <= a(WIDTH-1);         -- bit shifted out of the top

            when OP_SRL =>
                result_i <= '0' & a(WIDTH-1 downto 1);
                carry    <= a(0);               -- bit shifted out of the bottom

            when OP_SLT =>
                result_i <= (0 => slt_bit, others => '0');

            when others =>
                result_i <= (others => '0');
        end case;
    end process;

    result   <= result_i;
    zero     <= '1' when result_i = (result_i'range => '0') else '0';
    negative <= result_i(WIDTH-1);

end architecture rtl;

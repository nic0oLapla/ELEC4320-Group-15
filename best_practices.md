# 📘 Project Best Practices

## 1. Project Purpose
A hardware calculator implemented in Verilog for FPGA (Basys3) with a pipelined arithmetic unit (ALU) and peripherals. It receives PS/2 keyboard input, parses to operands/operations, executes arithmetic via single-cycle and multi-cycle engines (multiply, divide, factorial, log, CORDIC-based trig), and sends results over UART.

## 2. Project Structure
- calculator.srcs/
  - sources_1/
    - ip/clk_300_mhz/: Vivado clocking wizard IP for 300 MHz fabric clock and constraint files
    - new/: RTL modules and headers
      - define.v: global macro definitions (opcodes, widths, latencies)
      - ALU.v: operation dispatch; coordinates single-cycle and pipelined engines with valid/ready
      - multiplier_pipelined.v: fully pipelined N×N multiplier
      - division_pipelined.v: iterative fixed-point divider with in_valid/in_ready/out_valid
      - factorial_pipelined.v: iterative factorial built on multiplier
      - cordic_tan.v, cordic_arctan.v: CORDIC-based trig engines
      - log_base_fixed.v, exp_natural_fixed.v: fixed-point math
      - accumulator.v: parses key stream into RPN-like stack and issues ALU transactions
      - keys_2_calc.v, ps2_receiver.v, debouncer.v: keyboard front-end
      - num_2_ascii.v, uart_sender.v: number formatting and UART output
      - top.v: top-level integration and wiring
  - sim_1/
    - new/
      - controller_tb.v: system-level testbench driving PS/2 scan codes
  - constrs_1/imports/constraints/Basys3_Master.xdc: board constraints
- calculator.xpr: Vivado project file
- README.md: project overview
- .gitignore

Conventions
- One primary clock domain: clk_300 from clock wizard
- Fixed-point format: signed `WIDTH` with `FRAC` fractional bits (define.v)
- Opcode macros in define.v drive consistent ALU dispatch

## 3. Test Strategy
- Framework: HDL simulation via Verilog testbenches
- Location: calculator.srcs/sim_1/new/*.v
- Current testbench: controller_tb.v integrates clock, PS/2 stimulus, ALU/accumulator pipeline, and UART path
- Practices
  - Write self-contained testbenches with local clock generation and stimulus processes
  - Favor transaction-level stimuli (e.g., feeding PS/2 scan codes sequences) for integration tests
  - Add module-level unit benches for new math engines (exercise valid/ready, edge cases, latency)
  - Use $display for key milestones and end the sim deterministically ($finish)
  - Keep reset scenarios covered (assert/deassert and verify idle/valid behavior)
  - Model backpressure where applicable (e.g., UART ready)

When to write tests
- Unit tests: for math engine modules and protocol correctness (valid/ready, latency, truncation)
- Integration tests: end-to-end paths through accumulator → ALU → formatting/uart
- Regression: add tests for fixed bug cases and boundary values (zero, max/min, divide-by-zero)

## 4. Code Style
- Language: Verilog-2001
- Headers: include `define.v` for shared parameters and opcodes
- Resets: synchronous reset ports named `reset`; always handle reset paths first in sequential blocks
- Handshake naming
  - Inputs: in_valid, in_ready
  - Outputs: out_valid
  - ALU interface: valid_in/valid_out/idle plus data signals
- Signal naming: lower_snake_case for wires/regs, Capitalized module names
- Constants/macros: SCREAMING_SNAKE_CASE in define.v
- Combinational vs sequential
  - sequential: always @(posedge clk) with non-blocking (<=)
  - avoid unintended latches; initialize defaults each cycle where needed
- Default_nettype
  - Prefer `default_nettype none` at file top and re-enable with `default_nettype wire` at end to catch typos (already used in several files)
- Comments
  - Document protocols (latency, handshake timing)
  - Avoid restating obvious code; keep TODOs actionable
- Fixed-point handling
  - Truncation/rounding must be explicit; document width assumptions and truncation sites

## 5. Common Patterns
- Valid/Ready micro-protocol for pipelined engines (mult/div/fact/log/cordic)
- Active operation state machine inside ALU (`active_op` with OPSTATE_* localparams)
- Iterative engines that pulse out_valid when complete and ignore new requests while busy
- Pipelined adder-tree multiplier using registered stages
- Accumulator operating as a small stack machine to prepare unary/binary ops for ALU

## 6. Do's and Don'ts
✅ Do
- Use define.v macros for opcodes and widths; parameterize modules with N/Q
- Assert/deassert reset in simulation; drive defined values on reset
- Keep handshakes clean: drive out_valid for exactly one cycle per result, and guard in_valid with in_ready
- Constrain and synchronize all logic to clk_300; avoid accidental multi-clock domains
- Provide clear latency notes and pipeline stages in comments for new engines
- Add module-level testbenches with deterministic finish conditions

❌ Don’t
- Don’t start multi-cycle operations without verifying the target engine’s in_ready
- Don’t mix blocking and non-blocking assignments in the same sequential always block
- Don’t leave width assumptions undocumented when truncating products/quotients
- Don’t gate clocks; use enables/handshakes instead
- Don’t introduce implicit nets (keep `default_nettype none` whenever possible)

## 7. Tools & Dependencies
- Vivado (Xilinx) for synthesis/implementation and IP integration (Clocking Wizard)
- Basys3 board constraints (Basys3_Master.xdc)
- Simulation: Vivado simulator or other Verilog simulators (e.g., xsim, ModelSim)

Setup
- Open calculator.xpr in Vivado
- Ensure clk_300_mhz IP is generated/available
- Use provided XDC for pin/clock constraints
- Run simulation from calculator.srcs/sim_1/new/controller_tb.v or module-specific benches

## 8. Other Notes
- The ALU uses a mix of single-cycle ops (ADD/SUB, placeholders) and multi-cycle engines; new ops must integrate with active_op state and handshakes
- Factorial is iterative with internal use of multiplier; large inputs can overflow—document bounds and behavior
- Divider handles divide-by-zero via out_overflow; callers should define policy for results
- Maintain consistent truncation to N bits for multi-engine outputs (e.g., mult_p[N-1:0])
- For new modules, expose in_ready/out_valid and synchronous reset; document latency and any fixed-point nuances

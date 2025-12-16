# Project Best Practices

## 1. Project Purpose
A hardware calculator implemented in Verilog for FPGA (Basys3 by default) with a pipelined arithmetic unit (ALU) and peripherals. It receives PS/2 keyboard input, parses operands/operations, executes arithmetic via single-cycle and multi-cycle engines (multiply, divide, factorial, log, CORDIC-based trig), and sends results over UART.

## 2. Project Structure
- calculator.srcs/
  - sources_1/
    - ip/clk_300_mhz/: Vivado clocking wizard IP for 300 MHz fabric clock and constraint files
    - new/: RTL modules and headers
      - define.v: global macro definitions (opcodes, widths, latencies)
      - ALU.v: operation dispatch; coordinates single-cycle and pipelined engines with valid/ready
      - multiplier_pipelined.v: fully pipelined multiplier
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

## 3. Conventions
- Clocking: single primary clock domain from clk_300 (clock wizard IP).
- Fixed-point format: two's-complement Q22.10 (32 bits total, 10 fractional bits). Keep ALU inputs/outputs at 32 bits; set `WIDTH=32`, `FRAC=10` in define.v; document any truncation/rounding sites.
- Opcode macros in define.v drive consistent ALU dispatch and shared parameters.

## 4. Test Strategy
- Framework: HDL simulation via Verilog testbenches.
- Location: calculator.srcs/sim_1/new/*.v (current: controller_tb.v with PS/2 stimulus, ALU/accumulator pipeline, UART path).
- Practices:
  - Self-contained benches with local clock/reset and stimulus processes.
  - Transaction-level stimuli (e.g., PS/2 scan-code sequences) for integration tests.
  - Module-level benches for new math engines (valid/ready, edge cases, latency).
  - Use $display for milestones; end simulations deterministically with $finish.
  - Cover reset assertions/deassertions and verify idle/valid behavior.
  - Model backpressure when applicable (e.g., UART ready).
- When to write tests:
  - Unit: math engines and protocol correctness (valid/ready, latency, truncation).
  - Integration: end-to-end paths through accumulator → ALU → formatting/UART.
  - Regression: boundary values (zero, max/min, divide-by-zero) and fixed bug cases.

## 5. Code Style
- Verilog-2001; include `define.v` for shared parameters/opcodes.
- Resets: synchronous `reset` ports; handle reset paths first in sequential blocks.
- Handshake naming: inputs in_valid/in_ready; outputs out_valid; ALU interface valid_in/valid_out/idle plus data signals.
- Signal naming: lower_snake_case for wires/regs; Capitalized module names.
- Constants/macros: SCREAMING_SNAKE_CASE in define.v.
- Combinational vs sequential: use always @(posedge clk) with non-blocking (<=) for sequential; avoid unintended latches by initializing defaults each cycle.
- Default_nettype: prefer `default_nettype none` at file top and re-enable with `default_nettype wire` at end to catch typos.
- Comments: document protocols (latency, handshake timing) and fixed-point width/rounding assumptions; keep TODOs actionable.

## 6. Common Patterns
- Valid/Ready micro-protocol for pipelined engines (mult/div/fact/log/cordic).
- Active operation state machine inside ALU (`active_op` with OPSTATE_* localparams).
- Iterative engines pulse out_valid when complete and ignore new requests while busy.
- Pipelined adder-tree multiplier using registered stages.
- Accumulator as a small stack machine preparing unary/binary ops for the ALU.

## 7. Do's and Don'ts
Do
- Use define.v macros for opcodes and widths; parameterize modules with N/Q.
- Assert/deassert reset in simulation; drive defined values on reset.
- Keep handshakes clean: drive out_valid for exactly one cycle per result and guard in_valid with in_ready.
- Constrain and synchronize all logic to clk_300; avoid accidental multi-clock domains.
- Provide clear latency notes and pipeline stages in comments for new engines.
- Add module-level testbenches with deterministic finish conditions.

Don't
- Don't start multi-cycle operations without verifying the target engine's in_ready.
- Don't mix blocking and non-blocking assignments in the same sequential always block.
- Don't leave width assumptions undocumented when truncating products/quotients.
- Don't gate clocks; use enables/handshakes instead.
- Don't introduce implicit nets (keep `default_nettype none` whenever possible).

## 8. Tools & Dependencies
- Vivado 2020.2 for synthesis/implementation and IP integration (Clocking Wizard).
- Basys3 board constraints (Basys3_Master.xdc); if targeting PYNQ-Z2, include its XDC and update pin mapping.
- Simulation: Vivado simulator or other Verilog simulators (e.g., xsim, ModelSim).

Setup
- Open calculator.xpr in Vivado.
- Ensure clk_300_mhz IP is generated/available.
- Use the relevant XDC for pin/clock constraints.
- Run simulation from calculator.srcs/sim_1/new/controller_tb.v or module-specific benches.

## 9. Assignment Compliance & Packaging
- Deliverables to bundle in the submission zip: Verilog sources also copied to .txt files (per rubric), full Vivado project folder, generated .bit file, and any host-PC code used in the flow.
- Platform choice: Basys3 by default; if using PYNQ-Z2, justify added complexity and document any Python-side support. Keep constraint files (XDC) aligned to the chosen board.
- Functional requirements to demonstrate: meaningful sequential logic (FSM control), on-chip memory use (RAM/ROM), register read/write paths, and human-machine I/O (inputs such as switches/buttons/UART/keyboard; outputs such as 7-seg/VGA/UART). Show these in simulation and on-board demo.
- Keep ALU/top-level I/O aligned to the expected peripherals and call out which I/Os are exercised in the demo.

## 10. Documentation, Sourcing, and Reporting
- Report outline should include: introduction/background; development environment and I/O; module functionalities; block/schematic diagram of top/core modules with I/O meaning; FSM/flowchart for top/core control; debugging description (I/O, test data, fixes); simulation waveforms for core modules; task distribution table (task, name, %); references with proper citation format (papers, blogs, datasheets, existing projects).
- Sourcing best practices: keep a reference log for any borrowed ideas/code; cite sources in the report; mark reused modules/snippets in comments; clearly separate original work vs borrowed contributions.
- Testing evidence: archive key waveforms/screenshots for the report; note expected vs observed behavior and fixes applied.
- Collaboration: record contribution ratios and ensure every member participates in the presentation/demo.

## 11. Milestones & Quality Targets
- Deadlines: proposal (Canvas group) by Oct 31; written report by Dec 15; demo/presentation Dec 16–17 (all members must present).
- Scoring factors: completeness by deadline; design complexity/technical difficulty; I/O utilization/interaction; optimization (performance/resource/power, if applicable); written report quality; presentation quality.

## 12. Other Notes
- The ALU mixes single-cycle ops (ADD/SUB, placeholders) and multi-cycle engines; new ops must integrate with the active_op state and handshakes.
- Factorial is iterative with internal multiplier use; large inputs can overflow—document bounds and behavior.
- Divider handles divide-by-zero via out_overflow; callers should define policy for results.
- Maintain consistent truncation to N bits for multi-engine outputs (e.g., mult_p[N-1:0]).
- For new modules, expose in_ready/out_valid and synchronous reset; document latency and any fixed-point nuances.

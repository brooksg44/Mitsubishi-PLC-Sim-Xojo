# Mitsubishi PLC Simulator — Xojo 2026

A desktop PLC simulator for **Xojo 2026 Release 1.2** that implements the Mitsubishi MELSEC IL (Instruction List) instruction set with a real-time Ladder Diagram (LD) display.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-blue)
![Xojo](https://img.shields.io/badge/Xojo-2026%20R1.2-orange)

---

## Features

- **Full MELSEC IL instruction set** — LD/LDI/LDP/LDF, AND/ANI/ANDP/ANDF, OR/ORI/ORP/ORF, ORB, MPS/MRD/MPP, OUT/OUTP, SET/RST, MOV, ADD, SUB, MUL, DIV, CMP, INC, DEC, SHL, SHR, ROL, ROR, FOR/NEXT, CJ/JMP/CALL/RET, END, FEND, NOP, comparison contacts (LD=, LD<>, LD<, LD>, LD<=, LD>=)
- **Ladder Diagram renderer** — live graphical LD view with power-flow highlighting, scrollable via ▲/▼ toolbar buttons
- **IL editor** — editable IL source with Load button to parse and reload
- **Run / Stop / Step / Reset** controls with configurable scan timer
- **Input toggles** — X0–X15 push-button toggles for simulating field inputs
- **Register monitor** — read-only scrollable text panel showing all X, Y, M, T, C, D register values, updated every scan
- **Set Register input** — type `D0=100`, `X0=1`, `M5=0`, etc. and click **Set** to write any register mid-simulation

## Register types

| Register | Range | Description |
|----------|-------|-------------|
| X0–X15   | Bit   | Digital inputs |
| Y0–Y15   | Bit   | Digital outputs |
| M0–M127  | Bit   | Internal relays |
| T0–T7    | Word  | Timer current values |
| C0–C7    | Word  | Counter current values |
| D0–D127  | Word  | Data registers (16-bit) |

## Sample programs

The simulator loads Program 1 on startup and includes 9 built-in sample programs in the **Load Sample** menu:

| # | Title | Key Instructions Demonstrated |
|---|---|---|
| 1 | Basic I/O (Timer/Counter/Latch) | `OUT T0`, `OUT C0`, `SET`/`RST M0`, `ADD`, `LD>` |
| 2 | Arithmetic (ADD/SUB/MUL/DIV/CMP) | `MOV`, `ADD`, `SUB`, `MUL`, `DIV`, `INC`, `DEC`, comparison contacts |
| 3 | Stack (MPS/MRD/MPP) | `MPS`, `MRD`, `MPP` with multiple output branches |
| 4 | Bit & Word Ops (BSET/SHL/WAND) | `BSET`, `BCLR`, `BTEST`, `WAND`, `WOR`, `SHL`, `SHR`, `ROL`, `ROR` |
| 5 | Subroutines & Jumps (CALL/CJ/JMP) | `CALL P1`, `RET`, `CJ P2`, `JMP P3`, `FEND`, labels |
| 6 | Timer & Counter Patterns | On-delay timer, oscillator (`ANI T1` -> `OUT T1`), counter with reset, `LDF` falling edge |
| 7 | 3-Wire Motor Control | START/STOP seal-in circuit with overload interlock |
| 8 | Block OR (ORB) | `ORB` for two series branches in parallel |
| 9 | Block AND (ANB) | `ANB` for two parallel groups in series |

Program 1:

```
// === Program 1: Basic I/O (Timer, Counter, Latch) ===
// X0: start T0 timer (1s), T0 -> Y0
// X1: pulse C0 counter (target 5), C0 -> Y1
// X2: reset counter C0
// X3: SET M0 latch, X4: RST M0 latch, M0 -> Y2
// X5: when on, add D0+D1 -> D2 (use Set Reg to set D0/D1)
// Comparison contact: D2>K100 -> Y3

LD X0
OUT T0 K10

LD T0
OUT Y0

LD X1
OUT C0 K5

LD C0
OUT Y1

LD X2
RST C0

LD X3
SET M0

LD X4
RST M0

LD M0
OUT Y2

LD X5
ADD D0 D1 D2

LD> D2 K100
OUT Y3

END
```

## Getting started

### Open the text project

1. Open `MitsubishiPLCSim/MitsubishiPLCSim.xojo_project` in **Xojo 2026 R1.2**
2. Click **Run** in the Xojo IDE (or press ⌘R)

The text project is the source of truth for day-to-day development. Its classes are stored as readable `.xojo_code` and `.xojo_window` files so changes can be reviewed and versioned normally.

### Legacy binary generator

The original binary project can still be regenerated from the Python generator:

```bash
python3 gen_plcsim.py
```

This writes a fresh `MitsubishiPLCSim.xojo_binary_project` in the repository root.

Requires Python 3.6+ (no third-party packages).

## Usage

| Control | Action |
|---------|--------|
| **Load** | Parse the IL editor text and reload the simulator |
| **Run** | Start continuous scan (100 ms cycle) |
| **Stop** | Halt scanning |
| **Step** | Execute one scan cycle manually |
| **Reset** | Clear all registers and reload the program |
| **▲ / ▼** | Scroll the Ladder Diagram view |
| **X0–X15** | Toggle digital input bits |
| **Set Reg** | Write a value — type `D0=100` then click **Set** |

## Engine tests

The text project includes a lightweight `PLCEngineTests` class for smoke-testing the simulator core. To run it from the Xojo debugger or Immediate pane:

```xojo
Dim tests As New PLCEngineTests
MessageBox(tests.RunAll)
```

The suite covers basic output writes, timer done contacts, counter rising-edge behavior, arithmetic/comparison instructions, `ORB` branch logic, and `CALL`/`FEND` subroutine flow.

## Architecture

| File | Description |
|------|-------------|
| `MitsubishiPLCSim/MitsubishiPLCSim.xojo_project` | Primary Xojo text project |
| `MitsubishiPLCSim/*.xojo_code` | Readable Xojo class source files |
| `MitsubishiPLCSim/MainWindow.xojo_window` | Main window layout and event/method code |
| `gen_plcsim.py` | Legacy Python generator for the binary project |
| `MitsubishiPLCSim.xojo_binary_project` | Generated legacy Xojo binary project |

### Classes

- **PLCEngine** — instruction parser, register storage, scan executor
- **PLCInstruction** — single parsed IL instruction (OpCode, Operand1, Operand2)
- **PLCCanvas** — `DesktopCanvas` subclass that renders the Ladder Diagram
- **MainWindow** — top-level window with toolbar, IL editor, LD view, and register monitor
- **SamplePrograms** — built-in sample IL program names and source text
- **PLCEngineTests** — lightweight smoke tests for the simulator core

## Requirements

- [Xojo 2026 Release 1.2](https://www.xojo.com) (Desktop licence or trial)
- macOS, Windows, or Linux
- Python 3.6+ (only needed to regenerate the project)

## License

MIT

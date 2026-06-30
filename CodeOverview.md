# MitsubishiPLCSim — Code Overview

## Table of Contents

1. [Project Summary](#project-summary)
2. [Architecture](#architecture)
3. [Class Diagram](#class-diagram)
4. [Detailed Class Descriptions](#detailed-class-descriptions)
   - [App](#app)
   - [PLCInstruction](#plcinstruction)
   - [PLCEngine](#plcengine)
   - [PLCCanvas](#plccanvas)
   - [MainWindow](#mainwindow)
5. [Data Flow](#data-flow)
6. [Instruction Set Reference](#instruction-set-reference)
7. [Memory Map](#memory-map)
8. [Sample Programs](#sample-programs)
9. [Key Design Decisions](#key-design-decisions)

---

## Project Summary

**MitsubishiPLCSim** is a desktop application that simulates a Mitsubishi MELSEC programmable logic controller (PLC). It accepts Instruction List (IL) code written in Mitsubishi MELSEC mnemonic format, parses it, executes scan cycles, and renders the program as a live ladder diagram. Users can toggle inputs, step through execution, and monitor all internal registers in real time.

**Language / Framework:** Xojo (DesktopApplication target)
**Date:** June 28, 2026

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         App                                  │
│                    (DesktopApplication)                      │
│                         │                                     │
│                    creates ▼                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   MainWindow                         │   │
│  │  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │   │
│  │  │ Toolbar  │  │PLCCanvas │  │   ILEditor        │  │   │
│  │  │ Buttons  │  │(Ladder   │  │ (DesktopTextArea) │  │   │
│  │  │ X0–X15   │  │ Diagram) │  │                   │  │   │
│  │  └────┬─────┘  └────┬─────┘  └───────┬───────────┘  │   │
│  │       │              │                 │              │   │
│  │       │         ┌────▼─────┐    LoadProgram()       │   │
│  │       └────────▶│ PLCEngine│◀──────────────────────  │   │
│  │                 │          │                          │   │
│  │                 │ ◆Instructions()                    │   │
│  │                 │ ◆XBits, YBits, MBits               │   │
│  │                 │ ◆DRegs, TCurrent, CCurrent         │   │
│  │                 └────┬─────┘                          │   │
│  │                      │ contains                       │   │
│  │                 ┌────▼──────────┐                     │   │
│  │                 │PLCInstruction │ (× N)               │   │
│  │                 │ OpCode        │                     │   │
│  │                 │ Operand1..3   │                     │   │
│  │                 └───────────────┘                     │   │
│  │  ┌─────────────────────────────┐                     │   │
│  │  │ RegList (Register Monitor) │                     │   │
│  │  └─────────────────────────────┘                     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Class Diagram

```
DesktopApplication
       │
       ▼
       App
       │
       ▼
DesktopWindow
       │
       ▼
   MainWindow ──────────────── uses ──────── PLCEngine
       │                                           │
       │ contains                                   │ contains 0..*
       │                                           │
       ▼                                           ▼
   PLCCanvas ◀─────────────── reads ──────── PLCInstruction
   (DesktopCanvas)
```

---

## Detailed Class Descriptions

### App

| Aspect | Detail |
|---|---|
| **Inherits** | `DesktopApplication` |
| **Purpose** | Application entry point |
| **Behavior** | On `Opening`, instantiates `MainWindow` and calls `Show` |
| **Complexity** | Minimal — single-event class acting as bootstrap |

---

### PLCInstruction

| Aspect | Detail |
|---|---|
| **Inherits** | `Object` |
| **Purpose** | Represents one parsed line of IL source code |
| **Constructor** | `Constructor(line As String)` — tokenizes a single line by spaces |

#### Parsing Logic (Constructor)

1. Splits the trimmed line on spaces into `parts()`.
2. Assigns `OpCode = parts(0)`, `Operand1 = parts(1)`, `Operand2 = parts(2)`, `Operand3 = parts(3)` (all uppercased).
3. **Label detection:** If `OpCode` ends with `":"`, the token is re-interpreted as a label — `IsLabel = True`, `LabelName` is extracted (everything before the colon), and `OpCode` is set to `"LABEL"`.
4. Comparison load opcodes like `LD=`, `LD<>`, `LD<`, `LD>` are kept intact as the full `OpCode` string.

#### Properties

| Property | Type | Description |
|---|---|---|
| `OpCode` | `String` | The instruction mnemonic (e.g. `"LD"`, `"OUT"`, `"ADD"`) |
| `Operand1` | `String` | First operand (e.g. `"X0"`, `"D0"`) |
| `Operand2` | `String` | Second operand (e.g. `"K10"`, `"D1"`) |
| `Operand3` | `String` | Third operand (e.g. `"D2"` for `ADD D0 D1 D2`) |
| `IsLabel` | `Boolean` | `True` if this line is a label like `1:` or `P2:` |
| `LabelName` | `String` | The label identifier without the colon |
| `LineNumber` | `Integer` | Source line number (set by `PLCEngine.LoadProgram`) |

#### Methods

| Method | Returns | Description |
|---|---|---|
| `GetRegType()` | `String` | First character of `Operand1` — e.g. `"X"`, `"Y"`, `"M"`, `"D"`, `"T"`, `"C"` |
| `RegIndex()` | `Integer` | Numeric index extracted from `Operand1`. **Important:** For `X` and `Y` registers the suffix is interpreted as **octal** (`Val("&O" + suffix)`), matching Mitsubishi convention. All other registers use decimal. |
| `KValue(operand)` | `Integer` | Resolves a numeric constant: `K` prefix → decimal, `H` prefix → hex, otherwise raw integer |

---

### PLCEngine

| Aspect | Detail |
|---|---|
| **Inherits** | `Object` |
| **Purpose** | Core simulation engine — holds all PLC memory, parses programs, and executes scan cycles |
| **Key Pattern** | Input → BeginScan → Execute all instructions → EndScan → Output update |

#### Memory Arrays

| Array | Size | Type | Purpose |
|---|---|---|---|
| `XBits()` | 2048 | `Boolean` | Input bits (physical inputs) |
| `YBits()` | 2048 | `Boolean` | Output bits (physical outputs, updated at end of scan) |
| `YShadow()` | 2048 | `Boolean` | Output shadow — written during scan, copied to `YBits` in `EndScan` |
| `MBits()` | 8192 | `Boolean` | Internal auxiliary relays |
| `TCoil()` | 512 | `Boolean` | Timer coil energization state |
| `TContact()` | 512 | `Boolean` | Timer done bit (True when `TCurrent >= TPreset`) |
| `TPreset()` | 512 | `Integer` | Timer preset value (in scan ticks) |
| `TCurrent()` | 512 | `Integer` | Timer elapsed value |
| `CCoil()` | 256 | `Boolean` | Counter coil state |
| `CContact()` | 256 | `Boolean` | Counter done bit (True when `CCurrent >= CPreset`) |
| `CCurrent()` | 256 | `Integer` | Counter accumulated value |
| `CPreset()` | 256 | `Integer` | Counter target value |
| `CPrevCoil()` | 256 | `Boolean` | Previous-scan counter coil (for rising-edge detection) |
| `DRegs()` | 8192 | `Integer` | Data registers (16-bit word storage) |
| `ZReg()` | 8 | `Integer` | Index registers Z0–Z7 |
| `XPrev()`, `YPrev()`, `MPrev()` | 2048/2048/8192 | `Boolean` | Previous-scan state for edge detection (`LDP`/`LDF`) |
| `MStack()` | 11 | `Boolean` | MPS/MRD/MPP stack |
| `MCStack()` | 8 | `Boolean` | Master Control (MC/MCR) nest stack |
| `SubStack()` | 32 | `Integer` | CALL/RET subroutine return-address stack |

#### State Properties

| Property | Type | Description |
|---|---|---|
| `Instructions()` | `PLCInstruction()` | Parsed instruction array |
| `LabelMap` | `Dictionary` | Maps label name (`String`) → instruction index (`Integer`) |
| `ScanCount` | `Integer` | Number of completed scan cycles |
| `IsRunning` | `Boolean` | Run/Stop flag (set by UI) |
| `HasEnded` | `Boolean` | Set `True` when `END` instruction is executed |
| `StkPtr` | `Integer` | Current stack pointer for MPS/MRD/MPP |
| `MCPtr` | `Integer` | Current MC nesting level |
| `SubPtr` | `Integer` | Current subroutine call depth |

#### Method: `Initialize()`

Clears and re-dims every memory array to its maximum size. Resets all pointers and flags to zero/False. Creates a fresh `LabelMap` dictionary.

#### Method: `LoadProgram(ilText As String)`

1. Splits input text by `EndOfLine`.
2. Iterates each line, skipping blanks and comments (`//` or `;`).
3. Strips inline `//` comments.
4. Constructs a `PLCInstruction` for each valid line.
5. If the instruction is a label, records `LabelName → next index` in `LabelMap`.
6. Appends to `Instructions` array.
7. Resets `StkPtr`, `MCPtr`, `SubPtr`, `HasEnded`.

#### Method: `ExecuteScan()`

The core execution loop. Simulates one complete PLC scan cycle:

```
BeginScan()
  └─ Clear YShadow, reset StkPtr, MCPtr
For each instruction (PC = 0 … max):
  └─ Switch on OpCode
       ├─ LD/LDI/LDP/LDF    → Load accumulator
       ├─ AND/ANI/ANDP/ANDF → AND with accumulator
       ├─ OR/ORI/ORP/ORF    → OR with accumulator
       ├─ ANB/ORB           → Block AND/OR with stack
       ├─ MPS/MRD/MPP       → Stack push/peek/pop
       ├─ OUT/SET/RST       → Write outputs/coils
       ├─ MOV/ADD/SUB/...   → Application instructions (only if acc=True)
       ├─ LD=/AND=/OR=...   → Comparison contacts
       ├─ CJ/JMP/CALL/RET   → Program flow control
       ├─ MC/MCR            → Master Control nesting
       ├─ FEND/END/NOP/LABEL → Terminal/skip
       └─ (50+ opcodes total)
EndScan()
  └─ Copy YShadow → YBits
  └─ Update timers (increment TCurrent if coil on)
  └─ Update counters (increment CCurrent on rising coil edge)
  └─ Save XPrev/YPrev/MPrev for next-scan edge detection
  └─ Increment ScanCount
```

**Key detail — gated execution:** The `gated` variable tracks Master Control (MC) state. Output-type instructions (`OUT`, `SET`, `RST`) only execute when `gated = True`.

**Key detail — power-flow gating for application instructions:** Instructions like `MOV`, `ADD`, `SUB`, etc. only execute when the accumulator (`acc`) is `True`. This mirrors real PLC behavior where function blocks only fire when power flows to them.

#### Method: `BeginScan()` / `EndScan()`

- **BeginScan:** Zeros the output shadow (`YShadow`), resets stack and MC pointers.
- **EndScan:** Copies shadow to physical outputs, advances timers (assumes 100ms per scan tick), advances counters on rising coil edge, snapshots all bit states for edge detection on the next scan, increments `ScanCount`.

#### Method: `GetBit(rt, idx)` / `SetBit(rt, idx, v)`

Unified bit access. `GetBit` dispatches on register type prefix:
- `"X"` → `XBits`
- `"Y"` → `YBits`
- `"M"` → `MBits`
- `"T"` → `TContact` (the done bit, not the coil)
- `"C"` → `CContact` (the done bit)
- `"SM"` → Special relays (SM400=always ON, SM401=always OFF, SM402=first scan)

`SetBit` writes back with special handling for timers and counters (reset clears current value and done bit).

#### Method: `GetWord(rt, idx)` / `SetWord(rt, idx, v)`

Unified word access:
- `"D"` → `DRegs`
- `"T"` → `TCurrent`
- `"C"` → `CCurrent`
- `"Z"` → `ZReg`

#### Method: `ResolveWord(op As String)` → `Integer`

Resolves an operand to an integer value:
| Prefix | Meaning | Example |
|---|---|---|
| `K` | Decimal constant | `K100` → 100 |
| `H` | Hexadecimal constant | `H1F` → 31 |
| `D` | Data register | `D0` → `DRegs(0)` |
| `T` | Timer current value | `T0` → `TCurrent(0)` |
| `C` | Counter current value | `C0` → `CCurrent(0)` |
| `Z` | Index register | `Z0` → `ZReg(0)` |
| `R` | Alias for D register | `R10` → `DRegs(10)` |

#### Method: `GetRise(rt, idx)` / `GetFall(rt, idx)`

Edge detection functions comparing current bit state against previous-scan snapshot (`XPrev`/`YPrev`/`MPrev`):
- **Rise:** `cur AND NOT prev`
- **Fall:** `NOT cur AND prev`

#### Method: `GetRegisterDump()` → `String`

Generates a compact human-readable text dump of all registers (X0–X15, Y0–Y15, M0–M15, T0–T7 with PV/CV/DN, C0–C7 with PV/CV/DN, D0–D15). Displayed in the `RegList` text area.

---

### PLCCanvas

| Aspect | Detail |
|---|---|
| **Inherits** | `DesktopCanvas` |
| **Purpose** | Custom-drawn ladder diagram renderer |
| **Properties** | `Engine As PLCEngine`, `ScrollY As Integer` |

#### Rendering Approach

The `Paint` event is entirely procedural — no offscreen buffer or retained scene graph. Each paint call:

1. **Clears** to white.
2. **Early exit** if no program is loaded.
3. **Draws power rails** — two vertical blue bars (4px wide) on left and right edges.
4. **Iterates instructions** to identify rungs:
   - A rung starts at an `LD*` instruction.
   - A rung ends at the first `OUT`/`SET`/`RST`/`END`/`FEND`/`NOP`/`LABEL`/`RET` encountered, or when the next instruction is another `LD*`. `MRD`/`MPP` keep the current rung open so stack branches render as one Mitsubishi-style branch group.
5. **For each rung,** draws a horizontal bus line and iterates through its instructions, dispatching to draw helpers.

#### Drawing Constants

| Constant | Value | Purpose |
|---|---|---|
| `RAIL_W` | 4 | Power rail width |
| `LEFT_X` | 80 | Left margin for first element |
| `RUNG_H` | 70 | Vertical height per rung |
| `ELEM_W` | 70 | Width of contact/coil elements |
| `ELEM_H` | 28 | Height of contact/coil elements |
| `COIL_X` | `g.Width - 170` | X position for output coils |

#### Element Rendering

| Method | Draws |
|---|---|
| `DrawContactElement(g, x, y, w, h, lbl, active, nc, isRise, isFall)` | Normally-open or normally-closed contact. Active contacts glow blue with a filled rectangle. `P`/`N` markers for edge detection. |
| `DrawCoilElement(g, x, y, w, h, lbl, active, isReset)` | Circular coil symbol. Active coils glow orange. Reset coils have a diagonal cross line. |
| `DrawFBElement(g, x, y, w, h, op, o1, o2, o3)` | Rectangular function block (for `MOV`, `ADD`, `CALL`, etc.) with operation name and operands. |

#### Branch Handling

- `OR`/`ORI`/`ORP`/`ORF` instructions draw a **parallel branch below** the main rung bus.
- `ORB` closes the branch by drawing three connecting lines (left vertical, right vertical, bottom horizontal).
- The `branchOpen` flag tracks whether a branch is currently being drawn.
- When a branch exists, extra vertical space (60px) is added below the rung.

#### MPS/MRD/MPP Visualization

The ladder renderer hides stack instructions and draws the equivalent Mitsubishi-style branch structure. `MPS/MRD/MPP` output stacks branch from the saved logic point, `MPS ... ORB` draws block-OR branches, and `MPS ... ANB` acts as a block separator for series-connected logic groups.

#### Scrolling

`ScrollY` offsets the Y origin so the `ScrollUp`/`ScrollDown` buttons (in `MainWindow`) can pan the diagram in 140px increments.

---

### MainWindow

| Aspect | Detail |
|---|---|
| **Inherits** | `DesktopWindow` |
| **Size** | 1400 × 820 pixels |
| **Title** | "Mitsubishi MELSEC PLC Simulator" |
| **Purpose** | Main application window — assembles all UI controls and wires event handlers |

#### UI Layout (Top to Bottom)

```
┌──────────────────────────────────────────────────────────────────┐
│ TOOLBAR (50px)                                                    │
│ [Load IL] [▶ RUN] [■ STOP] [» STEP] [↺ RESET]  STOP  Scan: 0   │
│   [▲][▼]  Inputs: [X0][X1]...[X7] / [X8][X9]...[X15]             │
├──────────────────────────┬───────────────────────────────────────┤
│ PLCCanvas                │ Sample: [▼ PopupMenu     ] [Load]    │
│ (Ladder Diagram)         │ ILEdit (DesktopTextArea)              │
│ 900 × 550                │ 498 × 510                            │
│                          │                                       │
│                          │                                       │
├──────────────────────────┴───────────────────────────────────────┤
│ Set Reg (e.g. D0=100, X0=1): [ bordered input ] [Set]           │
├──────────────────────────────────────────────────────────────────┤
│ RegList (DesktopTextArea, ReadOnly) — 1400 × 420                 │
│ X: X0=0 X1=0 ...                                                 │
│ D: D0=0 D1=0 ...                                                 │
└──────────────────────────────────────────────────────────────────┘
```

#### Toolbar Controls

| Control | Event Handler | Action |
|---|---|---|
| `Load IL` button | `LoadBtn_Pressed` | Calls `LoadCurrentProgram` — parses `ILEdit.Text` into engine |
| `▶ RUN` button | `RunBtn_Pressed` | Sets `Engine.IsRunning = True`, starts `ScanTimer` (100ms, Mode=2 = multiple) |
| `■ STOP` button | `StopBtn_Pressed` | Sets `Engine.IsRunning = False`, stops `ScanTimer` |
| `» STEP` button | `StepBtn_Pressed` | Executes exactly one scan cycle |
| `↺ RESET` button | `ResetBtn_Pressed` | Re-initializes engine, re-loads program, resets scan counter |
| `StatusLbl` | — | Displays "RUN", "STOP", or "RESET" |
| `ScanLbl` | — | Displays "Scan: N" |
| `▲` / `▼` buttons | `ScrollUp_Pressed` / `ScrollDown_Pressed` | Adjusts `LDView.ScrollY` by ±140px |
| `X0`–`X15` toggle buttons | `XInput_Pressed` | Toggles `Engine.XBits(n)` (XOR flip) and refreshes the LD/register views |

#### Sample Menu

A `DesktopPopupMenu` with 9 pre-built example programs. The `Load Sample` button (`LoadSample_Pressed`) re-initializes the engine, loads the selected sample text into `ILEdit`, and parses it.

#### IL Editor (`ILEdit`)

A `DesktopTextArea` where users type or edit Mitsubishi IL code. Pre-populated with Sample Program 1 on startup.

#### Register Set Field

A text field accepting input in the format `REG=VALUE` (e.g. `D0=100`, `X0=1`). `ApplySetReg` parses this and calls `Engine.SetWord` or `Engine.SetBit` accordingly. Bound to both the `Set` button's `Pressed` event and the text field's `Action` event (Enter key).

#### Register Monitor (`RegList`)

A read-only `DesktopTextArea` at the bottom showing `Engine.GetRegisterDump`. Updated after every scan or manual action.

#### Scan Timer

A `Timer` with 100ms period and `Mode = 2` (multiple fire). Its `Action` event calls `Engine.ExecuteScan`, refreshes the ladder canvas, updates the register dump, and updates the scan counter label.

#### Properties Reference

| Property | Type | UI Role |
|---|---|---|
| `Engine` | `PLCEngine` | The simulation core |
| `LDView` | `PLCCanvas` | Ladder diagram display |
| `ILEdit` | `DesktopTextArea` | IL code editor |
| `RegList` | `DesktopTextArea` | Register state display |
| `SampleMenu` | `DesktopPopupMenu` | Sample program selector |
| `ScanLbl` | `DesktopLabel` | Scan counter display |
| `StatusLbl` | `DesktopLabel` | Run/Stop status display |
| `ScanTimer` | `Timer` | 100ms periodic scan trigger |
| `SetRegField` | `DesktopTextField` | Manual register set input |

---

## Data Flow

```
User types IL code in ILEdit
         │
         ▼
  [Load IL] / [Load Sample]
         │
         ▼
  PLCEngine.LoadProgram(ileEdit.Text)
         │  ┌─ Splits lines
         │  ├─ Skips comments/blanks
         │  ├─ Creates PLCInstruction per line
         │  └─ Builds LabelMap
         ▼
  Instructions() array populated
         │
         ▼
  [▶ RUN] → ScanTimer fires every 100ms
         │
         ▼
  PLCEngine.ExecuteScan()
         │  ├─ BeginScan() → clear YShadow
         │  ├─ Loop: evaluate each instruction
         │  │    ├─ Read XBits, MBits, TContact, CContact
         │  │    ├─ Write YShadow, MBits, TCoil, CCoil, DRegs
         │  │    └─ Handle jumps/calls via LabelMap
         │  └─ EndScan()
         │       ├─ YShadow → YBits
         │       ├─ Advance timers/counters
         │       └─ Save edge-detection snapshots
         ▼
  LDView.Refresh() → PLCCanvas.Paint()
         │  └─ Reads Engine state to color contacts/coils
         ▼
  UpdateRegisters() → RegList.Text = Engine.GetRegisterDump()
```

---

## Instruction Set Reference

### Basic Bit Load/Logic

| Op | Action | Accumulator Result |
|---|---|---|
| `LD a` | Load Normally Open | `GetBit(a)` |
| `LDI a` | Load Normally Closed | `NOT GetBit(a)` |
| `LDP a` | Load Rising Edge | `GetRise(a)` |
| `LDF a` | Load Falling Edge | `GetFall(a)` |
| `AND a` | AND Normally Open | `acc AND GetBit(a)` |
| `ANI a` | AND Normally Closed | `acc AND NOT GetBit(a)` |
| `ANDP a` | AND Rising Edge | `acc AND GetRise(a)` |
| `ANDF a` | AND Falling Edge | `acc AND GetFall(a)` |
| `OR a` | OR Normally Open | `acc OR GetBit(a)` |
| `ORI a` | OR Normally Closed | `acc OR NOT GetBit(a)` |
| `ORP a` | OR Rising Edge | `acc OR GetRise(a)` |
| `ORF a` | OR Falling Edge | `acc OR GetFall(a)` |

### Block Logic

| Op | Action |
|---|---|
| `ANB` | `acc = stack.Pop AND acc` |
| `ORB` | `acc = stack.Pop OR acc` |

### Stack Operations

| Op | Action |
|---|---|
| `MPS` | `stack.Push(acc)` |
| `MRD` | `acc = stack.Peek` (no pop) |
| `MPP` | `acc = stack.Pop` |

### Output Instructions

| Op | Action | Gate Required |
|---|---|---|
| `OUT a [K]` | Write accumulator to coil (timer/counter use K as preset) | Yes (MC) |
| `OUTP a` | Pulse output — write acc directly each scan | Yes (MC) |
| `SET a` | Latch ON (only when acc=True) | Yes (MC + acc) |
| `RST a` | Reset OFF (clears timer/counter values) | Yes (MC + acc) |

### Comparison Contacts

| Op | Accumulator Result |
|---|---|
| `LD= a b` / `AND= a b` / `OR= a b` | `ResolveWord(a) = ResolveWord(b)` |
| `LD<> a b` / `AND<> a b` / `OR<> a b` | `ResolveWord(a) <> ResolveWord(b)` |
| `LD< a b` / `AND< a b` / `OR< a b` | `ResolveWord(a) < ResolveWord(b)` |
| `LD> a b` / `AND> a b` / `OR> a b` | `ResolveWord(a) > ResolveWord(b)` |
| `LD<= a b` / `AND<= a b` / `OR<= a b` | `ResolveWord(a) <= ResolveWord(b)` |
| `LD>= a b` / `AND>= a b` / `OR>= a b` | `ResolveWord(a) >= ResolveWord(b)` |

### Data Transfer

| Op | Action (only if acc=True) |
|---|---|
| `MOV src dst` | `SetWord(dst, ResolveWord(src))` |
| `MOVP src dst` | Same as MOV |

### Arithmetic

| Op | Action (only if acc=True) |
|---|---|
| `ADD a b dst` | `dst = a + b` |
| `SUB a b dst` | `dst = a - b` |
| `MUL a b dst` | `dst = a * b` |
| `DIV a b dst` | `dst = a \ b` (integer division, guards against ÷0) |
| `INC a` | `a = a + 1` |
| `DEC a` | `a = a - 1` |
| `ADDP`, `SUBP`, `MULP`, `DIVP`, `INCP`, `DECP` | Pulse variants (same logic in this impl) |

### Bit Operations

| Op | Action (only if acc=True) |
|---|---|
| `BSET word bit` | Set bit at position `bit` in word register |
| `BCLR word bit` | Clear bit at position `bit` in word register |
| `BTEST word bit M` | Test bit, store result in `M` auxiliary relay |

### Word Logical Operations

| Op | Action (only if acc=True) |
|---|---|
| `WAND a b dst` | `dst = a AND b` |
| `WOR a b dst` | `dst = a OR b` |
| `WXOR a b dst` | `dst = a XOR b` |
| `CML src dst` | `dst = NOT src` (bitwise complement) |

### Shift / Rotate

| Op | Action (only if acc=True) |
|---|---|
| `SHL word n` | Shift left by n bits |
| `SHR word n` | Shift right by n bits |
| `ROL word n` | Rotate left (16-bit, `n mod 16`) |
| `ROR word n` | Rotate right (16-bit, `n mod 16`) |

### Compare

| Op | Action |
|---|---|
| `CMP a b Mbase` | Sets `M(base)=a>b`, `M(base+1)=a=b`, `M(base+2)=a<b` |

### Program Flow

| Op | Action |
|---|---|
| `CJ Pn` | Conditional jump (if acc=True) to label `n` |
| `JMP Pn` | Unconditional jump to label `n` |
| `CALL Pn` | Conditional subroutine call (if acc=True), pushes return address |
| `RET` | Return from subroutine (pops return address) |
| `MC N M` | Master Control — nest and gate outputs by acc |
| `MCR N` | Master Control Reset — unnest |
| `FEND` | End of main program (exit scan loop) |
| `END` | End of entire program |
| `NOP` | No operation |
| `LABEL` | Internal marker (no runtime action) |

---

## Memory Map

| Register | Prefix | Bit/Word | Range | Octal Addr? | Description |
|---|---|---|---|---|---|
| Input | `X` | Bit | 0–2047 | **Yes** | Physical inputs (toggle buttons) |
| Output | `Y` | Bit | 0–2047 | **Yes** | Physical outputs (shadow-buffered) |
| Auxiliary | `M` | Bit | 0–8191 | No | Internal relays, latches, compare flags |
| Timer | `T` | Bit (coil/contact) + Word (PV/CV) | 0–511 | No | Coil, done contact, preset, current |
| Counter | `C` | Bit (coil/contact) + Word (PV/CV) | 0–255 | No | Coil, done contact, preset, current, prev-coil |
| Data | `D` | Word | 0–8191 | No | General-purpose 16-bit registers |
| Index | `Z` | Word | 0–7 | No | Index registers |
| Special | `SM` | Bit | 400–402 | No | SM400=always ON, SM401=always OFF, SM402=first scan |

**Octal addressing for X/Y:** Mitsubishi PLCs traditionally use octal numbering for I/O points (e.g., X10 = 8 decimal). The `PLCInstruction.RegIndex` method handles this via `Val("&O" + suffix)`.

---

## Sample Programs

| # | Title | Key Instructions Demonstrated |
|---|---|---|
| 1 | Basic I/O (Timer/Counter/Latch) | `OUT T0`, `OUT C0`, `SET`/`RST M0`, `ADD`, `LD>` |
| 2 | Arithmetic (ADD/SUB/MUL/DIV/CMP) | `MOV`, `ADD`, `SUB`, `MUL`, `DIV`, `INC`, `DEC`, comparison contacts |
| 3 | Stack (MPS/MRD/MPP) | `MPS`, `MRD`, `MPP` with multiple output branches |
| 4 | Bit & Word Ops (BSET/SHL/WAND) | `BSET`, `BCLR`, `BTEST`, `WAND`, `WOR`, `SHL`, `SHR`, `ROL`, `ROR` |
| 5 | Subroutines & Jumps (CALL/CJ/JMP) | `CALL P1`, `RET`, `CJ P2`, `JMP P3`, `FEND`, labels |
| 6 | Timer & Counter Patterns | On-delay timer, oscillator (`ANI T1 → OUT T1`), counter with reset, `LDF` falling edge |
| 7 | 3-Wire Motor Control | START/STOP seal-in circuit with overload interlock |
| 8 | Block OR (ORB) | `ORB` for two series branches in parallel |
| 9 | Block AND (ANB) | `ANB` for two parallel groups in series |

---

## Key Design Decisions

### 1. Output Shadow Buffer
Outputs are written to `YShadow` during the scan and copied to `YBits` only in `EndScan`. This prevents mid-scan output flickering and matches real PLC behavior where all outputs update simultaneously at the end of the scan.

### 2. Timer Model (Scan-Based, Not Real-Time)
Timers increment by 1 each scan tick. With a 100ms scan timer, `K10` = 1 second. This is a simplification — real Mitsubishi PLCs use hardware timers with millisecond precision. The code does **not** account for scan-time variation.

### 3. Counter Edge Detection
Counters increment only on the **rising edge** of the coil signal (detected via `CPrevCoil`). This matches standard PLC counter behavior where each pulse must transition OFF→ON to count. `RST Cn` clears the current value and done bit while preserving the current coil state for edge detection, so holding the count input ON during reset does not immediately add a count.

### 4. Power-Flow Gating for Application Instructions
Instructions like `MOV`, `ADD`, `SUB`, etc. check `If acc Then` before executing. This means they only fire when the logical chain leading to them evaluates to True, exactly like function blocks on a ladder rung.

### 5. Master Control (MC/MCR) Gating
The `gated` variable only affects output-type instructions (`OUT`, `SET`, `RST`). Comparison loads, arithmetic, and other non-output instructions execute regardless of MC state. This matches standard MELSEC behavior.

### 6. Octal Addressing for X/Y
`X` and `Y` register indices are parsed as octal. For example, `X10` resolves to index 8 (decimal). `M`, `D`, `T`, `C` use decimal. This is a critical detail for correct I/O mapping.

### 7. Label Resolution
Labels like `1:`, `P2:`, `3:` are detected during parsing and stored in `LabelMap` as `name → instruction index`. Jump/call instructions strip the `P` prefix if present. The label itself is stored as a `LABEL` instruction (no-op at runtime).

### 8. Single-Threaded Execution
All execution happens on the main thread via the `Timer.Action` event. There is no threading or async — the UI may block briefly during long program execution, but for typical IL programs this is negligible.

### 9. No Error Handling for Invalid Programs
The parser does not validate operand types or ranges at load time. Invalid instructions (e.g., `OUT X0` — writing to an input) are silently ignored or produce undefined behavior. The `GetBit`/`SetBit` methods do bounds-check their arrays, so out-of-range accesses return `False` or are no-ops.

### 10. Procedural Ladder Rendering
`PLCCanvas.Paint` re-parses the instruction array on every frame to determine rung boundaries and branch structure. There is no intermediate rung data structure. This keeps the code simple but means the rendering logic is tightly coupled to instruction ordering conventions (LD starts a rung, OUT ends one).

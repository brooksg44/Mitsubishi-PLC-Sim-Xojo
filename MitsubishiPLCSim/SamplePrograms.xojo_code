#tag Class
Protected Class SamplePrograms
	#tag Method, Flags = &h0
		Sub AddRows(menu As DesktopPopupMenu)
		  menu.AddRow "1: Basic I/O (Timer/Counter/Latch)"
		  menu.AddRow "2: Arithmetic (ADD/SUB/MUL/DIV/CMP)"
		  menu.AddRow "3: Stack (MPS/MRD/MPP)"
		  menu.AddRow "4: Bit & Word Ops (BSET/SHL/WAND)"
		  menu.AddRow "5: Subroutines & Jumps (CALL/CJ/JMP)"
		  menu.AddRow "6: Timer & Counter Patterns"
		  menu.AddRow "7: 3-Wire Motor Control"
		  menu.AddRow "8: Block OR (ORB)"
		  menu.AddRow "9: Block AND (ANB)"
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetSample(idx As Integer) As String
		  Select Case idx
		  Case 0
		      Return "// === Program 1: Basic I/O (Timer, Counter, Latch) ===" + EndOfLine + "// X0: start T0 timer (1s), T0 -> Y0" + EndOfLine + "// X1: pulse C0 counter (target 5), C0 -> Y1" + EndOfLine + "// X2: reset counter C0" + EndOfLine + "// X3: SET M0 latch, X4: RST M0 latch, M0 -> Y2" + EndOfLine + "// X5: when on, add D0+D1 -> D2 (use Set Reg to set D0/D1)" + EndOfLine + "// Comparison contact: D2>K100 -> Y3" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "OUT T0 K10" + EndOfLine + "" + EndOfLine + "LD T0" + EndOfLine + "OUT Y0" + EndOfLine + "" + EndOfLine + "LD X1" + EndOfLine + "OUT C0 K5" + EndOfLine + "" + EndOfLine + "LD C0" + EndOfLine + "OUT Y1" + EndOfLine + "" + EndOfLine + "LD X2" + EndOfLine + "RST C0" + EndOfLine + "" + EndOfLine + "LD X3" + EndOfLine + "SET M0" + EndOfLine + "" + EndOfLine + "LD X4" + EndOfLine + "RST M0" + EndOfLine + "" + EndOfLine + "LD M0" + EndOfLine + "OUT Y2" + EndOfLine + "" + EndOfLine + "LD X5" + EndOfLine + "ADD D0 D1 D2" + EndOfLine + "" + EndOfLine + "LD> D2 K100" + EndOfLine + "OUT Y3" + EndOfLine + "" + EndOfLine + "END"
		  Case 1
		      Return "// === Program 2: Arithmetic & Compare ===" + EndOfLine + "// X0: load D0=25, D1=10; compute D2..D5" + EndOfLine + "//   D2=D0+D1=35  D3=D0-D1=15  D4=D0*D1=250  D5=D0/D1=2" + EndOfLine + "// X1: INC D6 each scan" + EndOfLine + "// X2: DEC D7 each scan" + EndOfLine + "// CMP D0 D1 M0 -> M0=(D0>D1), M1=(D0=D1), M2=(D0<D1)" + EndOfLine + "// Y0/Y1/Y2 reflect compare result" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "MOV K25 D0" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "MOV K10 D1" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "ADD D0 D1 D2" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "SUB D0 D1 D3" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "MUL D0 D1 D4" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "DIV D0 D1 D5" + EndOfLine + "" + EndOfLine + "LD X1" + EndOfLine + "INC D6" + EndOfLine + "" + EndOfLine + "LD X2" + EndOfLine + "DEC D7" + EndOfLine + "" + EndOfLine + "LD> D0 D1" + EndOfLine + "OUT Y0" + EndOfLine + "" + EndOfLine + "LD= D0 D1" + EndOfLine + "OUT Y1" + EndOfLine + "" + EndOfLine + "LD< D0 D1" + EndOfLine + "OUT Y2" + EndOfLine + "" + EndOfLine + "END"
		  Case 2
		      Return "// === Program 3: Stack Operations (MPS/MRD/MPP) ===" + EndOfLine + "// X0 is master; X1->Y0, X2->Y1, X3->Y2, direct->Y3" + EndOfLine + "// MPS saves X0 state; MRD peeks for each branch; MPP pops last" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "MPS" + EndOfLine + "AND X1" + EndOfLine + "OUT Y0" + EndOfLine + "MRD" + EndOfLine + "AND X2" + EndOfLine + "OUT Y1" + EndOfLine + "MRD" + EndOfLine + "AND X3" + EndOfLine + "OUT Y2" + EndOfLine + "MPP" + EndOfLine + "OUT Y3" + EndOfLine + "" + EndOfLine + "// Rung 2: X4 master; X5 -> SET M1, NOT X5 -> RST M1" + EndOfLine + "LD X4" + EndOfLine + "MPS" + EndOfLine + "AND X5" + EndOfLine + "SET M1" + EndOfLine + "MPP" + EndOfLine + "ANI X5" + EndOfLine + "RST M1" + EndOfLine + "" + EndOfLine + "LD M1" + EndOfLine + "OUT Y4" + EndOfLine + "" + EndOfLine + "// Rung 3: three outputs share one condition (X0)" + EndOfLine + "LD X0" + EndOfLine + "MPS" + EndOfLine + "MOV K100 D0" + EndOfLine + "MRD" + EndOfLine + "MOV K200 D1" + EndOfLine + "MPP" + EndOfLine + "ADD D0 D1 D2" + EndOfLine + "" + EndOfLine + "END"
		  Case 3
		      Return "// === Program 4: Bit & Word Operations ===" + EndOfLine + "// Use Set Reg to set D0 first (e.g. D0=100)" + EndOfLine + "// X0: set bit 4 of D0" + EndOfLine + "// X1: clear bit 4 of D0" + EndOfLine + "// X2: test bit 4 of D0 -> M0 -> Y0" + EndOfLine + "// X3: D1 = D0 AND K255  (lower byte mask)" + EndOfLine + "// X4: D2 = D0 OR K256   (force bit 8 high)" + EndOfLine + "// X5: shifts and rotates on D3..D6" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "BSET D0 K4" + EndOfLine + "" + EndOfLine + "LD X1" + EndOfLine + "BCLR D0 K4" + EndOfLine + "" + EndOfLine + "LD X2" + EndOfLine + "BTEST D0 K4 M0" + EndOfLine + "" + EndOfLine + "LD M0" + EndOfLine + "OUT Y0" + EndOfLine + "" + EndOfLine + "LD X3" + EndOfLine + "WAND D0 K255 D1" + EndOfLine + "" + EndOfLine + "LD X4" + EndOfLine + "WOR D0 K256 D2" + EndOfLine + "" + EndOfLine + "LD X5" + EndOfLine + "SHL D3 K2" + EndOfLine + "" + EndOfLine + "LD X5" + EndOfLine + "SHR D4 K2" + EndOfLine + "" + EndOfLine + "LD X5" + EndOfLine + "ROL D5 K1" + EndOfLine + "" + EndOfLine + "LD X5" + EndOfLine + "ROR D6 K1" + EndOfLine + "" + EndOfLine + "END"
		  Case 4
		      Return "// === Program 5: Subroutines & Conditional Jumps ===" + EndOfLine + "// Set D0=10 D1=20 via Set Reg first" + EndOfLine + "// X0: CALL subroutine 1 -> D2=D0+D1=30, D3=D0*D1=200" + EndOfLine + "// X1: CJ P2 - when ON, skips MOV K999 D5" + EndOfLine + "// X2: JMP P3 - when ON, skips MOV K888 D6" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "CALL P1" + EndOfLine + "" + EndOfLine + "LD> D2 K0" + EndOfLine + "OUT Y0" + EndOfLine + "" + EndOfLine + "LD X1" + EndOfLine + "CJ P2" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "MOV K999 D5" + EndOfLine + "" + EndOfLine + "2:" + EndOfLine + "" + EndOfLine + "LD X2" + EndOfLine + "JMP P3" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "MOV K888 D6" + EndOfLine + "" + EndOfLine + "3:" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "OUT Y1" + EndOfLine + "" + EndOfLine + "FEND" + EndOfLine + "" + EndOfLine + "// Subroutine 1: D2 = D0+D1, D3 = D0*D1" + EndOfLine + "1:" + EndOfLine + "LD X0" + EndOfLine + "ADD D0 D1 D2" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "MUL D0 D1 D3" + EndOfLine + "" + EndOfLine + "RET" + EndOfLine + "" + EndOfLine + "END"
		  Case 5
		      Return "// === Program 6: Timer & Counter Patterns ===" + EndOfLine + "// X0: on-delay timer T0 (1 second=K10) -> Y0" + EndOfLine + "// X1: auto-repeat oscillator T1 (2s) -> Y1 pulses" + EndOfLine + "// X2: count presses -> C0 target 5 -> Y2" + EndOfLine + "// X3: reset C0" + EndOfLine + "// X4: falling edge of X4 sets M2 -> Y3; X5 clears it" + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "OUT T0 K10" + EndOfLine + "" + EndOfLine + "LD T0" + EndOfLine + "OUT Y0" + EndOfLine + "" + EndOfLine + "LD X1" + EndOfLine + "ANI T1" + EndOfLine + "OUT T1 K20" + EndOfLine + "" + EndOfLine + "LD T1" + EndOfLine + "OUT Y1" + EndOfLine + "" + EndOfLine + "LD X2" + EndOfLine + "OUT C0 K5" + EndOfLine + "" + EndOfLine + "LD X3" + EndOfLine + "RST C0" + EndOfLine + "" + EndOfLine + "LD C0" + EndOfLine + "OUT Y2" + EndOfLine + "" + EndOfLine + "LDF X4" + EndOfLine + "SET M2" + EndOfLine + "" + EndOfLine + "LD X5" + EndOfLine + "RST M2" + EndOfLine + "" + EndOfLine + "LD M2" + EndOfLine + "OUT Y3" + EndOfLine + "" + EndOfLine + "END"
		  Case 6
		      Return "// === Program 7: 3-Wire Motor Control ===" + EndOfLine + "// X0: STOP pushbutton (NC field contact; ON here means pressed/open)" + EndOfLine + "// X1: START pushbutton (NO)" + EndOfLine + "// X2: overload trip (ON means tripped)" + EndOfLine + "// Y0: motor starter coil" + EndOfLine + "// Y1: motor running pilot light" + EndOfLine + "// Logic: (START OR sealed-in Y0) AND NOT STOP AND NOT OVERLOAD" + EndOfLine + "" + EndOfLine + "LD X1" + EndOfLine + "OR Y0" + EndOfLine + "ANI X0" + EndOfLine + "ANI X2" + EndOfLine + "OUT Y0" + EndOfLine + "" + EndOfLine + "LD Y0" + EndOfLine + "OUT Y1" + EndOfLine + "" + EndOfLine + "END"
		  Case 7
		      Return "// === Program 8: ORB Block OR ===" + EndOfLine + "// Demonstrates ORB: two series branches in parallel" + EndOfLine + "// Y0 = (X0 AND X1) OR (X2 AND X3)" + EndOfLine + "// Turn on X0+X1 or X2+X3 to energize Y0." + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "AND X1" + EndOfLine + "MPS" + EndOfLine + "LD X2" + EndOfLine + "AND X3" + EndOfLine + "ORB" + EndOfLine + "OUT Y0" + EndOfLine + "" + EndOfLine + "END"
		  Case 8
		      Return "// === Program 9: ANB Block AND ===" + EndOfLine + "// Demonstrates ANB: two parallel groups in series" + EndOfLine + "// Y0 = (X0 OR X1) AND (X2 OR X3)" + EndOfLine + "// Turn on one input from each group to energize Y0." + EndOfLine + "" + EndOfLine + "LD X0" + EndOfLine + "OR X1" + EndOfLine + "MPS" + EndOfLine + "LD X2" + EndOfLine + "OR X3" + EndOfLine + "ANB" + EndOfLine + "OUT Y0" + EndOfLine + "" + EndOfLine + "END"
		  End Select
		  
		  Return ""
		End Function
	#tag EndMethod

	#tag ViewBehavior
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass

#tag Class
Protected Class PLCEngine
	#tag Method, Flags = &h0
		Sub BeginScan()
		  // Clear output shadow
		  Dim i As Integer
		  For i = 0 To 2047
		      YShadow(i) = False
		  Next
		  StkPtr = 0
		  MCPtr = 0
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub EndScan()
		  // Copy output shadow to physical outputs
		  Dim i As Integer
		  For i = 0 To 2047
		      YBits(i) = YShadow(i)
		  Next
		  // Update timers (100ms per scan assumed)
		  For i = 0 To 511
		      If TCoil(i) Then
		          If TCurrent(i) < TPreset(i) Then
		              TCurrent(i) = TCurrent(i) + 1
		          End If
		          If TCurrent(i) >= TPreset(i) And TPreset(i) > 0 Then
		              TContact(i) = True
		          End If
		      Else
		          TCurrent(i) = 0
		          TContact(i) = False
		      End If
		  Next
		  // Update counters (on rising edge of coil)
		  For i = 0 To 255
		      If CCoil(i) And Not CPrevCoil(i) Then
		          CCurrent(i) = CCurrent(i) + 1
		          If CCurrent(i) >= CPreset(i) And CPreset(i) > 0 Then
		              CContact(i) = True
		          End If
		      End If
		      CPrevCoil(i) = CCoil(i)
		  Next
		  ScanCount = ScanCount + 1
		  // Save state for edge detection AFTER scan outputs are settled
		  Dim j As Integer
		  For j = 0 To 2047
		      XPrev(j) = XBits(j)
		  Next
		  For j = 0 To 2047
		      YPrev(j) = YBits(j)
		  Next
		  For j = 0 To 8191
		      MPrev(j) = MBits(j)
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub ExecuteScan()
		  If UBound(Instructions) < 0 Then Return
		  BeginScan
		  Dim acc As Boolean = False
		  Dim pc As Integer = 0
		  Dim maxPC As Integer = UBound(Instructions)
		  Dim mcActive As Boolean = True
		  
		  While pc <= maxPC
		      Dim ins As PLCInstruction = Instructions(pc)
		      Dim op As String = ins.OpCode
		      Dim o1 As String = ins.Operand1
		      Dim o2 As String = ins.Operand2
		      Dim o3 As String = ins.Operand3
		      Dim rt As String = ins.GetRegType
		      Dim idx As Integer = ins.RegIndex
		    
		      // Master control gate
		      Dim gated As Boolean = mcActive
		    
		      Select Case op
		        // ── Basic contacts ──────────────────────────────────────
		      Case "LD"
		          acc = GetBit(rt, idx)
		      Case "LDI"
		          acc = Not GetBit(rt, idx)
		      Case "LDP"
		          acc = GetRise(rt, idx)
		      Case "LDF"
		          acc = GetFall(rt, idx)
		      Case "AND"
		          acc = acc And GetBit(rt, idx)
		      Case "ANI"
		          acc = acc And Not GetBit(rt, idx)
		      Case "ANDP"
		          acc = acc And GetRise(rt, idx)
		      Case "ANDF"
		          acc = acc And GetFall(rt, idx)
		      Case "OR"
		          acc = acc Or GetBit(rt, idx)
		      Case "ORI"
		          acc = acc Or Not GetBit(rt, idx)
		      Case "ORP"
		          acc = acc Or GetRise(rt, idx)
		      Case "ORF"
		          acc = acc Or GetFall(rt, idx)
		        // ── Block instructions ───────────────────────────────────
		      Case "ANB"
		          If StkPtr > 0 Then
		              StkPtr = StkPtr - 1
		              acc = MStack(StkPtr) And acc
		          End If
		      Case "ORB"
		          If StkPtr > 0 Then
		              StkPtr = StkPtr - 1
		              acc = MStack(StkPtr) Or acc
		          End If
		        // ── Stack ───────────────────────────────────────────────
		      Case "MPS"
		          If StkPtr <= 10 Then
		              MStack(StkPtr) = acc
		              StkPtr = StkPtr + 1
		          End If
		      Case "MRD"
		          If StkPtr > 0 Then acc = MStack(StkPtr - 1)
		      Case "MPP"
		          If StkPtr > 0 Then
		              StkPtr = StkPtr - 1
		              acc = MStack(StkPtr)
		          End If
		        // ── Output instructions ──────────────────────────────────
		      Case "OUT"
		          If gated Then
		              If rt = "Y" And idx >= 0 And idx < 2048 Then
		                  YShadow(idx) = acc
		              ElseIf rt = "M" And idx >= 0 And idx < 8192 Then
		                  MBits(idx) = acc
		              ElseIf rt = "T" And idx >= 0 And idx < 512 Then
		                  TCoil(idx) = acc
		                  TPreset(idx) = ins.KValue(o2)
		              ElseIf rt = "C" And idx >= 0 And idx < 256 Then
		                  CCoil(idx) = acc
		                  CPreset(idx) = ins.KValue(o2)
		              End If
		          End If
		      Case "OUTP"  // Pulse output - follows power flow each scan
		          If gated Then SetBit rt, idx, acc
		      Case "SET"
		          If acc And gated Then SetBit rt, idx, True
		      Case "RST"
		          If acc And gated Then
		              If rt = "T" And idx >= 0 And idx < 512 Then
		                  TCurrent(idx) = 0
		                  TContact(idx) = False
		                  TCoil(idx) = False
		              ElseIf rt = "C" And idx >= 0 And idx < 256 Then
		                  CCurrent(idx) = 0
		                  CContact(idx) = False
		                  CPrevCoil(idx) = CCoil(idx)
		              Else
		                  SetBit rt, idx, False
		              End If
		          End If
		        // ── Comparison load contacts ─────────────────────────────
		      Case "LD="
		          acc = ResolveWord(o1) = ResolveWord(o2)
		      Case "LD<>"
		          acc = ResolveWord(o1) <> ResolveWord(o2)
		      Case "LD<"
		          acc = ResolveWord(o1) < ResolveWord(o2)
		      Case "LD>"
		          acc = ResolveWord(o1) > ResolveWord(o2)
		      Case "LD<="
		          acc = ResolveWord(o1) <= ResolveWord(o2)
		      Case "LD>="
		          acc = ResolveWord(o1) >= ResolveWord(o2)
		      Case "AND="
		          acc = acc And (ResolveWord(o1) = ResolveWord(o2))
		      Case "AND<>"
		          acc = acc And (ResolveWord(o1) <> ResolveWord(o2))
		      Case "AND<"
		          acc = acc And (ResolveWord(o1) < ResolveWord(o2))
		      Case "AND>"
		          acc = acc And (ResolveWord(o1) > ResolveWord(o2))
		      Case "AND<="
		          acc = acc And (ResolveWord(o1) <= ResolveWord(o2))
		      Case "AND>="
		          acc = acc And (ResolveWord(o1) >= ResolveWord(o2))
		      Case "OR="
		          acc = acc Or (ResolveWord(o1) = ResolveWord(o2))
		      Case "OR<>"
		          acc = acc Or (ResolveWord(o1) <> ResolveWord(o2))
		      Case "OR<"
		          acc = acc Or (ResolveWord(o1) < ResolveWord(o2))
		      Case "OR>"
		          acc = acc Or (ResolveWord(o1) > ResolveWord(o2))
		      Case "OR<="
		          acc = acc Or (ResolveWord(o1) <= ResolveWord(o2))
		      Case "OR>="
		          acc = acc Or (ResolveWord(o1) >= ResolveWord(o2))
		        // ── Application instructions ─────────────────────────────
		      Case "MOV"
		          If acc Then  // execute when power flows
		              SetWord o2.Left(1), o2.Mid(2).ToInteger, ResolveWord(o1)
		          End If
		      Case "MOVP"
		          If acc Then SetWord o2.Left(1), o2.Mid(2).ToInteger, ResolveWord(o1)
		      Case "ADD"
		          If acc Then
		              Dim r As Integer = ResolveWord(o1) + ResolveWord(o2)
		              SetWord o3.Left(1), o3.Mid(2).ToInteger, r
		          End If
		      Case "ADDP"
		          If acc Then
		              Dim r As Integer = ResolveWord(o1) + ResolveWord(o2)
		              SetWord o3.Left(1), o3.Mid(2).ToInteger, r
		          End If
		      Case "SUB"
		          If acc Then
		              Dim r As Integer = ResolveWord(o1) - ResolveWord(o2)
		              SetWord o3.Left(1), o3.Mid(2).ToInteger, r
		          End If
		      Case "SUBP"
		          If acc Then
		              Dim r As Integer = ResolveWord(o1) - ResolveWord(o2)
		              SetWord o3.Left(1), o3.Mid(2).ToInteger, r
		          End If
		      Case "MUL","MULP"
		          If acc Then
		              Dim r As Integer = ResolveWord(o1) * ResolveWord(o2)
		              SetWord o3.Left(1), o3.Mid(2).ToInteger, r
		          End If
		      Case "DIV","DIVP"
		          If acc Then
		              Dim dv As Integer = ResolveWord(o2)
		              If dv <> 0 Then
		                  SetWord o3.Left(1), o3.Mid(2).ToInteger, ResolveWord(o1) \ dv
		              End If
		          End If
		      Case "INC"
		          If acc Then
		              Dim cur As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)
		              SetWord o1.Left(1), o1.Mid(2).ToInteger, cur + 1
		          End If
		      Case "INCP"
		          If acc Then
		              Dim cur As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)
		              SetWord o1.Left(1), o1.Mid(2).ToInteger, cur + 1
		          End If
		      Case "DEC"
		          If acc Then
		              Dim cur As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)
		              SetWord o1.Left(1), o1.Mid(2).ToInteger, cur - 1
		          End If
		      Case "DECP"
		          If acc Then
		              Dim cur As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)
		              SetWord o1.Left(1), o1.Mid(2).ToInteger, cur - 1
		          End If
		        // ── Bit operations ───────────────────────────────────────
		      Case "BSET"
		          If acc Then
		              Dim bidx As Integer = ResolveWord(o2)
		              Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)
		              SetWord o1.Left(1), o1.Mid(2).ToInteger, w Or Bitwise.ShiftLeft(1, bidx)
		          End If
		      Case "BCLR"
		          If acc Then
		              Dim bidx As Integer = ResolveWord(o2)
		              Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)
		              SetWord o1.Left(1), o1.Mid(2).ToInteger, w And Not Bitwise.ShiftLeft(1, bidx)
		          End If
		      Case "BTEST"  // sets M based on bit test
		          If acc Then
		              Dim bidx As Integer = ResolveWord(o2)
		              Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)
		              Dim res As Boolean = (w And Bitwise.ShiftLeft(1, bidx)) <> 0
		              MBits(o3.Mid(2).ToInteger) = res
		          End If
		        // ── Word logical ops ─────────────────────────────────────
		      Case "WAND","WANDP"
		          If acc Then
		              Dim r As Integer = ResolveWord(o1) And ResolveWord(o2)
		              SetWord o3.Left(1), o3.Mid(2).ToInteger, r
		          End If
		      Case "WOR","WORP"
		          If acc Then
		              Dim r As Integer = ResolveWord(o1) Or ResolveWord(o2)
		              SetWord o3.Left(1), o3.Mid(2).ToInteger, r
		          End If
		      Case "WXOR","WXORP"
		          If acc Or op = "WXOR" Then
		              Dim r As Integer = ResolveWord(o1) Xor ResolveWord(o2)
		              SetWord o3.Left(1), o3.Mid(2).ToInteger, r
		          End If
		      Case "CML"   // complement
		          If acc Then
		              Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)
		              SetWord o2.Left(1), o2.Mid(2).ToInteger, Not w
		          End If
		        // ── Shift/Rotate ─────────────────────────────────────────
		      Case "SHL","SHLP"
		          If acc Then
		              Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)
		              SetWord o1.Left(1), o1.Mid(2).ToInteger, Bitwise.ShiftLeft(w, ResolveWord(o2))
		          End If
		      Case "SHR","SHRP"
		          If acc Then
		              Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)
		              SetWord o1.Left(1), o1.Mid(2).ToInteger, Bitwise.ShiftRight(w, ResolveWord(o2))
		          End If
		      Case "ROL","ROLP"
		          If acc Then
		              Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)
		              Dim n As Integer = ResolveWord(o2) Mod 16
		              w = (Bitwise.ShiftLeft(w, n) Or Bitwise.ShiftRight(w, 16 - n)) And 65535
		              SetWord o1.Left(1), o1.Mid(2).ToInteger, w
		          End If
		      Case "ROR","RORP"
		          If acc Then
		              Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)
		              Dim n As Integer = ResolveWord(o2) Mod 16
		              w = (Bitwise.ShiftRight(w, n) Or Bitwise.ShiftLeft(w, 16 - n)) And 65535
		              SetWord o1.Left(1), o1.Mid(2).ToInteger, w
		          End If
		        // ── Compare (result in M flags) ──────────────────────────
		      Case "CMP"
		          Dim s1 As Integer = ResolveWord(o1)
		          Dim s2 As Integer = ResolveWord(o2)
		          Dim mBase As Integer = o3.Mid(2).ToInteger
		          MBits(mBase)     = (s1 > s2)
		          MBits(mBase + 1) = (s1 = s2)
		          MBits(mBase + 2) = (s1 < s2)
		        // ── Program flow ─────────────────────────────────────────
		      Case "CJ"
		          If acc Then
		              Dim lbl As String = o1
		              If lbl.Left(1) = "P" Then lbl = lbl.Mid(2)
		              If LabelMap.HasKey(lbl) Then
		                  pc = CType(LabelMap.Value(lbl), Integer)
		                  Continue While
		              End If
		          End If
		      Case "JMP"
		          Dim lbl As String = o1
		          If lbl.Left(1) = "P" Then lbl = lbl.Mid(2)
		          If LabelMap.HasKey(lbl) Then
		              pc = CType(LabelMap.Value(lbl), Integer)
		              Continue While
		          End If
		      Case "CALL"
		          If acc Then
		              Dim lbl As String = o1
		              If lbl.Left(1) = "P" Then lbl = lbl.Mid(2)
		              If LabelMap.HasKey(lbl) And SubPtr < 31 Then
		                  SubStack(SubPtr) = pc + 1
		                  SubPtr = SubPtr + 1
		                  pc = CType(LabelMap.Value(lbl), Integer)
		                  Continue While
		              End If
		          End If
		      Case "RET"
		          If SubPtr > 0 Then
		              SubPtr = SubPtr - 1
		              pc = SubStack(SubPtr)
		              Continue While
		          End If
		      Case "MC"   // Master Control - o1=N level, o2=M coil
		          If MCPtr < 7 Then
		              MCStack(MCPtr) = mcActive
		              MCPtr = MCPtr + 1
		          End If
		          mcActive = acc
		      Case "MCR"  // Master Control Reset
		          If MCPtr > 0 Then
		              MCPtr = MCPtr - 1
		              mcActive = MCStack(MCPtr)
		          Else
		              mcActive = True
		          End If
		      Case "LABEL"  // internal label marker - skip
		          // nothing
		      Case "FEND"   // end of main program body
		          Exit While
		      Case "END"
		          HasEnded = True
		          Exit While
		      Case "NOP"
		          // nothing
		      End Select
		      pc = pc + 1
		  Wend
		  
		  EndScan
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetBit(rt As String, idx As Integer) As Boolean
		  Select Case rt
		  Case "X"
		      If idx >= 0 And idx < 2048 Then Return XBits(idx)
		  Case "Y"
		      If idx >= 0 And idx < 2048 Then Return YBits(idx)
		  Case "M"
		      If idx >= 0 And idx < 8192 Then Return MBits(idx)
		  Case "T"
		      If idx >= 0 And idx < 512 Then Return TContact(idx)
		  Case "C"
		      If idx >= 0 And idx < 256 Then Return CContact(idx)
		  Case "SM"
		      Select Case idx
		      Case 400
		          Return True
		      Case 401
		          Return False
		      Case 402
		          Return (ScanCount = 0)
		      End Select
		  End Select
		  Return False
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetFall(rt As String, idx As Integer) As Boolean
		  Dim cur As Boolean = GetBit(rt, idx)
		  Dim prev As Boolean = False
		  Select Case rt
		  Case "X"
		      If idx >= 0 And idx < 2048 Then prev = XPrev(idx)
		  Case "Y"
		      If idx >= 0 And idx < 2048 Then prev = YPrev(idx)
		  Case "M"
		      If idx >= 0 And idx < 8192 Then prev = MPrev(idx)
		  End Select
		  Return Not cur And prev
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetRegisterDump() As String
		  Dim sb As String = ""
		  Dim i As Integer
		  sb = sb + "X: "
		  For i = 0 To 15
		      sb = sb + "X" + i.ToString + "=" + If(XBits(i),"1","0") + " "
		  Next
		  sb = sb + EndOfLine + "Y: "
		  For i = 0 To 15
		      sb = sb + "Y" + i.ToString + "=" + If(YBits(i),"1","0") + " "
		  Next
		  sb = sb + EndOfLine + "M: "
		  For i = 0 To 15
		      sb = sb + "M" + i.ToString + "=" + If(MBits(i),"1","0") + " "
		  Next
		  sb = sb + EndOfLine + "T: "
		  For i = 0 To 7
		      sb = sb + "T" + i.ToString + " PV=" + TPreset(i).ToString + " CV=" + TCurrent(i).ToString + " DN=" + If(TContact(i),"1","0") + " "
		      If i = 3 Then sb = sb + EndOfLine + "   "
		  Next
		  sb = sb + EndOfLine + "C: "
		  For i = 0 To 7
		      sb = sb + "C" + i.ToString + " PV=" + CPreset(i).ToString + " CV=" + CCurrent(i).ToString + " DN=" + If(CContact(i),"1","0") + " "
		      If i = 3 Then sb = sb + EndOfLine + "   "
		  Next
		  sb = sb + EndOfLine + "D: "
		  For i = 0 To 15
		      sb = sb + "D" + i.ToString + "=" + DRegs(i).ToString + " "
		  Next
		  Return sb
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetRise(rt As String, idx As Integer) As Boolean
		  Dim cur As Boolean = GetBit(rt, idx)
		  Dim prev As Boolean = False
		  Select Case rt
		  Case "X"
		      If idx >= 0 And idx < 2048 Then prev = XPrev(idx)
		  Case "Y"
		      If idx >= 0 And idx < 2048 Then prev = YPrev(idx)
		  Case "M"
		      If idx >= 0 And idx < 8192 Then prev = MPrev(idx)
		  End Select
		  Return cur And Not prev
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetWord(rt As String, idx As Integer) As Integer
		  Select Case rt
		  Case "D"
		      If idx >= 0 And idx < 8192 Then Return DRegs(idx)
		  Case "T"
		      If idx >= 0 And idx < 512 Then Return TCurrent(idx)
		  Case "C"
		      If idx >= 0 And idx < 256 Then Return CCurrent(idx)
		  Case "Z"
		      If idx >= 0 And idx <= 7 Then Return ZReg(idx)
		  End Select
		  Return 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Initialize()
		  ReDim XBits(2047)
		  ReDim YBits(2047)
		  ReDim YShadow(2047)
		  ReDim MBits(8191)
		  ReDim TCoil(511)
		  ReDim TContact(511)
		  ReDim TPreset(511)
		  ReDim TCurrent(511)
		  ReDim CCoil(255)
		  ReDim CContact(255)
		  ReDim CPreset(255)
		  ReDim CCurrent(255)
		  ReDim CPrevCoil(255)
		  ReDim DRegs(8191)
		  ReDim ZReg(7)
		  ReDim XPrev(2047)
		  ReDim YPrev(2047)
		  ReDim MPrev(8191)
		  ReDim MStack(10)
		  ReDim MRStack(10)
		  ReDim MCStack(7)
		  ReDim SubStack(31)
		  StkPtr = 0
		  MCPtr = 0
		  SubPtr = 0
		  ScanCount = 0
		  IsRunning = False
		  HasEnded = False
		  LabelMap = New Dictionary
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub LoadProgram(ilText As String)
		  Dim lines() As String
		  lines = ilText.Split(EndOfLine)
		  ReDim Instructions(-1)
		  LabelMap = New Dictionary
		  Dim lineNo As Integer = 0
		  For Each line As String In lines
		      Dim t As String = line.Trim
		      If t = "" Or t.Left(2) = "//" Or t.Left(1) = ";" Then
		          lineNo = lineNo + 1
		          Continue For
		      End If
		      // strip inline comments
		      Dim ci As Integer = t.IndexOf("//")
		      If ci >= 0 Then t = t.Left(ci).Trim
		      If t = "" Then
		          lineNo = lineNo + 1
		          Continue For
		      End If
		      Dim instr As New PLCInstruction(t)
		      instr.LineNumber = lineNo
		      If instr.IsLabel Then
		          LabelMap.Value(instr.LabelName) = UBound(Instructions) + 1
		      End If
		      Instructions.Append(instr)
		      lineNo = lineNo + 1
		  Next
		  StkPtr = 0
		  MCPtr = 0
		  SubPtr = 0
		  HasEnded = False
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function ResolveWord(op As String) As Integer
		  // Resolves K100, H1F, D0, T0, C0 etc to integer value
		  If op = "" Then Return 0
		  Dim rtyp As String = op.Left(1)
		  Dim suf As String = op.Mid(2)
		  Select Case rtyp
		  Case "K"
		      Return suf.ToInteger
		  Case "H"
		      Return Val("&H" + suf)
		  Case "D"
		      Return GetWord("D", suf.ToInteger)
		  Case "T"
		      Return GetWord("T", suf.ToInteger)
		  Case "C"
		      Return GetWord("C", suf.ToInteger)
		  Case "Z"
		      Return GetWord("Z", suf.ToInteger)
		  Case "R"
		      Return GetWord("D", suf.ToInteger)
		  End Select
		  Return op.ToInteger
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetBit(rt As String, idx As Integer, v As Boolean)
		  Select Case rt
		  Case "X"
		      If idx >= 0 And idx < 2048 Then XBits(idx) = v
		  Case "Y"
		      If idx >= 0 And idx < 2048 Then
		          YShadow(idx) = v
		          YBits(idx) = v
		      End If
		  Case "M"
		      If idx >= 0 And idx < 8192 Then MBits(idx) = v
		  Case "T"
		      If idx >= 0 And idx < 512 Then
		          TContact(idx) = v
		          If Not v Then TCurrent(idx) = 0
		      End If
		  Case "C"
		      If idx >= 0 And idx < 256 Then
		          If Not v Then
		              CCurrent(idx) = 0
		              CContact(idx) = False
		          End If
		      End If
		  End Select
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetWord(rt As String, idx As Integer, v As Integer)
		  Select Case rt
		  Case "D"
		      If idx >= 0 And idx < 8192 Then DRegs(idx) = v
		  Case "Z"
		      If idx >= 0 And idx <= 7 Then ZReg(idx) = v
		  End Select
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		CCoil() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		CContact() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		CCurrent() As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		CPreset() As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		CPrevCoil() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		DRegs() As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		HasEnded As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		Instructions() As PLCInstruction
	#tag EndProperty

	#tag Property, Flags = &h0
		IsRunning As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		LabelMap As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h0
		MBits() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		MCPtr As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		MCStack() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		MPrev() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		MRStack() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		MStack() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		ScanCount As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		StkPtr As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		SubPtr As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		SubStack() As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		TCoil() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		TContact() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		TCurrent() As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		TPreset() As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		XBits() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		XPrev() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		YBits() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		YPrev() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		YShadow() As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		ZReg() As Integer
	#tag EndProperty


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
		#tag ViewProperty
			Name="StkPtr"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="MCPtr"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="ScanCount"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="IsRunning"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="HasEnded"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="SubPtr"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass

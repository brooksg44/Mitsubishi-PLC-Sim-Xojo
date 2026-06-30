#tag Class
Protected Class PLCCanvas
Inherits DesktopCanvas
	#tag Event
		Sub Paint(g As Graphics, areas() As Rect)
		  g.AntiAlias = False
		  g.DrawingColor = Color.White
		  g.FillRectangle(0, 0, g.Width, g.Height)
		  
		  If Engine Is Nil Or UBound(Engine.Instructions) < 0 Then
		      g.DrawingColor = &c888888
		      g.DrawText("No program loaded. Enter IL code and click Load.", 20, g.Height\2)
		      Return
		  End If
		  
		  Const RAIL_W As Integer = 4
		  Const LEFT_X As Integer = 80
		  Dim RIGHT_X As Integer = g.Width - 80
		  Const RUNG_H As Integer = 70
		  Const ELEM_W As Integer = 70
		  Const ELEM_H As Integer = 28
		  Dim COIL_X As Integer = RIGHT_X - 90
		  
		  // Draw power rails
		  g.DrawingColor = &c001080
		  g.FillRectangle(0, 0, RAIL_W, g.Height)
		  g.FillRectangle(g.Width - RAIL_W, 0, RAIL_W, g.Height)
		  
		  // Parse instructions into rungs
		  // A rung begins with LD/LDI/LDP/LDF and ends with OUT/SET/RST/END
		  Dim y As Integer = 10 - ScrollY
		  Dim rungStart As Integer = 0
		  Dim ins As PLCInstruction
		  Dim n As Integer = UBound(Engine.Instructions)
		  Dim rungNum As Integer = 1
		  
		  Do
		      Dim rungEnd As Integer = rungStart
		      // Find end of this rung (first OUT/SET/RST/END/NOP after contacts)
		      Dim k As Integer = rungStart
		      Dim contactX As Integer = LEFT_X + RAIL_W
		      Dim hasPower As Boolean = False
		      Dim lastCoilIdx As Integer = -1
		    
		      // Draw rung number
		      g.DrawingColor = &c666666
		      g.DrawText(rungNum.ToString, 8, y + RUNG_H\2 + 5)
		    
		      // Draw horizontal rung bus
		      g.DrawingColor = &c001080
		      g.DrawLine(RAIL_W, y + RUNG_H\2, g.Width - RAIL_W, y + RUNG_H\2)
		    
		      // Draw elements
		      Dim cx As Integer = LEFT_X
		      Dim branchOpen As Boolean = False
		      Dim branchTopX As Integer = cx
		      Dim branchBotY As Integer = y + RUNG_H + 10
		      Dim branchBotX As Integer = cx
		      Dim stackBranchOpen As Boolean = False
		      Dim stackBaseX As Integer = cx
		      Dim stackRow As Integer = 0
		      Dim stackMaxRow As Integer = 0
		      Dim stackPendingBranch As Boolean = False
		      Dim stackClosePending As Boolean = False
		      Dim stackBlockMode As String = ""
		    
		      While k <= n
		          ins = Engine.Instructions(k)
		          Dim op As String = ins.OpCode
		          Dim o1 As String = ins.Operand1
		          Dim rt As String = ins.GetRegType
		          Dim bi As Integer = ins.RegIndex
		          Dim bstate As Boolean = If(Engine <> Nil, Engine.GetBit(rt, bi), False)
		          Dim isActive As Boolean = bstate
		          Dim rowY As Integer = y + stackRow * RUNG_H
		          Dim rowMid As Integer = rowY + RUNG_H\2
		      
		          Select Case op
		          Case "LD","LDI","LDP","LDF","AND","ANI","ANDP","ANDF"
		              If stackPendingBranch And op.Left(2) = "LD" Then
		                  stackRow = stackRow + 1
		                  If stackRow > stackMaxRow Then stackMaxRow = stackRow
		                  cx = stackBaseX
		                  rowY = y + stackRow * RUNG_H
		                  rowMid = rowY + RUNG_H\2
		                  g.DrawingColor = &c001080
		                  g.DrawLine(stackBaseX, y + RUNG_H\2, stackBaseX, rowMid)
		                  If stackBlockMode = "OUTPUT" Then g.DrawLine(stackBaseX, rowMid, g.Width - RAIL_W, rowMid)
		                  stackPendingBranch = False
		              End If
		              If branchOpen And op.Left(2) = "AN" Then
		                  g.DrawingColor = &c001080
		                  g.DrawLine(branchTopX, y + RUNG_H\2, branchTopX, branchBotY + ELEM_H\2)
		                  g.DrawLine(cx, y + RUNG_H\2, cx, branchBotY + ELEM_H\2)
		                  g.DrawLine(branchTopX, branchBotY + ELEM_H\2, cx, branchBotY + ELEM_H\2)
		                  branchOpen = False
		              End If
		              // Series contact
		              Dim nc As Boolean = (op = "LDI" Or op = "ANI" Or op = "ANDF")
		              Dim pe As Boolean = (op.Right(1) = "P")
		              Dim fe As Boolean = (op.Right(1) = "F")
		              If nc Then isActive = Not isActive
		              DrawContactElement(g, cx, rowMid - ELEM_H\2, ELEM_W, ELEM_H, o1, isActive, nc, pe, fe)
		              cx = cx + ELEM_W
		          Case "LD=","LD<>","LD<","LD>","LD<=","LD>=","AND=","AND<>","AND<","AND>","AND<=","AND>="
		              DrawContactElement(g, cx, rowMid - ELEM_H\2, ELEM_W, ELEM_H, ins.Operand1 + If(op.Left(3) = "AND", op.Mid(4), op.Mid(3)) + ins.Operand2, False, False, False, False)
		              cx = cx + ELEM_W
		          Case "OR","ORI","ORP","ORF"
		              // Parallel branch - draw below current rung
		              If Not branchOpen Then
		                  branchOpen = True
		                  branchTopX = cx - ELEM_W
		                  branchBotX = branchTopX
		                  branchBotY = y + RUNG_H + 8
		              End If
		              Dim nc As Boolean = (op = "ORI" Or op = "ORF")
		              Dim bst As Boolean = If(Engine <> Nil, Engine.GetBit(ins.GetRegType, ins.RegIndex), False)
		              If nc Then bst = Not bst
		              DrawContactElement(g, branchBotX, branchBotY, ELEM_W, ELEM_H, o1, bst, nc, (op.Right(1)="P"), (op.Right(1)="F"))
		              branchBotX = branchBotX + ELEM_W
		          Case "ORB"
		              // Close parallel branch
		              If stackBranchOpen And stackBlockMode = "ORB" Then
		                  g.DrawingColor = &c001080
		                  g.DrawLine(cx, y + RUNG_H\2, cx, rowMid)
		                  stackBranchOpen = False
		                  stackBlockMode = ""
		                  stackRow = 0
		              ElseIf branchOpen Then
		                  g.DrawingColor = &c001080
		                  g.DrawLine(branchTopX, y + RUNG_H\2, branchTopX, branchBotY + ELEM_H\2)
		                  g.DrawLine(cx, y + RUNG_H\2, cx, branchBotY + ELEM_H\2)
		                  g.DrawLine(branchTopX, branchBotY + ELEM_H\2, cx, branchBotY + ELEM_H\2)
		                  branchOpen = False
		              End If
		          Case "ANB"
		              // ANB combines two logic blocks in series. Visually, close any simple OR branch and continue.
		              If branchOpen Then
		                  g.DrawingColor = &c001080
		                  g.DrawLine(branchTopX, y + RUNG_H\2, branchTopX, branchBotY + ELEM_H\2)
		                  g.DrawLine(cx, y + RUNG_H\2, cx, branchBotY + ELEM_H\2)
		                  g.DrawLine(branchTopX, branchBotY + ELEM_H\2, cx, branchBotY + ELEM_H\2)
		                  branchOpen = False
		              End If
		              stackBranchOpen = False
		              stackBlockMode = ""
		          Case "MPS"
		              // Mitsubishi ladder view hides stack instructions and renders their block/branch structure.
		              Dim j As Integer = k + 1
		              Dim closeOp As String = ""
		              While j <= n
		                  Dim lookOp As String = Engine.Instructions(j).OpCode
		                  If lookOp = "MRD" Or lookOp = "MPP" Or lookOp = "ORB" Or lookOp = "ANB" Then
		                      closeOp = lookOp
		                      Exit While
		                  ElseIf lookOp = "END" Or lookOp = "FEND" Then
		                      Exit While
		                  End If
		                  j = j + 1
		              Wend
		              If closeOp = "MRD" Or closeOp = "MPP" Then
		                  stackBranchOpen = True
		                  stackBaseX = cx
		                  stackRow = 0
		                  stackMaxRow = 0
		                  stackBlockMode = "OUTPUT"
		              ElseIf closeOp = "ORB" Then
		                  stackBranchOpen = True
		                  stackBaseX = LEFT_X
		                  stackRow = 0
		                  stackMaxRow = 0
		                  stackPendingBranch = True
		                  stackBlockMode = "ORB"
		              ElseIf closeOp = "ANB" Then
		                  If branchOpen Then
		                      g.DrawingColor = &c001080
		                      g.DrawLine(branchTopX, y + RUNG_H\2, branchTopX, branchBotY + ELEM_H\2)
		                      g.DrawLine(cx, y + RUNG_H\2, cx, branchBotY + ELEM_H\2)
		                      g.DrawLine(branchTopX, branchBotY + ELEM_H\2, cx, branchBotY + ELEM_H\2)
		                      branchOpen = False
		                  End If
		                  stackBlockMode = "ANB"
		              End If
		          Case "MRD","MPP"
		              If stackBranchOpen Then
		                  stackRow = stackRow + 1
		                  If stackRow > stackMaxRow Then stackMaxRow = stackRow
		                  cx = stackBaseX
		                  rowY = y + stackRow * RUNG_H
		                  rowMid = rowY + RUNG_H\2
		                  g.DrawingColor = &c001080
		                  g.DrawLine(stackBaseX, y + RUNG_H\2, stackBaseX, rowMid)
		                  g.DrawLine(stackBaseX, rowMid, g.Width - RAIL_W, rowMid)
		                  If op = "MPP" Then stackClosePending = True
		              Else
		                  g.DrawingColor = &c001080
		                  g.FillOval(cx - 4, rowMid - 4, 8, 8)
		                  g.DrawText(op, cx - 12, rowMid + 14)
		              End If
		          Case "OUT","OUTP"
		              If branchOpen Then
		                  g.DrawingColor = &c001080
		                  g.DrawLine(branchTopX, y + RUNG_H\2, branchTopX, branchBotY + ELEM_H\2)
		                  g.DrawLine(cx, y + RUNG_H\2, cx, branchBotY + ELEM_H\2)
		                  g.DrawLine(branchTopX, branchBotY + ELEM_H\2, cx, branchBotY + ELEM_H\2)
		                  branchOpen = False
		              End If
		              // Output coil
		              Dim ost As Boolean = If(Engine <> Nil, Engine.GetBit(ins.GetRegType, ins.RegIndex), False)
		              DrawCoilElement(g, COIL_X, rowMid - ELEM_H\2, ELEM_W, ELEM_H, o1, ost, False)
		              lastCoilIdx = k
		              If stackClosePending Then
		                  stackBranchOpen = False
		                  stackClosePending = False
		              End If
		          Case "SET"
		              If branchOpen Then
		                  g.DrawingColor = &c001080
		                  g.DrawLine(branchTopX, y + RUNG_H\2, branchTopX, branchBotY + ELEM_H\2)
		                  g.DrawLine(cx, y + RUNG_H\2, cx, branchBotY + ELEM_H\2)
		                  g.DrawLine(branchTopX, branchBotY + ELEM_H\2, cx, branchBotY + ELEM_H\2)
		                  branchOpen = False
		              End If
		              Dim ost As Boolean = If(Engine <> Nil, Engine.GetBit(ins.GetRegType, ins.RegIndex), False)
		              DrawCoilElement(g, COIL_X, rowMid - ELEM_H\2, ELEM_W, ELEM_H, "S:" + o1, ost, False)
		              lastCoilIdx = k
		              If stackClosePending Then
		                  stackBranchOpen = False
		                  stackClosePending = False
		              End If
		          Case "RST"
		              If branchOpen Then
		                  g.DrawingColor = &c001080
		                  g.DrawLine(branchTopX, y + RUNG_H\2, branchTopX, branchBotY + ELEM_H\2)
		                  g.DrawLine(cx, y + RUNG_H\2, cx, branchBotY + ELEM_H\2)
		                  g.DrawLine(branchTopX, branchBotY + ELEM_H\2, cx, branchBotY + ELEM_H\2)
		                  branchOpen = False
		              End If
		              Dim ost As Boolean = If(Engine <> Nil, Engine.GetBit(ins.GetRegType, ins.RegIndex), False)
		              DrawCoilElement(g, COIL_X, rowMid - ELEM_H\2, ELEM_W, ELEM_H, "R:" + o1, ost, True)
		              lastCoilIdx = k
		              If stackClosePending Then
		                  stackBranchOpen = False
		                  stackClosePending = False
		              End If
		          Case "MOV","MOVP","ADD","ADDP","SUB","SUBP","MUL","MULP","DIV","DIVP","CMP","INC","INCP","DEC","DECP","BSET","BCLR","BTEST","SHL","SHLP","SHR","SHRP","ROL","ROLP","ROR","RORP","WAND","WANDP","WOR","WORP","WXOR","WXORP","CML","CALL","CJ","JMP","MC","MCR"
		              If branchOpen Then
		                  g.DrawingColor = &c001080
		                  g.DrawLine(branchTopX, y + RUNG_H\2, branchTopX, branchBotY + ELEM_H\2)
		                  g.DrawLine(cx, y + RUNG_H\2, cx, branchBotY + ELEM_H\2)
		                  g.DrawLine(branchTopX, branchBotY + ELEM_H\2, cx, branchBotY + ELEM_H\2)
		                  branchOpen = False
		              End If
		              DrawFBElement(g, COIL_X - ELEM_W, rowMid - ELEM_H, ELEM_W*2, ELEM_H*2, op, o1, ins.Operand2, ins.Operand3)
		              lastCoilIdx = k
		              If stackClosePending Then
		                  stackBranchOpen = False
		                  stackClosePending = False
		              End If
		          Case "END","FEND","NOP","LABEL","RET"
		              lastCoilIdx = k
		              k = k + 1
		              Exit While
		          End Select
		      
		          k = k + 1
		          // Start new rung on next LD/LDI after an output
		          If k <= n Then
		              Dim nop As String = Engine.Instructions(k).OpCode
		              If (nop.Left(2) = "LD") And lastCoilIdx >= 0 Then
		                  Exit While
		              End If
		          End If
		      Wend
		    
		      rungStart = k
		      y = y + RUNG_H * (stackMaxRow + 1) + (If(branchOpen Or branchBotX > LEFT_X, 60, 0))
		      rungNum = rungNum + 1
		      If rungStart > n Then Exit Do
		  Loop
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0
		Sub DrawCoilElement(g As Graphics, x As Integer, y As Integer, w As Integer, h As Integer, lbl As String, active As Boolean, isReset As Boolean)
		  Dim clr As Color = If(active, &cFF4400, &c444444)
		  g.DrawingColor = clr
		  // Horizontal connections
		  g.DrawLine(x, y + h\2, x + 8, y + h\2)
		  g.DrawLine(x + w - 8, y + h\2, x + w, y + h\2)
		  // Circle for coil
		  g.DrawOval(x + 8, y + 2, w - 16, h - 4)
		  // Reset coil extra line
		  If isReset Then g.DrawLine(x + 8, y + h - 2, x + w - 8, y + 2)
		  // Active fill
		  If active Then
		      g.DrawingColor = &cFF4400
		      g.FillOval(x + 9, y + 3, w - 18, h - 6)
		  End If
		  // Label
		  g.DrawingColor = &c001080
		  g.DrawText(lbl, x + w\2 - g.TextWidth(lbl)\2, y + h + 12)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub DrawContactElement(g As Graphics, x As Integer, y As Integer, w As Integer, h As Integer, lbl As String, active As Boolean, nc As Boolean, isRise As Boolean, isFall As Boolean)
		  Dim clr As Color = If(active, &c0000FF, &c444444)
		  g.DrawingColor = clr
		  // Horizontal lines above and below contact
		  g.DrawLine(x, y + h\2, x + 8, y + h\2)
		  g.DrawLine(x + w - 8, y + h\2, x + w, y + h\2)
		  // Left bar
		  g.DrawLine(x + 8, y + 2, x + 8, y + h - 2)
		  // Right bar
		  g.DrawLine(x + w - 8, y + 2, x + w - 8, y + h - 2)
		  // Normally closed diagonal
		  If nc Then g.DrawLine(x + 8, y + h - 2, x + w - 8, y + 2)
		  // Rising/Falling edge markers
		  If isRise Then
		      g.DrawText("P", x + w\2 - 4, y - 2)
		  ElseIf isFall Then
		      g.DrawText("N", x + w\2 - 4, y - 2)
		  End If
		  // Label
		  g.DrawingColor = &c001080
		  g.DrawText(lbl, x + w\2 - g.TextWidth(lbl)\2, y + h + 12)
		  // Power glow
		  If active Then
		      g.DrawingColor = &c0000FF
		      g.FillRectangle(x + 9, y + 3, w - 18, h - 6)
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub DrawFBElement(g As Graphics, x As Integer, y As Integer, w As Integer, h As Integer, op As String, o1 As String, o2 As String, o3 As String)
		  g.DrawingColor = &c333333
		  g.DrawRectangle(x, y, w, h)
		  g.DrawingColor = &c001080
		  g.DrawText(op, x + w\2 - g.TextWidth(op)\2, y + 14)
		  g.DrawingColor = Color.Black
		  Dim info As String = o1
		  If o2 <> "" Then info = info + " " + o2
		  If o3 <> "" Then info = info + " " + o3
		  g.DrawText(info, x + 4, y + 28)
		  // Connect to rung
		  g.DrawingColor = &c001080
		  g.DrawLine(x - 10, y + h\2, x, y + h\2)
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		Engine As PLCEngine
	#tag EndProperty

	#tag Property, Flags = &h0
		ScrollY As Integer
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
			InitialValue=""
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
			Name="Width"
			Visible=true
			Group="Position"
			InitialValue="100"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Height"
			Visible=true
			Group="Position"
			InitialValue="100"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="LockLeft"
			Visible=true
			Group="Position"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="LockTop"
			Visible=true
			Group="Position"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="LockRight"
			Visible=true
			Group="Position"
			InitialValue="False"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="LockBottom"
			Visible=true
			Group="Position"
			InitialValue="False"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="TabIndex"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="TabPanelIndex"
			Visible=false
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="TabStop"
			Visible=true
			Group="Position"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="AllowAutoDeactivate"
			Visible=true
			Group="Appearance"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Backdrop"
			Visible=true
			Group="Appearance"
			InitialValue=""
			Type="Picture"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Enabled"
			Visible=true
			Group="Appearance"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Tooltip"
			Visible=true
			Group="Appearance"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="AllowFocusRing"
			Visible=true
			Group="Appearance"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Visible"
			Visible=true
			Group="Appearance"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="AllowFocus"
			Visible=true
			Group="Behavior"
			InitialValue="False"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="AllowTabs"
			Visible=true
			Group="Behavior"
			InitialValue="False"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Transparent"
			Visible=true
			Group="Behavior"
			InitialValue="False"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="ScrollY"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass

#tag DesktopWindow
Begin DesktopWindow MainWindow
   Backdrop        =   0
   BackgroundColor =   &cFFFFFF
   Composite       =   False
   DefaultLocation =   2
   FullScreen      =   False
   HasBackgroundColor=   False
   HasCloseButton  =   True
   HasFullScreenButton=   False
   HasMaximizeButton=   True
   HasMinimizeButton=   True
   HasTitleBar     =   True
   Height          =   400
   ImplicitInstance=   True
   MacProcID       =   0
   MaximumHeight   =   32000
   MaximumWidth    =   32000
   MenuBar         =   ""
   MenuBarVisible  =   False
   MinimumHeight   =   64
   MinimumWidth    =   64
   Resizeable      =   True
   Title           =   "Untitled"
   Type            =   0
   Visible         =   True
   Width           =   600
End
#tag EndDesktopWindow

#tag WindowCode
	#tag Event
		Sub Opening()
		  Self.Title = "Mitsubishi MELSEC PLC Simulator"
		  Self.Width = 1400
		  Self.Height = 1102
		  
		  // Create PLC Engine
		  Engine = New PLCEngine
		  Engine.Initialize
		  
		  // ── Toolbar (top 50px) ─────────────────────────────
		  Const TB As Integer = 90
		  
		  Dim loadBtn As New DesktopButton
		  loadBtn.Caption = "Load IL"
		  loadBtn.Left = 10
		  loadBtn.Top = 8
		  loadBtn.Width = 90
		  loadBtn.Height = 34
		  Self.AddControl(loadBtn)
		  AddHandler loadBtn.Pressed, AddressOf LoadBtn_Pressed
		  
		  Dim runBtn As New DesktopButton
		  runBtn.Caption = "▶ RUN"
		  runBtn.Left = 110
		  runBtn.Top = 8
		  runBtn.Width = 90
		  runBtn.Height = 34
		  Self.AddControl(runBtn)
		  AddHandler runBtn.Pressed, AddressOf RunBtn_Pressed
		  
		  Dim stopBtn As New DesktopButton
		  stopBtn.Caption = "■ STOP"
		  stopBtn.Left = 210
		  stopBtn.Top = 8
		  stopBtn.Width = 90
		  stopBtn.Height = 34
		  Self.AddControl(stopBtn)
		  AddHandler stopBtn.Pressed, AddressOf StopBtn_Pressed
		  
		  Dim stepBtn As New DesktopButton
		  stepBtn.Caption = "» STEP"
		  stepBtn.Left = 310
		  stepBtn.Top = 8
		  stepBtn.Width = 90
		  stepBtn.Height = 34
		  Self.AddControl(stepBtn)
		  AddHandler stepBtn.Pressed, AddressOf StepBtn_Pressed
		  
		  Dim resetBtn As New DesktopButton
		  resetBtn.Caption = "↺ RESET"
		  resetBtn.Left = 410
		  resetBtn.Top = 8
		  resetBtn.Width = 90
		  resetBtn.Height = 34
		  Self.AddControl(resetBtn)
		  AddHandler resetBtn.Pressed, AddressOf ResetBtn_Pressed
		  
		  StatusLbl = New DesktopLabel
		  StatusLbl.Text = "STOP"
		  StatusLbl.Left = 520
		  StatusLbl.Top = 12
		  StatusLbl.Width = 120
		  StatusLbl.Height = 26
		  Self.AddControl(StatusLbl)
		  
		  ScanLbl = New DesktopLabel
		  ScanLbl.Text = "Scan: 0"
		  ScanLbl.Left = 660
		  ScanLbl.Top = 12
		  ScanLbl.Width = 140
		  ScanLbl.Height = 26
		  Self.AddControl(ScanLbl)
		  
		  Dim scrollUpBtn As New DesktopButton
		  scrollUpBtn.Caption = Chr(9650)
		  scrollUpBtn.Left = 806
		  scrollUpBtn.Top = 8
		  scrollUpBtn.Width = 34
		  scrollUpBtn.Height = 34
		  Self.AddControl(scrollUpBtn)
		  AddHandler scrollUpBtn.Pressed, AddressOf ScrollUp_Pressed
		  
		  Dim scrollDnBtn As New DesktopButton
		  scrollDnBtn.Caption = Chr(9660)
		  scrollDnBtn.Left = 842
		  scrollDnBtn.Top = 8
		  scrollDnBtn.Width = 34
		  scrollDnBtn.Height = 34
		  Self.AddControl(scrollDnBtn)
		  AddHandler scrollDnBtn.Pressed, AddressOf ScrollDown_Pressed
		  
		  // ── Input toggles ─────────────────────────────────
		  Dim xLbl As New DesktopLabel
		  xLbl.Text = "Inputs:"
		  xLbl.Left = 880
		  xLbl.Top = 34
		  xLbl.Width = 60
		  xLbl.Height = 24
		  Self.AddControl(xLbl)
		  
		  Dim xLabels() As String
		  xLabels = Array("X0","X1","X2","X3","X4","X5","X6","X7","X8","X9","X10","X11","X12","X13","X14","X15")
		  Dim xBtns() As DesktopButton
		  ReDim xBtns(15)
		  Dim xi As Integer
		  For xi = 0 To 15
		      Dim xb As New DesktopButton
		      xb.Caption = xLabels(xi)
		      xb.Left = 950 + (xi Mod 8) * 55
		      xb.Top = 4 + (xi \ 8) * 40
		      xb.Width = 50
		      xb.Height = 34
		      Self.AddControl(xb)
		      xBtns(xi) = xb
		      AddHandler xb.Pressed, AddressOf XInput_Pressed
		  Next
		  
		  // ── Ladder Diagram Canvas ─────────────────────────
		  LDView = New PLCCanvas
		  LDView.Engine = Engine
		  LDView.Left = 0
		  LDView.Top = TB
		  LDView.Width = 900
		  LDView.Height = 550
		  LDView.LockLeft = True
		  LDView.LockTop = True
		  LDView.LockBottom = True
		  Self.AddControl(LDView)
		  
		  // ── Sample selector ───────────────────────────────
		  SampleMenu = New DesktopPopupMenu
		  SampleMenu.Left = 902
		  SampleMenu.Top = TB
		  SampleMenu.Width = 354
		  SampleMenu.Height = 34
		  Dim samples As New SamplePrograms
		  samples.AddRows(SampleMenu)
		  SampleMenu.SelectedRowIndex = 0
		  Self.AddControl(SampleMenu)
		  Dim loadSmpBtn As New DesktopButton
		  loadSmpBtn.Caption = "Load Sample"
		  loadSmpBtn.Left = 1260
		  loadSmpBtn.Top = TB
		  loadSmpBtn.Width = 138
		  loadSmpBtn.Height = 34
		  Self.AddControl(loadSmpBtn)
		  AddHandler loadSmpBtn.Pressed, AddressOf LoadSample_Pressed
		  
		  // ── IL Editor ─────────────────────────────────────
		  ILEdit = New DesktopTextArea
		  ILEdit.Left = 902
		  ILEdit.Top = TB + 40
		  ILEdit.Width = 498
		  ILEdit.Height = 510
		  ILEdit.Multiline = True
		  ILEdit.LockRight = True
		  ILEdit.LockTop = True
		  ILEdit.LockLeft = False
		  ILEdit.Text = GetSample(0)
		  Self.AddControl(ILEdit)
		  
		  // ── Register Monitor ──────────────────────────────
		  // ── Set Register row ───────────────────────────────
		  Dim setLbl As New DesktopLabel
		  setLbl.Text = "Set Reg (e.g. D0=100, X0=1):"
		  setLbl.Left = 4
		  setLbl.Top = TB + 556
		  setLbl.Width = 240
		  setLbl.Height = 26
		  Self.AddControl(setLbl)
		  SetRegField = New DesktopTextField
		  SetRegField.Left = 248
		  SetRegField.Top = TB + 552
		  SetRegField.Width = 160
		  SetRegField.Height = 34
		  SetRegField.HasBorder = True
		  Self.AddControl(SetRegField)
		  Dim setBtn As New DesktopButton
		  setBtn.Caption = "Set"
		  setBtn.Left = 414
		  setBtn.Top = TB + 552
		  setBtn.Width = 60
		  setBtn.Height = 34
		  Self.AddControl(setBtn)
		  AddHandler setBtn.Pressed, AddressOf SetRegBtn_Pressed
		  
		  // ── Register Monitor ──────────────────────────────
		  RegList = New DesktopTextArea
		  RegList.Left = 0
		  RegList.Top = TB + 592
		  RegList.Width = 1400
		  RegList.Height = 420
		  RegList.ReadOnly = True
		  RegList.LockBottom = True
		  RegList.LockLeft = True
		  RegList.LockRight = True
		  Self.AddControl(RegList)
		  
		  // ── Scan Timer ────────────────────────────────────
		  ScanTimer = New Timer
		  ScanTimer.Period = 100
		  ScanTimer.Mode = 2
		  AddHandler ScanTimer.Action, AddressOf ScanTimer_Action
		  
		  // Load the sample program
		  LoadCurrentProgram
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0
		Sub ApplySetReg()
		  Dim input As String = SetRegField.Text.Trim
		  If input = "" Then Return
		  Dim eqPos As Integer = input.IndexOf("=")
		  If eqPos < 0 Then Return
		  Dim regName As String = input.Left(eqPos).Trim.Uppercase
		  Dim valStr As String = input.Mid(eqPos + 2).Trim
		  Dim val As Integer = valStr.ToInteger
		  Dim rt As String = regName.Left(1)
		  Dim idx As Integer = regName.Mid(2).ToInteger
		  If rt = "D" Or rt = "T" Or rt = "C" Then
		      Engine.SetWord(rt, idx, val)
		  ElseIf rt = "X" Or rt = "Y" Or rt = "M" Then
		      Engine.SetBit(rt, idx, val <> 0)
		  End If
		  SetRegField.Text = ""
		  UpdateRegisters
		  LDView.Refresh
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetSample(idx As Integer) As String
		  Dim samples As New SamplePrograms
		  Return samples.GetSample(idx)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub LoadBtn_Pressed(sender As DesktopButton)
		  LoadCurrentProgram
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub LoadCurrentProgram()
		  Engine.LoadProgram(ILEdit.Text)
		  LDView.Refresh
		  UpdateRegisters
		  StatusLbl.Text = "STOP  (" + CStr(UBound(Engine.Instructions)) + "+1 instr)"
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub LoadSample_Pressed(sender As DesktopButton)
		  Engine.Initialize
		  ILEdit.Text = GetSample(SampleMenu.SelectedRowIndex)
		  LoadCurrentProgram
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub ResetBtn_Pressed(sender As DesktopButton)
		  Engine.Initialize
		  Engine.LoadProgram(ILEdit.Text)
		  LDView.Refresh
		  UpdateRegisters
		  ScanLbl.Text = "Scan: 0"
		  StatusLbl.Text = "RESET"
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub RunBtn_Pressed(sender As DesktopButton)
		  Engine.IsRunning = True
		  ScanTimer.Mode = 2
		  StatusLbl.Text = "RUN"
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub ScanTimer_Action(sender As Timer)
		  If Not Engine.IsRunning Then Return
		  Engine.ExecuteScan
		  LDView.Refresh
		  UpdateRegisters
		  ScanLbl.Text = "Scan: " + Engine.ScanCount.ToString
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub ScrollDown_Pressed(sender As DesktopButton)
		  LDView.ScrollY = LDView.ScrollY + 140
		  LDView.Refresh
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub ScrollUp_Pressed(sender As DesktopButton)
		  LDView.ScrollY = LDView.ScrollY - 140
		  If LDView.ScrollY < 0 Then LDView.ScrollY = 0
		  LDView.Refresh
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetRegBtn_Pressed(sender As DesktopButton)
		  ApplySetReg
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetRegField_Action(sender As DesktopTextField)
		  ApplySetReg
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub StepBtn_Pressed(sender As DesktopButton)
		  Engine.ExecuteScan
		  LDView.Refresh
		  UpdateRegisters
		  ScanLbl.Text = "Scan: " + Engine.ScanCount.ToString
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub StopBtn_Pressed(sender As DesktopButton)
		  Engine.IsRunning = False
		  ScanTimer.Mode = 0
		  StatusLbl.Text = "STOP"
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub UpdateRegisters()
		  RegList.Text = Engine.GetRegisterDump
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub XInput_Pressed(sender As DesktopButton)
		  Dim idx As Integer = -1
		  Select Case sender.Caption
		  Case "X0"
		      idx = 0
		  Case "X1"
		      idx = 1
		  Case "X2"
		      idx = 2
		  Case "X3"
		      idx = 3
		  Case "X4"
		      idx = 4
		  Case "X5"
		      idx = 5
		  Case "X6"
		      idx = 6
		  Case "X7"
		      idx = 7
		  Case "X8"
		      idx = 8
		  Case "X9"
		      idx = 9
		  Case "X10"
		      idx = 10
		  Case "X11"
		      idx = 11
		  Case "X12"
		      idx = 12
		  Case "X13"
		      idx = 13
		  Case "X14"
		      idx = 14
		  Case "X15"
		      idx = 15
		  End Select
		  If idx < 0 Then Return
		  Engine.XBits(idx) = Not Engine.XBits(idx)
		  LDView.Refresh
		  UpdateRegisters
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		Engine As PLCEngine
	#tag EndProperty

	#tag Property, Flags = &h0
		ILEdit As DesktopTextArea
	#tag EndProperty

	#tag Property, Flags = &h0
		LDView As PLCCanvas
	#tag EndProperty

	#tag Property, Flags = &h0
		RegList As DesktopTextArea
	#tag EndProperty

	#tag Property, Flags = &h0
		SampleMenu As DesktopPopupMenu
	#tag EndProperty

	#tag Property, Flags = &h0
		ScanLbl As DesktopLabel
	#tag EndProperty

	#tag Property, Flags = &h0
		ScanTimer As Timer
	#tag EndProperty

	#tag Property, Flags = &h0
		SetRegField As DesktopTextField
	#tag EndProperty

	#tag Property, Flags = &h0
		StatusLbl As DesktopLabel
	#tag EndProperty

	#tag Property, Flags = &h0
		X0Btn As DesktopButton
	#tag EndProperty

	#tag Property, Flags = &h0
		X1Btn As DesktopButton
	#tag EndProperty

	#tag Property, Flags = &h0
		X2Btn As DesktopButton
	#tag EndProperty

	#tag Property, Flags = &h0
		X3Btn As DesktopButton
	#tag EndProperty

	#tag Property, Flags = &h0
		X4Btn As DesktopButton
	#tag EndProperty

	#tag Property, Flags = &h0
		X5Btn As DesktopButton
	#tag EndProperty


#tag EndWindowCode

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
		Name="Interfaces"
		Visible=true
		Group="ID"
		InitialValue=""
		Type="String"
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
		Name="Width"
		Visible=true
		Group="Size"
		InitialValue="600"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Height"
		Visible=true
		Group="Size"
		InitialValue="400"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MinimumWidth"
		Visible=true
		Group="Size"
		InitialValue="64"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MinimumHeight"
		Visible=true
		Group="Size"
		InitialValue="64"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MaximumWidth"
		Visible=true
		Group="Size"
		InitialValue="32000"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MaximumHeight"
		Visible=true
		Group="Size"
		InitialValue="32000"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Type"
		Visible=true
		Group="Frame"
		InitialValue="0"
		Type="Types"
		EditorType="Enum"
		#tag EnumValues
			"0 - Document"
			"1 - Movable Modal"
			"2 - Modal Dialog"
			"3 - Floating Window"
			"4 - Plain Box"
			"5 - Shadowed Box"
			"6 - Rounded Window"
			"7 - Global Floating Window"
			"8 - Sheet Window"
			"9 - Modeless Dialog"
		#tag EndEnumValues
	#tag EndViewProperty
	#tag ViewProperty
		Name="Title"
		Visible=true
		Group="Frame"
		InitialValue="Untitled"
		Type="String"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="HasCloseButton"
		Visible=true
		Group="Frame"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="HasMaximizeButton"
		Visible=true
		Group="Frame"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="HasMinimizeButton"
		Visible=true
		Group="Frame"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="HasFullScreenButton"
		Visible=true
		Group="Frame"
		InitialValue="False"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="HasTitleBar"
		Visible=true
		Group="Frame"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Resizeable"
		Visible=true
		Group="Frame"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="Composite"
		Visible=false
		Group="OS X (Carbon)"
		InitialValue="False"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MacProcID"
		Visible=false
		Group="OS X (Carbon)"
		InitialValue="0"
		Type="Integer"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="FullScreen"
		Visible=true
		Group="Behavior"
		InitialValue="False"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="DefaultLocation"
		Visible=true
		Group="Behavior"
		InitialValue="2"
		Type="Locations"
		EditorType="Enum"
		#tag EnumValues
			"0 - Default"
			"1 - Parent Window"
			"2 - Main Screen"
			"3 - Parent Window Screen"
			"4 - Stagger"
		#tag EndEnumValues
	#tag EndViewProperty
	#tag ViewProperty
		Name="Visible"
		Visible=true
		Group="Behavior"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="ImplicitInstance"
		Visible=true
		Group="Window Behavior"
		InitialValue="True"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="HasBackgroundColor"
		Visible=true
		Group="Background"
		InitialValue="False"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="BackgroundColor"
		Visible=true
		Group="Background"
		InitialValue="&cFFFFFF"
		Type="ColorGroup"
		EditorType="ColorGroup"
	#tag EndViewProperty
	#tag ViewProperty
		Name="Backdrop"
		Visible=true
		Group="Background"
		InitialValue=""
		Type="Picture"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MenuBar"
		Visible=true
		Group="Menus"
		InitialValue=""
		Type="DesktopMenuBar"
		EditorType=""
	#tag EndViewProperty
	#tag ViewProperty
		Name="MenuBarVisible"
		Visible=true
		Group="Deprecated"
		InitialValue="False"
		Type="Boolean"
		EditorType=""
	#tag EndViewProperty
#tag EndViewBehavior

#tag Class
Protected Class PLCEngineTests
	#tag Method, Flags = &h0
		Sub AssertBool(name As String, actual As Boolean, expected As Boolean, failures() As String)
		  If actual <> expected Then
		      failures.Append(name + ": expected " + If(expected, "True", "False") + ", got " + If(actual, "True", "False"))
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub AssertInteger(name As String, actual As Integer, expected As Integer, failures() As String)
		  If actual <> expected Then
		      failures.Append(name + ": expected " + expected.ToString + ", got " + actual.ToString)
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NewEngine(program As String) As PLCEngine
		  Dim engine As New PLCEngine
		  engine.Initialize
		  engine.LoadProgram(program)
		  Return engine
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function RunAll() As String
		  Dim failures() As String
		  
		  TestBasicOutput(failures)
		  TestTimerDoneContact(failures)
		  TestCounterRisingEdge(failures)
		  TestArithmeticAndCompare(failures)
		  TestOrbBranch(failures)
		  TestCallAndFend(failures)
		  TestValidationErrors(failures)
		  
		  If UBound(failures) < 0 Then
		      Return "PLCEngine tests passed: 7"
		  End If
		  
		  Dim failureCount As Integer = UBound(failures) + 1
		  Dim result As String = "PLCEngine tests failed: " + failureCount.ToString + EndOfLine
		  Dim i As Integer
		  For i = 0 To UBound(failures)
		      result = result + "- " + failures(i) + EndOfLine
		  Next
		  
		  Return result
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub TestArithmeticAndCompare(failures() As String)
		  Dim program As String = "LD X0" + EndOfLine + _
		      "MOV K25 D0" + EndOfLine + _
		      "ADD D0 K17 D1" + EndOfLine + _
		      "LD> D1 K40" + EndOfLine + _
		      "OUT Y1" + EndOfLine + _
		      "END"
		  Dim engine As PLCEngine = NewEngine(program)
		  
		  engine.SetBit("X", 0, True)
		  engine.ExecuteScan
		  
		  AssertInteger("Arithmetic D0", engine.GetWord("D", 0), 25, failures)
		  AssertInteger("Arithmetic D1", engine.GetWord("D", 1), 42, failures)
		  AssertBool("Comparison output Y1", engine.GetBit("Y", 1), True, failures)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub TestBasicOutput(failures() As String)
		  Dim program As String = "LD X0" + EndOfLine + _
		      "OUT Y0" + EndOfLine + _
		      "END"
		  Dim engine As PLCEngine = NewEngine(program)
		  
		  engine.SetBit("X", 0, True)
		  engine.ExecuteScan
		  AssertBool("Basic output Y0 on", engine.GetBit("Y", 0), True, failures)
		  
		  engine.SetBit("X", 0, False)
		  engine.ExecuteScan
		  AssertBool("Basic output Y0 off", engine.GetBit("Y", 0), False, failures)
		  AssertInteger("Basic output scan count", engine.ScanCount, 2, failures)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub TestCallAndFend(failures() As String)
		  Dim program As String = "LD X0" + EndOfLine + _
		      "CALL P1" + EndOfLine + _
		      "LD> D0 K4" + EndOfLine + _
		      "OUT Y0" + EndOfLine + _
		      "FEND" + EndOfLine + _
		      "1:" + EndOfLine + _
		      "LD X0" + EndOfLine + _
		      "ADD D0 K5 D0" + EndOfLine + _
		      "RET" + EndOfLine + _
		      "END"
		  Dim engine As PLCEngine = NewEngine(program)
		  
		  engine.SetWord("D", 0, 1)
		  engine.SetBit("X", 0, True)
		  engine.ExecuteScan
		  
		  AssertInteger("CALL subroutine D0", engine.GetWord("D", 0), 6, failures)
		  AssertBool("CALL continuation Y0", engine.GetBit("Y", 0), True, failures)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub TestCounterRisingEdge(failures() As String)
		  Dim program As String = "LD X0" + EndOfLine + _
		      "OUT C0 K2" + EndOfLine + _
		      "LD C0" + EndOfLine + _
		      "OUT Y0" + EndOfLine + _
		      "END"
		  Dim engine As PLCEngine = NewEngine(program)
		  
		  engine.SetBit("X", 0, True)
		  engine.ExecuteScan
		  AssertInteger("Counter first pulse", engine.GetWord("C", 0), 1, failures)
		  AssertBool("Counter not done after first pulse", engine.GetBit("C", 0), False, failures)
		  
		  engine.ExecuteScan
		  AssertInteger("Counter ignores held input", engine.GetWord("C", 0), 1, failures)
		  
		  engine.SetBit("X", 0, False)
		  engine.ExecuteScan
		  engine.SetBit("X", 0, True)
		  engine.ExecuteScan
		  AssertInteger("Counter second pulse", engine.GetWord("C", 0), 2, failures)
		  AssertBool("Counter done after second pulse", engine.GetBit("C", 0), True, failures)
		  
		  engine.ExecuteScan
		  AssertBool("Counter drives Y0 after done scan", engine.GetBit("Y", 0), True, failures)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub TestOrbBranch(failures() As String)
		  Dim program As String = "LD X0" + EndOfLine + _
		      "AND X1" + EndOfLine + _
		      "MPS" + EndOfLine + _
		      "LD X2" + EndOfLine + _
		      "AND X3" + EndOfLine + _
		      "ORB" + EndOfLine + _
		      "OUT Y0" + EndOfLine + _
		      "END"
		  Dim engine As PLCEngine = NewEngine(program)
		  
		  engine.SetBit("X", 0, True)
		  engine.SetBit("X", 1, True)
		  engine.ExecuteScan
		  AssertBool("ORB first branch", engine.GetBit("Y", 0), True, failures)
		  
		  engine.Initialize
		  engine.LoadProgram(program)
		  engine.SetBit("X", 2, True)
		  engine.SetBit("X", 3, True)
		  engine.ExecuteScan
		  AssertBool("ORB second branch", engine.GetBit("Y", 0), True, failures)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub TestValidationErrors(failures() As String)
		  Dim program As String = "LD X0" + EndOfLine + _
		      "BOGUS Y0" + EndOfLine + _
		      "ADD D0 K1" + EndOfLine + _
		      "CALL P99" + EndOfLine + _
		      "END"
		  Dim engine As PLCEngine = NewEngine(program)
		  
		  AssertBool("Validation detects errors", engine.HasValidationErrors, True, failures)
		  AssertInteger("Validation error count", UBound(engine.ValidationErrors) + 1, 3, failures)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub TestTimerDoneContact(failures() As String)
		  Dim program As String = "LD X0" + EndOfLine + _
		      "OUT T0 K2" + EndOfLine + _
		      "LD T0" + EndOfLine + _
		      "OUT Y0" + EndOfLine + _
		      "END"
		  Dim engine As PLCEngine = NewEngine(program)
		  
		  engine.SetBit("X", 0, True)
		  engine.ExecuteScan
		  AssertInteger("Timer current after first scan", engine.GetWord("T", 0), 1, failures)
		  AssertBool("Timer contact before preset", engine.GetBit("T", 0), False, failures)
		  AssertBool("Timer output before done", engine.GetBit("Y", 0), False, failures)
		  
		  engine.ExecuteScan
		  AssertInteger("Timer current at preset", engine.GetWord("T", 0), 2, failures)
		  AssertBool("Timer contact at preset", engine.GetBit("T", 0), True, failures)
		  AssertBool("Timer output waits until next scan", engine.GetBit("Y", 0), False, failures)
		  
		  engine.ExecuteScan
		  AssertBool("Timer output after done scan", engine.GetBit("Y", 0), True, failures)
		End Sub
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

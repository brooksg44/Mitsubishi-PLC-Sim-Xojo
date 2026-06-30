#tag Class
Protected Class PLCInstruction
	#tag Method, Flags = &h0
		Sub Constructor(line As String)
		  Dim parts() As String
		  Dim rawParts() As String
		  rawParts = line.Trim.Split(" ")
		  For Each part As String In rawParts
		      If part.Trim <> "" Then parts.Append(part.Trim)
		  Next
		  Dim n As Integer = UBound(parts)
		  If n < 0 Then Return
		  OpCode = parts(0).Uppercase
		  If n >= 1 Then Operand1 = parts(1).Uppercase
		  If n >= 2 Then Operand2 = parts(2).Uppercase
		  If n >= 3 Then Operand3 = parts(3).Uppercase
		  // Label detection
		  If OpCode.Right(1) = ":" Then
		      IsLabel = True
		      LabelName = OpCode.Left(OpCode.Length - 1)
		      OpCode = "LABEL"
		  End If
		  // Handle comparison load opcodes: LD=, LD<>, LD<, LD>, LD<=, LD>=
		  If OpCode.Left(2) = "LD" And OpCode.Length > 2 Then
		      // already fine - OpCode stores full token
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetRegType() As String
		  If Operand1 = "" Then Return ""
		  Return Operand1.Left(1)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function KValue(operand As String) As Integer
		  If operand = "" Then Return 0
		  If operand.Left(1) = "K" Then Return operand.Mid(2).ToInteger
		  If operand.Left(1) = "H" Then
		      Return Val("&H" + operand.Mid(2))
		  End If
		  Return operand.ToInteger
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function RegIndex() As Integer
		  If Operand1 = "" Then Return 0
		  // Mitsubishi uses octal for X/Y bits, decimal for others
		  Dim suffix As String = Operand1.Mid(2)
		  Dim rt As String = Operand1.Left(1)
		  If rt = "X" Or rt = "Y" Then
		      // X/Y addresses are octal in Mitsubishi notation
		      Return Val("&O" + suffix)
		  Else
		      Return suffix.ToInteger
		  End If
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		IsLabel As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		LabelName As String
	#tag EndProperty

	#tag Property, Flags = &h0
		LineNumber As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		OpCode As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Operand1 As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Operand2 As String
	#tag EndProperty

	#tag Property, Flags = &h0
		Operand3 As String
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
			Name="OpCode"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Operand1"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Operand2"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Operand3"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="LineNumber"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="IsLabel"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="LabelName"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass

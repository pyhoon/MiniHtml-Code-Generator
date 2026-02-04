B4J=true
Group=Helpers
ModulesStructureVersion=1
Type=Class
Version=10.3
@EndOfDesignText@
' Google Gemini
' Class: MiniHtmlCodeGenerator
Sub Class_Globals
	Private TagCounters As Map
	Private mSubMapper As Map
	Private mIndent As String = TAB
	Private mOutput As StringBuilder
	Private mReturnAsString As Boolean
End Sub

Public Sub Initialize
	mSubMapper.Initialize
	TagCounters.Initialize
End Sub

Public Sub setSubMapper (SubMapper As Map)
	mSubMapper = SubMapper
End Sub

Public Sub setReturnAsString (Value As Boolean)
	mReturnAsString = Value
End Sub

Public Sub Generate (HtmlText As String, SubName As String) As String
	Dim parser As MiniHtmlParser
	parser.Initialize
	' root is the container returned by the parser
	Dim root As HtmlNode = parser.Parse(HtmlText)
	
	mOutput.Initialize
	TagCounters.Clear
	
	' 1. Find the primary starting node (skipping DOCTYPE)
	Dim StartNode As HtmlNode
	For Each node As HtmlNode In root.Children
		If node.Name.EqualsIgnoreCase("!DOCTYPE") Then Continue
		If node.Name <> "text" And node.Name <> "comment" Then
			StartNode = node
			Exit ' Start with the first real tag (usually <html>)
		End If
	Next
	
	' Auto Sub Name
	If SubName.EqualsIgnoreCase("<Auto>") Then
		If StartNode.IsInitialized Then
			SubName = "Generate" & StartNode.Name.CharAt(0).As(String).ToUpperCase & StartNode.Name.SubString(1)
		Else
			SubName = "GenerateHtml"
		End If
	End If
	
	mOutput.Append("Sub ").Append(SubName).Append(" As ")
	If mReturnAsString Then
		mOutput.Append("String")
	Else
		mOutput.Append("MiniHtml")
	End If
	mOutput.Append(CRLF)	
	
	' 2. Begin recursive generation
	If StartNode.IsInitialized Then
		Dim varName As String = GetNextVarName(StartNode.Name)
		GenerateNodeCode(StartNode, varName, "")
		mOutput.Append(mIndent).Append("Return ").Append(varName)
		If mReturnAsString Then
			mOutput.Append(".build")
		End If
		mOutput.Append(CRLF)
	Else
		mOutput.Append(mIndent).Append("Return ")
		If mReturnAsString Then
			mOutput.Append(QUOTE & QUOTE)
		Else
			mOutput.Append("Null")
		End If
		mOutput.Append(CRLF)
	End If
	
	mOutput.Append("End Sub").Append(CRLF)
	Return mOutput.ToString
End Sub

Private Sub GenerateNodeCode (node As HtmlNode, varName As String, parentVar As String)
	' Handle CDN resources specifically (CSS links and JS scripts)
	If IsCDN(node) Then
		HandleCDN(node, parentVar)
		Return
	End If

	' Initialize the tag
	Dim initCall As String = "CreateTag(" & QUOTE & node.Name & QUOTE & ")"
	If node.Name = "meta" Then initCall = "CreateMeta"
	If mSubMapper.IsInitialized Then
		If mSubMapper.ContainsKey(node.Name) Then initCall = mSubMapper.Get(node.Name)
	End If
	
	mOutput.Append(mIndent).Append("Dim ").Append(varName).Append(" As MiniHtml = ").Append(initCall)
	If parentVar <> "" Then mOutput.Append(".up(").Append(parentVar).Append(")")
	mOutput.Append(CRLF)

	' Map standard attributes to specific MiniHtml methods
	For Each attr As HtmlAttribute In node.Attributes
		' Skip meta attributes already handled by custom logic if needed
		If node.Name = "meta" And (attr.Key = "name" Or attr.Key = "content" Or attr.Key = "charset") Then
			mOutput.Append(mIndent).Append(varName).Append(".attr(" & QUOTE).Append(attr.Key).Append(QUOTE & ", " & QUOTE).Append(attr.Value).Append(QUOTE & ")").Append(CRLF)
			Continue
		End If
		
		Select attr.Key.ToLowerCase
			Case "class": mOutput.Append(mIndent).Append(varName).Append(".cls(" & QUOTE).Append(attr.Value).Append( QUOTE & ")").Append(CRLF)
			Case "style": mOutput.Append(mIndent).Append(varName).Append(".sty(" & QUOTE).Append(attr.Value).Append(QUOTE & ")").Append(CRLF)
			Case "lang":  mOutput.Append(mIndent).Append(varName).Append(".lang(" & QUOTE).Append(attr.Value).Append(QUOTE & ")").Append(CRLF)
			Case Else:    mOutput.Append(mIndent).Append(varName).Append(".attr(" & QUOTE).Append(attr.Key).Append(QUOTE & ", " & QUOTE).Append(attr.Value).Append(QUOTE & ")").Append(CRLF)
		End Select
	Next

	' Auto-format if the tag is complex
	If node.Attributes.Size > 3 Then mOutput.Append(mIndent).Append(varName).Append(".FormatAttributes = True").Append(CRLF)

	' Process children (text, comments, and nested tags)
	For Each child As HtmlNode In node.Children
		If child.Name = "text" Then
			Dim txt As String = GetAttrValue(child, "value").Trim
			If txt <> "" Then mOutput.Append(mIndent).Append(varName).Append(".text(" & QUOTE).Append(txt).Append(QUOTE & ")").Append(CRLF)
		Else If child.Name = "comment" Then
			mOutput.Append(mIndent).Append(varName).Append(".comment2(" & QUOTE).Append(GetAttrValue(child, "value")).Append(QUOTE & ", True)").Append(CRLF)
		Else
			GenerateNodeCode(child, GetNextVarName(child.Name), varName)
		End If
	Next
End Sub

' Helpers for CDN detection and attribute extraction
Private Sub IsCDN (node As HtmlNode) As Boolean
	Return (node.Name = "link" And GetAttrValue(node, "rel") = "stylesheet") Or _
	       (node.Name = "script" And GetAttrValue(node, "src") <> "")
End Sub

Private Sub HandleCDN (node As HtmlNode, parentVar As String)
	If parentVar = "" Then Return
	Dim cdnType As String = IIf(node.Name = "link", "style", "script")
	Dim srcAttr As String = IIf(node.Name = "link", "href", "src")
	mOutput.Append(mIndent).Append(parentVar).Append($".cdn2(""$).Append(cdnType).Append($"", ""$) _
		   .Append(GetAttrValue(node, srcAttr)).Append($"", ""$).Append(GetAttrValue(node, "integrity")) _
		   .Append($"", ""$).Append(GetAttrValue(node, "crossorigin")).Append($"")"$).Append(CRLF)
End Sub

Private Sub GetNextVarName (TagName As String) As String
	TagName = TagName.Replace("-", "_").ToLowerCase
	Dim count As Int = TagCounters.GetDefault(TagName, 0) + 1
	TagCounters.Put(TagName, count)
	Return TagName & count
End Sub

Private Sub GetAttrValue (node As HtmlNode, key As String) As String
	For Each attr As HtmlAttribute In node.Attributes
		If attr.Key.EqualsIgnoreCase(key) Then Return attr.Value
	Next
	Return ""
End Sub
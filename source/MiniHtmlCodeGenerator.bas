B4J=true
Group=Helpers
ModulesStructureVersion=1
Type=Class
Version=10.3
@EndOfDesignText@
' Google Gemini
' Class: MiniHtmlCodeGenerator
Sub Class_Globals
	Private mOutput As StringBuilder
	Private TagCounters As Map
	Private mIndent As String = "    "
End Sub

Public Sub Initialize
	TagCounters.Initialize
End Sub

Public Sub Generate (HtmlText As String, SubName As String) As String
	Dim parser As MiniHtmlParser
	parser.Initialize
	Dim root As HtmlNode = parser.Parse(HtmlText)
	
	mOutput.Initialize
	TagCounters.Clear
	
	' Generate Header
	mOutput.Append("Sub ").Append(SubName).Append(" As String").Append(CRLF)
	
	For Each node As HtmlNode In root.Children
		If node.Name <> "text" And node.Name <> "comment" Then
			Dim varName As String = GetNextVarName(node.Name)
			GenerateNodeCode(node, varName, "")
			mOutput.Append(mIndent).Append("Return ").Append(varName).Append(".Build").Append(CRLF)
			Exit 
		End If
	Next
	
	mOutput.Append("End Sub").Append(CRLF)
	Return mOutput.ToString
End Sub

Private Sub GenerateNodeCode (node As HtmlNode, varName As String, parentVar As String)
	' 1. Check for CDN Resources (CSS/JS)
	If IsCDN(node) Then
		HandleCDN(node, parentVar)
		Return
	End If

	' 2. Tag Initialization
	Dim initCall As String = "CreateTag(""" & node.Name & """)"
	If node.Name = "meta" Then initCall = "CreateMeta"
	
	mOutput.Append(mIndent).Append("Dim ").Append(varName).Append(" As MiniHtml = ").Append(initCall)
	If parentVar <> "" Then mOutput.Append(".up(").Append(parentVar).Append(")")
	mOutput.Append(CRLF)

	' 3. Attribute Mapping
	For Each attr As HtmlAttribute In node.Attributes
		If node.Name = "meta" And (attr.Key = "name" Or attr.Key = "content" Or attr.Key = "charset") Then Continue
		
		Select Case attr.Key.ToLowerCase
			Case "class": mOutput.Append(mIndent).Append(varName).Append(".cls(""").Append(attr.Value).Append(""")").Append(CRLF)
			Case "style": mOutput.Append(mIndent).Append(varName).Append(".sty(""").Append(attr.Value).Append(""")").Append(CRLF)
			Case "lang":  mOutput.Append(mIndent).Append(varName).Append(".lang(""").Append(attr.Value).Append(""")").Append(CRLF)
			Case Else:    mOutput.Append(mIndent).Append(varName).Append(".attr(""").Append(attr.Key).Append(""", """).Append(attr.Value).Append(""")").Append(CRLF)
		End Select
	Next

	' 4. Formatting & Children
	If node.Attributes.Size > 3 Then mOutput.Append(mIndent).Append(varName).Append(".FormatAttributes = True").Append(CRLF)

	For Each child As HtmlNode In node.Children
		If child.Name = "text" Then
			Dim txt As String = GetAttrValue(child, "value").Trim
			If txt <> "" Then mOutput.Append(mIndent).Append(varName).Append(".text(""").Append(txt).Append(""")").Append(CRLF)
		Else If child.Name = "comment" Then
			mOutput.Append(mIndent).Append(varName).Append(".comment2(""").Append(GetAttrValue(child, "value")).Append(""", True)").Append(CRLF)
		Else
			GenerateNodeCode(child, GetNextVarName(child.Name), varName)
		End If
	Next
End Sub

' --- Internal Helpers ---

Private Sub IsCDN (node As HtmlNode) As Boolean
	Return (node.Name = "link" And GetAttrValue(node, "rel") = "stylesheet") Or _
	       (node.Name = "script" And GetAttrValue(node, "src") <> "")
End Sub

Private Sub HandleCDN (node As HtmlNode, parentVar As String)
	If parentVar = "" Then Return
	Dim cdnType As String = IIf(node.Name = "link", "style", "script")
	Dim srcAttr As String = IIf(node.Name = "link", "href", "src")
	mOutput.Append(mIndent).Append(parentVar).Append(".cdn2(""").Append(cdnType).Append(""", """) _
		   .Append(GetAttrValue(node, srcAttr)).Append(""", """).Append(GetAttrValue(node, "integrity")) _
		   .Append(""", """).Append(GetAttrValue(node, "crossorigin")).Append(""")").Append(CRLF)
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
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

' Main entry point: Takes an HTML string and returns B4X Code
Public Sub Generate (HtmlText As String, SubName As String) As String
    Dim parser As MiniHtmlParser
    parser.Initialize
    Dim root As HtmlNode = parser.Parse(HtmlText)
    
    mOutput.Initialize
    TagCounters.Clear
    
    mOutput.Append("Sub ").Append(SubName).Append(" As String").Append(CRLF)
    
    ' Start recursion from the first real tag (usually <html>)
    For Each node As HtmlNode In root.Children
        If node.Name <> "text" And node.Name <> "comment" Then
            Dim varName As String = GetNextVarName(node.Name)
            GenerateNodeCode(node, varName, "")
            mOutput.Append(mIndent).Append("Return ").Append(varName).Append(".Build").Append(CRLF)
            Exit ' Only process the first root tag
        End If
    Next
    
    mOutput.Append("End Sub").Append(CRLF)
    Return mOutput.ToString
End Sub

Private Sub GenerateNodeCode (node As HtmlNode, varName As String, parentVar As String)
    ' 1. Declaration and Initialization
    mOutput.Append(mIndent).Append("Dim ").Append(varName).Append(" As MiniHtml = ")
    mOutput.Append("CreateTag(""").Append(node.Name).Append(""")")
    
    ' 2. Handle Parent relationship
    If parentVar <> "" Then
        mOutput.Append(".up(").Append(parentVar).Append(")")
    End If
    mOutput.Append(CRLF)

    ' 3. Handle Classes and Styles separately for cleaner code
    For Each attr As HtmlAttribute In node.Attributes
        If attr.Key = "class" Then
            mOutput.Append(mIndent).Append(varName).Append(".cls(""").Append(attr.Value).Append(""")").Append(CRLF)
        Else If attr.Key = "style" Then
            mOutput.Append(mIndent).Append(varName).Append(".sty(""").Append(attr.Value).Append(""")").Append(CRLF)
        Else
            mOutput.Append(mIndent).Append(varName).Append(".attr(""").Append(attr.Key).Append(""", """).Append(attr.Value).Append(""")").Append(CRLF)
        End If
    Next

    ' 4. Handle Children (Recursion)
    For Each child As HtmlNode In node.Children
        If child.Name = "text" Then
            ' Extract text from the value attribute your parser uses
            Dim txt As String = GetAttrValue(child, "value")
            If txt.Trim <> "" Then
                mOutput.Append(mIndent).Append(varName).Append(".text(""").Append(txt.Trim).Append(""")").Append(CRLF)
            End If
        Else If child.Name = "comment" Then
            Dim commentTxt As String = GetAttrValue(child, "value")
            mOutput.Append(mIndent).Append(varName).Append(".comment2(""").Append(commentTxt).Append(""", True)").Append(CRLF)
        Else
            ' It's a nested tag
            Dim childVar As String = GetNextVarName(child.Name)
            GenerateNodeCode(child, childVar, varName)
        End If
    Next
End Sub

' Helper to get unique variable names like div1, div2
Private Sub GetNextVarName (TagName As String) As String
    TagName = TagName.Replace("-", "_").ToLowerCase
    Dim count As Int = TagCounters.GetDefault(TagName, 0)
    count = count + 1
    TagCounters.Put(TagName, count)
    Return TagName & count
End Sub

Private Sub GetAttrValue (node As HtmlNode, key As String) As String
    For Each attr As HtmlAttribute In node.Attributes
        If attr.Key = key Then Return attr.Value
    Next
    Return ""
End Sub
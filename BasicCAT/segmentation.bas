﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=StaticCode
Version=6.51
@EndOfDesignText@
'Static code module
Sub Process_Globals
	Private fx As JFX
End Sub

Public Sub segmentedTxt(text As String,Trim As Boolean,sourceLang As String,filetype As String) As List
	Dim segmentationRule As List
	If filetype="idml" Then
		segmentationRule=File.ReadList(File.DirAssets,"segmentation_"&sourceLang&"_idml.conf")
	Else
		segmentationRule=File.ReadList(File.DirAssets,"segmentation_"&sourceLang&".conf")
	End If
	
	Dim segmentationExceptionRule As List
	segmentationExceptionRule=File.ReadList(File.DirAssets,"segmentation_"&sourceLang&"_exception.conf")
	
	Dim seperatedByCRLF As String
	seperatedByCRLF=text
	For Each rule As String In segmentationRule
		seperatedByCRLF=Regex.Replace(rule,seperatedByCRLF,"$0"&CRLF)
	Next

	For Each rule As String In segmentationExceptionRule
		seperatedByCRLF=seperatedByCRLF.Replace(rule&CRLF,rule)
	Next
	Dim out As List
	out.Initialize
	For Each sentence As String In Regex.Split(CRLF,seperatedByCRLF)
		If Trim Then
			sentence=sentence.Trim
		End If
		out.Add(sentence)
	Next
	Log(out)
	Return out
End Sub
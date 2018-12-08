﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=6.51
@EndOfDesignText@
Sub Class_Globals
	Private fx As JFX
	Public translationMemory As KeyValueStore
	Public externalTranslationMemory As KeyValueStore
	Private sharedTM As ClientKVS
	Private similarityStore As Map
	Public currentSource As String
	Private projectName As String
End Sub

'Initializes the object. You can add parameters to this method if needed.
Public Sub Initialize(projectPath As String)
	translationMemory.Initialize(File.Combine(projectPath,"TM"),"TM.db")
    externalTranslationMemory.Initialize(File.Combine(projectPath,"TM"),"externalTM.db")
	similarityStore.Initialize
	initSharedTM(projectPath)
End Sub

Public Sub initSharedTM(projectPath As String)
	If Main.currentProject.settings.GetDefault("sharingTM_enabled",False)=True Then
		projectName=File.GetName(projectPath)
		Log("projectName"&projectName)
		Dim address As String=Main.currentProject.settings.GetDefault("server_address","http://127.0.0.1:51042")
		Dim key As String
		If File.Exists(Main.currentProject.path,"accesskey") Then
			key=File.ReadString(Main.currentProject.path,"accesskey")
		Else
			key="put your key in this file"
		End If
		sharedTM.Initialize(Me, "sharedTM", address,File.Combine(projectPath,"TM"),"sharedTM.db",key)
		sharedTM.SetAutoRefresh(Array(projectName&"TM"), 0.1) 'auto refresh every 0.1 minute
		Dim job As HttpJob
		job.Initialize("job",Me)
		If address.EndsWith("/")=False Then
			address=address&"/"
		End If
		job.Download(address&"getinfo?type=size&user="&projectName&"TM")
		wait for (job) JobDone(job As HttpJob)
		If job.Success Then
			Try
				Dim size As Int=job.GetString
				If size=0 Then
					fillSharedTM
				End If
			Catch
				Log(LastException)
			End Try
		End If
		job.Release
	End If
End Sub


Sub fillSharedTM
	'progressDialog.Show("Filling SharedTM","sharedTM")
	Dim tmmap As Map
	tmmap=sharedTM.GetAll(projectName&"TM")
	'Dim size As Int=translationMemory.ListKeys.Size
	Dim index As Int=0
	Dim toAddMap As Map
	toAddMap.Initialize
	For Each key As String In translationMemory.ListKeys
		index=index+1
	    Sleep(0)
		'progressDialog.update(index,size)
		If tmmap.ContainsKey(key) Then
			
			Dim previousTargetMap As Map=translationMemory.Get(key)
			Dim newTargetMap As Map=tmmap.Get(key)
			Dim previousCreatedTime,newCreatedTime As Long
			previousCreatedTime=previousTargetMap.Get("createdTime")
			newCreatedTime=newTargetMap.Get("createdTime")
			
			If previousTargetMap.Get("text")<>translationMemory.Get("text") And newCreatedTime>previousCreatedTime Then
				toAddMap.Put(key,translationMemory.Get(key))
			End If
		Else
			toAddMap.Put(key,translationMemory.Get(key))
		End If
	Next
	fillALL(toAddMap)
	'progressDialog.close
End Sub

Sub fillALL(toAddMap As Map)
	For Each key As String In toAddMap.Keys
		Sleep(0)
		sharedTM.Put(projectName&"TM",key,toAddMap.Get(key))
	Next
End Sub


Sub sharedTM_NewData(changedItems As List)
	Log("changed"&changedItems)
	Dim changedKeys As List
	changedKeys.Initialize

	Dim map1 As Map=sharedTM.GetAll(projectName&"TM")
	For Each item1 As Item In changedItems
		If item1.UserField=projectName&"TM" Then
			If item1.ValueField=Null Then 'remove
				sharedTM.removeLocal(item1.UserField,item1.KeyField)
				If translationMemory.ContainsKey(item1.KeyField) Then
					translationMemory.Remove(item1.KeyField)
				End If
				Continue
			End If
			
			If translationMemory.ContainsKey(item1.KeyField) Then

				Dim previousTargetMap,newTargetMap As Map
				previousTargetMap=translationMemory.Get(item1.KeyField)
				newTargetMap=map1.Get(item1.KeyField)
				Dim previousCreatedTime,newCreatedTime As Long
				previousCreatedTime=previousTargetMap.Get("createdTime")
				newCreatedTime=newTargetMap.Get("createdTime")
				
				If newCreatedTime>previousCreatedTime Then
					translationMemory.Put(item1.KeyField,map1.Get(item1.KeyField))
					changedKeys.Add(item1.KeyField)
				End If
			Else
				translationMemory.Put(item1.KeyField,map1.Get(item1.KeyField))
				changedKeys.Add(item1.KeyField)
			End If
		End If
	Next
	Main.currentProject.saveNewDataToWorkfile(changedKeys)
End Sub

public Sub close
	If translationMemory.IsInitialized Then
		translationMemory.Close
		externalTranslationMemory.Close
	End If
End Sub

Sub addPair(source As String,targetMap As Map)
    Dim target As String
	target=targetMap.Get("text")
	Dim createdTime As Long
	createdTime=targetMap.Get("createdTime")
	If translationMemory.ContainsKey(source) Then
		Dim previousTargetMap As Map
		previousTargetMap=translationMemory.Get(source)
		Dim previousCreatedTime As Long=previousTargetMap.GetDefault("createdTime",0)
		If previousTargetMap.Get("text")=target Then
			Return
		End If
		If previousCreatedTime>createdTime Then
			Return
		End If
	End If
	translationMemory.Put(source,targetMap)
	addPairToSharedTM(source,targetMap)
End Sub

Public Sub addPairToSharedTM(source As String,targetMap As Map)
	If Main.currentProject.settings.GetDefault("sharingTM_enabled",False)=True Then
		sharedTM.Put(projectName&"TM",source,targetMap)
	End If
End Sub

Public Sub removeFromSharedTM(source As String)
	If Main.currentProject.settings.GetDefault("sharingTM_enabled",False)=True Then
		sharedTM.Put(projectName&"TM", source, Null) ' this equals remove method
	End If
End Sub

Public Sub deleteExternalTranslationMemory
	externalTranslationMemory.DeleteAll
End Sub

Public Sub importExternalTranslationMemory(tmList As List,projectFile As Map) As ResumableSub
	progressDialog.Show("Loading external memory","loadtm")
	Dim segments As List
	segments.Initialize
	For Each tmfile As String In tmList
		Dim tmfileLowercase As String
		tmfileLowercase=tmfile.ToLowerCase
		If tmfileLowercase.EndsWith(".txt") Then
			segments.AddAll(importedTxt(tmfile))
		Else if tmfileLowercase.EndsWith(".tmx") Then
			segments.AddAll(TMX.importedList(File.Combine(Main.currentProject.path,"TM"),tmfile,projectFile.Get("source"),projectFile.Get("target")))
		End If
	Next
	Log(segments)
	If segments.Size<>0 Then
		Dim index As Int=0
		For Each bitext As List In segments
			index=index+1
			progressDialog.update(index,segments.Size)
			Sleep(0)
			Dim source,target,filename As String
			Dim targetMap As Map
			targetMap.Initialize
			If bitext.Size=3 Then
				source=bitext.get(0)
				target=bitext.Get(1)
				filename=bitext.Get(2)
			Else
				Continue
			End If

			targetMap.Put("text",target)
			targetMap.Put("filename",filename)
			externalTranslationMemory.put(source,targetMap)
		Next
	End If
	Log(externalTranslationMemory.ListKeys.Size)
	progressDialog.close
	Return True
End Sub

Sub importedTxt(filename As String) As List
	Dim content As String
	content=File.ReadString(File.Combine(Main.currentProject.path,"TM"),filename)
	Dim segments As List
	segments=Regex.Split(CRLF,content)
	Dim result As List
	result.Initialize
	For Each line As String In segments

        Dim bitext As List
		bitext.Initialize
		Dim source,target As String

		source=Regex.Split("	",line)(0)
		target=Regex.Split("	",line)(1)
		bitext.Add(source)
		bitext.Add(target)
		bitext.Add(filename)
		result.Add(bitext)
	Next
	Return result
End Sub


Sub getMatchList(source As String) As ResumableSub
	Dim matchList As List
	matchList.Initialize

    Dim matchrate As Double
	If Main.currentProject.settings.ContainsKey("matchrate") Then
		matchrate=Main.currentProject.settings.Get("matchrate")
	Else
		matchrate=0.5
	End If
	For i=0 To 1
		If i=0 Then
			Dim kvs As KeyValueStore
			kvs=translationMemory
		Else
			Dim kvs As KeyValueStore
			kvs=externalTranslationMemory
		End If
		For Each key As String In kvs.ListKeys
			Sleep(0)
			If basicCompare(source,key)=False Then
				Continue
			End If

			'Dim pairList As List
			'pairList.Initialize
			'pairList.Add(source)
			'pairList.Add(key) ' two sourcelanguage sentences
			'Dim json As JSONGenerator
			'json.Initialize2(pairList)
			Dim similarity As Double
			If key=source Then 'exact match
				similarity=1.0
			Else
				If similarityStore.ContainsKey(source&"	"&key) Then
					similarity=similarityStore.Get(source&"	"&key)
				Else
					wait for (getSimilarityFuzzyWuzzy(source,key)) Complete (Result As Double)
					similarity=Result
					similarityStore.Put(source&"	"&key,similarity)
				End If
			End If

			If similarity>matchrate Then
				Dim tmPairList As List
				tmPairList.Initialize
				tmPairList.Add(similarity)
				tmPairList.Add(key)
				
				Dim target As String
				Dim targetMap As Map
				targetMap=kvs.Get(key)
				target=targetMap.Get("text")
				tmPairList.Add(target)
				If i=0 Then
					tmPairList.Add(targetMap.GetDefault("creator","anonymous"))
				Else
					tmPairList.Add(targetMap.Get("filename")) ' external tm name
				End If
				Log(tmPairList)
				matchList.Add(tmPairList)
			End If
		Next
    Next
	
	Return subtractedAndSortMatchList(matchList)
End Sub


Sub getOneUseMemory(source As String,rate As Double) As ResumableSub
	
	Dim matchList As List
	matchList.Initialize
	Dim onePairList As List
	onePairList.Initialize
	For i=0 To 1
		If i=0 Then
			Dim kvs As KeyValueStore
			kvs=translationMemory
		Else
			Dim kvs As KeyValueStore
			kvs=externalTranslationMemory
		End If
		
		If kvs.ContainsKey(source) Then
			Dim tmPairList As List
			tmPairList.Initialize
			tmPairList.Add(1)
			tmPairList.Add(source)
			
			Dim target As String
			Dim targetMap As Map
			targetMap=kvs.Get(source)
			target=targetMap.Get("text")
			
			If i=0 Then
				tmPairList.Add(target)
				tmPairList.Add(targetMap.GetDefault("creator","anonymous"))
			Else
				tmPairList.Add(target)
				tmPairList.Add(targetMap.Get("filename"))
			End If
			onePairList=tmPairList
			Return onePairList
		End If
		
		For Each key As String In kvs.ListKeys
			If basicCompare(source,key)=False Then
				Continue
			End If
			
			
			
			Dim similarity As Double
			
			If similarityStore.ContainsKey(source&"	"&key) Then
				similarity=similarityStore.Get(source&"	"&key)
			Else
				wait for (getSimilarityFuzzyWuzzy(source,key)) Complete (Result As Double)
				similarity=Result
				similarityStore.Put(source&"	"&key,similarity)
			End If
			




			If similarity>rate Then
				
				Dim target As String
				Dim targetMap As Map
				targetMap=kvs.Get(key)
				target=targetMap.Get("text")
				
				Dim tmPairList As List
				tmPairList.Initialize
				tmPairList.Add(similarity)
				tmPairList.Add(key)
				
				If i=0 Then
					tmPairList.Add(target)
					tmPairList.Add("")
				Else
					tmPairList.Add(target)
					tmPairList.Add(targetMap.Get("filename"))
				End If
				If similarity=1 Then
					'Log("exact match")
					onePairList=tmPairList
					Return onePairList
				End If
				matchList.Add(tmPairList)
			End If
		Next
	Next
	If matchList.Size=0 Then
		Return onePairList
	End If
	onePairList=subtractedAndSortMatchList(matchList).Get(0)
	Return onePairList
End Sub

Sub basicCompare(str1 As String,str2 As String) As Boolean
	Dim temp As String
	If str1.Length>str2.Length Then
		temp=str1
		str1=str2
		str2=temp
	End If
	If str1.Length-str2.Length>str2.Length/2 Then
		Return False
	Else
		Return True
	End If
	
End Sub

Sub subtractedAndSortMatchList(matchList As List) As List
	If matchList.Size<=1 Then
		Return matchList
	End If
	Dim newlist As List
	newlist.Initialize
	Dim sortedList As List
	sortedList=BubbleSort(matchList)
	For i=0 To Min(4,sortedList.Size-1)
		newlist.Add(sortedList.Get(i))
	Next
	Return newlist
End Sub

Sub BubbleSort(matchList As List) As List
	For j=0 To matchList.Size-1
		For i = 1 To matchList.Size - 1
			If  NextIsMoreSimilar(matchList.Get(i),matchList.Get(i-1)) Then
				matchList=Swap(matchList,i, i-1)
			End If
		Next
	Next
	Return matchList
End Sub

Sub Swap(matchList As List,index1 As Int, index2 As Int) As List
	Dim temp As List
	temp = matchList.Get(index1)
	matchList.Set(index1,matchList.Get(index2))
	matchList.Set(index2,temp)
	Return matchList
End Sub

Sub NextIsMoreSimilar(list2 As List,list1 As List) As Boolean
	'list2 is the next
	If list2.Get(0)>list1.Get(0) Then
		Return True
	Else
		Return False
	End If
End Sub

Sub getSimilarityFuzzyWuzzy(str1 As String,str2 As String) As ResumableSub
	Sleep(0)
	Dim result As Double
	Dim jo As JavaObject
	result=jo.InitializeStatic("me.xdrop.fuzzywuzzy.FuzzySearch").RunMethod("ratio",Array As String(str1,str2))
	result=result/100
	Return result
End Sub

Sub getExternalMemorySize As Int
	Return externalTranslationMemory.ListKeys.Size
End Sub

Sub getProjectMemorySize As Int
	Return externalTranslationMemory.ListKeys.Size+translationMemory.ListKeys.Size
End Sub


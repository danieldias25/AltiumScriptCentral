'
' @file               NumberSchematics.vbs
' @author             Geoffrey Hunter <gbmhunter@gmail.com> (www.mbedded.ninja)
' @created            2013-08-08
' @last-modified      2015-01-22
' @brief              Numbers all schematic sheets for the current project. Designed to work
'                     with a schematic template which displays the sheet number and total sheets
'                     on the schematic.
' @details
'                     See README.rst in repo root dir for more info.

' Forces us to explicitly define all variables before using them
Option Explicit

' @brief The name of this module for logging purposes
Private moduleName
moduleName = "NumberSchematics.vbs"

' @brief     Numbers all schematic sheets for the current project.
' @param     DummyVar    Dummy variable so that this sub does not show up to the user when
'                        they click "Run Script".
Sub NumberSchematics(dummyVar)

    'StdOut("Numbering schematics...")

    ' Obtain the schematic server interface.
    If SchServer Is Nothing Then
        ShowMessage("ERROR: Schematic server not online.")
        Exit Sub
    End If

    ' Get pcb project interface
    Dim workspace           ' As IWorkspace
    Set workspace = GetWorkspace

    Dim pcbProject          ' As IProject
    Set pcbProject = workspace.DM_FocusedProject

    If pcbProject Is Nothing Then
        ShowMessage("ERROR: Current project is not a PCB project")
        Exit Sub
    End If

   ' COMPILE PROJECT

    ResetParameters
    Call AddStringParameter("Action", "Compile")
    Call AddStringParameter("ObjectKind", "Project")
    Call RunProcess("WorkspaceManager:Compile")

   Set flatHierarchy = PCBProject.DM_DocumentFlattened

   ' If we couldn't get the flattened sheet, then most likely the project has
   ' not been compiled recently
   Dim flatHierarchy       ' As IDocument
   If flatHierarchy Is Nothing Then
      ShowMessage("ERROR: Compile the project before running this script.")
      Exit Sub
   End If

   Dim totalSheetCount     ' As Integer
   totalSheetCount = 0

   ' COUNT SCHEMATIC SHEETS

    ' Loop through all project documents to count schematic sheets
    Dim docNum              ' As Integer
    For docNum = 0 To pcbProject.DM_LogicalDocumentCount - 1
        Dim document            ' As IDocument
        Set document = pcbProject.DM_LogicalDocuments(docNum)

        ' If this is SCH document
        If document.DM_DocumentKind = "SCH" Then
            Dim sheet               ' As ISch_Document
            Set sheet = SCHServer.GetSchDocumentByPath(document.DM_FullPath)
            If sheet Is Nothing Then
                ShowMessage("ERROR: Sheet '" + document.DM_FullPath + "' could not be retrieved." + VbCr + VbLf)
                Exit Sub
            End If
            ' Increment count
            totalSheetCount = totalSheetCount + 1
        End If ' If document.DM_DocumentKind = "SCH" Then
    Next

    ' ADD SCHEMATIC NUMBER AND TOTAL COUNT
    Dim schematicSheetCount ' As Integer
    schematicSheetCount = 0

    ' Now loop through all project documents again to number sheets
    ' Note that if we use the default ordering, they are guaranteed to be numbered
    ' as laid out in the "Projects" window. This is confusing.
    For docNum = 0 To pcbProject.DM_LogicalDocumentCount - 1
        Set document = pcbProject.DM_LogicalDocuments(docNum)

        ' If this is SCH document
        If document.DM_DocumentKind = "SCH" Then
            Set sheet = SCHServer.GetSchDocumentByPath(document.DM_FullPath)
            'ShowMessage(document.DM_FullPath);
            If sheet Is Nothing Then
                ShowMessage("ERROR: No sheet found." + VbCr + VbLf)
                Exit Sub
            End If

            ' Increment sheet count
            schematicSheetCount = schematicSheetCount + 1

            ' Start of undo block
            Call SchServer.ProcessControl.PreProcess(sheet, "")

            '===== REMOVE EXISTING PARAMETERS IF THEY EXIST ====='

            ' Set up iterator to look for parameter objects only
            Dim paramIterator
            Set paramIterator = sheet.SchIterator_Create
            If paramIterator Is Nothing Then
                ShowMessage("ERROR: Iterator could not be created.")
                Exit Sub
            End If

            ' Set up iterator mask
            paramIterator.AddFilter_ObjectSet(MkSet(eParameter))

            Dim schParameters
            Set schParameters = paramIterator.FirstSchObject

            ' Iterate through exising parameters
            Do While Not (schParameters Is Nothing)
                 ' Look for sheet count or total count parameters
                 If schParameters.Name = SCHEMATIC_SHEET_COUNT_PARAM_NAME Or schParameters.Name = TOTAL_SHEET_PARAM_NAME Then
                       ' Remove parameter before adding again
                       sheet.RemoveSchObject(schParameters)
                       Call SchServer.RobotManager.SendMessage(sheet.I_ObjectAddress, c_BroadCast, SCHM_PrimitiveRegistration, schParameters.I_ObjectAddress)
                 End If

                Set schParameters = paramIterator.NextSchObject
            Loop

            sheet.SchIterator_Destroy(paramIterator)

            '===== ADDING NEW PARAMETERS ====='

            ' Add schematic sheet number and total count as parameters

            Dim sheetCountParam
            sheetCountParam = SchServer.SchObjectFactory(eParameter, eCreate_Default)
            sheetCountParam.Name = SCHEMATIC_SHEET_COUNT_PARAM_NAME
            sheetCountParam.Text = schematicSheetCount
            sheet.AddSchObject(sheetCountParam)

            ' Tell server about change
            Call SchServer.RobotManager.SendMessage(sheet.I_ObjectAddress, c_BroadCast, SCHM_PrimitiveRegistration, sheetCountParam.I_ObjectAddress)

            Dim totalSheetsParam
            totalSheetsParam = SchServer.SchObjectFactory(eParameter, eCreate_Default)
            totalSheetsParam.Name = TOTAL_SHEET_PARAM_NAME
            totalSheetsParam.Text = totalSheetCount
            sheet.AddSchObject(totalSheetsParam)

            ' Tell server about change
            Call SchServer.RobotManager.SendMessage(sheet.I_ObjectAddress, c_BroadCast, SCHM_PrimitiveRegistration, totalSheetsParam.I_ObjectAddress)

            ' End of undo block
            Call SchServer.ProcessControl.PostProcess(sheet, "")

        End If ' If document.DM_DocumentKind = "SCH" Then
    Next ' For docNum = 0 To pcbProject.DM_LogicalDocumentCount - 1

    ShowMessage("Schematic numbers have been added to '" + CStr(totalSheetCount) + "' sheets.")

End Sub

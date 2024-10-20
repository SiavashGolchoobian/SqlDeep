USE [msdb]
GO
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SqlDeep' AND category_class=1)
BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SqlDeep'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Local_SqlDeep_ScriptRepositoryVAR_JOBNAME', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'SqlDeep', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ExportScriptFile]    Script Date: 9/10/2024 10:00:43 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ExportScriptFile', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=4, 
		@on_fail_step_id=3, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'
#-----------User Inputs
[string]$myDestinationFolderPath = "U:\Install\Scripts\JobRepo\$(ESCAPE_SQUOTE(JOBID))"
[string]$myCommand = "SELECT [myItems].[ItemName],[myItems].[SubscriberItemId] FROM [SqlDeep].[repository].[dbafn_get_subscriber_item_and_dependencies] (''VAR_REPOSITORYITEMNAME'',Null,Null) AS myItems WHERE [myItems].[IsEnabled]=1 AND [myItems].[ItemChecksum]=[myItems].[SubscriberItemChecksum]"
[string]$myConnectionString = "Data Source= $(ESCAPE_SQUOTE(MACH)).sqldeep.local\$(ESCAPE_SQUOTE(INST)),1433;Integrated Security=True;Initial Catalog=SqlDeep;Encrypt=yes"

#-----------Dont touch bellow scripts
$myFileQueryList = @{}
if ("$(ESCAPE_SQUOTE(INST))" -eq "MSSQLSERVER") {$myConnectionString=$myConnectionString.Replace("\MSSQLSERVER","")}

Function ExecuteSql
{
    [CmdletBinding()]
    [Alias()]
    Param
    (    
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$false, Position=0)]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$false, Position=1)]
        [string]$CommandText,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$false, Position=2)]
		[ValidateSet(''NonQuery'' ,''Scalar'', ''Binary'' ,''DataSet'')]
        [string]$CommandType,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=3)]
        [string]$DestinationFilePath
    )

    Begin
    {
        if($CommandType -notin (''NonQuery'' ,''Scalar'' ,''Binary'' ,''DataSet'') )
        {
            throw ''The ''''$CommandType'''' parameter contains an invalid value Valid values are: ''''NonQuery'''' ,''''Scalar'''' ,''''Binary'''' ,''''DataSet'''''';
        }

        try
        {
            $mySqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString);
            $mySqlCommand = $mySqlConnection.CreateCommand();
            $mySqlConnection.Open(); 
            $mySqlCommand.CommandText = $CommandText;                      
            
            # NonQuery
            if($CommandType -eq ''NonQuery'')
            {
                $mySqlCommand.ExecuteNonQuery();
                return;
            }
            
            # Scalar
            if($CommandType -eq ''Scalar'')
            {       
                $myVal = $mySqlCommand.ExecuteScalar();
                return $myVal;
            }
            
            # DataSet
            if($CommandType -eq "DataSet")
            {
                $myDataSet = New-Object System.Data.DataSet;
                $mySqlDataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter;
                $mySqlDataAdapter.SelectCommand = $mySqlCommand;
                $mySqlDataAdapter.Fill($myDataSet);
                return $myDataSet;
            }

            # Binary
            if($CommandType -eq ''Binary'')
            {       
                $myAnswer=$true;
                $myBufferSize = 8192*8;
                # New Command and Reader
                $myReader = $mySqlCommand.ExecuteReader();
        
                # Create a byte array for the stream.
                $myOut = [array]::CreateInstance(''Byte'', $myBufferSize)

                # Looping through records
                While ($myReader.Read())
                {
                    #Create Directory if not exists and remove any Existing item
                    $myFolderPath=Split-Path $DestinationFilePath
                    IF (-not (Test-Path -Path $myFolderPath -PathType Container)) {
                        New-Item -Path $myFolderPath -ItemType Directory -Force
                        #$myDestinationFolderPath=$DestinationFilePath.Substring(0,($DestinationFilePath.Length-$DestinationFilePath.Split("\")[-1].Length))
                        #New-Item -ItemType Directory -Path $myDestinationFolderPath -Force
                    }
                    IF (Test-Path -Path $DestinationFilePath -PathType Leaf) {Move-Item -Path $DestinationFilePath -Force}
            
                    # New BinaryWriter, write content to specified file on (zero based) first column (FileContent)
                    $myFileStream = New-Object System.IO.FileStream $DestinationFilePath, Create, Write;
                    $myBinaryWriter = New-Object System.IO.BinaryWriter $myFileStream;

                    $myStart = 0;
                    # Read first byte stream from (zero based) first column (FileContent)
                    $myReceived = $myReader.GetBytes(0, $myStart, $myOut, 0, $myBufferSize - 1);
                    While ($myReceived -gt 0)
                    {
                    $myBinaryWriter.Write($myOut, 0, $myReceived);
                    $myBinaryWriter.Flush();
                    $myStart += $myReceived;
                    # Read next byte stream from (zero based) first column (FileContent)
                    $myReceived = $myReader.GetBytes(0, $myStart, $myOut, 0, $myBufferSize - 1);
                    }

                    $myBinaryWriter.Close();
                    $myFileStream.Close();
                }
                # Closing & Disposing all objects            
                if (-not (Test-Path -Path $DestinationFilePath) -or -not ($myFileStream)) {
                    $myAnswer=$false
                }
                if ($myFileStream) {$myFileStream.Dispose()};
                $myReader.Close();
                return $myAnswer
            }
        }
        catch
        {       
            Write-Error($_.ToString())
            Throw;
        }
        finally
        {
            $mySqlCommand.Dispose();
            $mySqlConnection.Close();
            $mySqlConnection.Dispose();
            #[System.Data.SqlClient.SqlConnection]::ClearAllPools();  
        }
    }
}

Function DownloadMultipleFilesFromDB
{
        Param
        (
        [Parameter(Mandatory=$true)][string]$ConnectionString,
        [Parameter(Mandatory=$true)][hashtable]$FileQueryList,
        [Parameter(Mandatory=$true)][string]$DestinationFolderPath
        )
    [bool]$myAnswer=$false;
    try{
        [int]$myRequestCount=$FileQueryList.Count
        [int]$myDownloadedCount=0
        [bool]$myDownloadResult=$false
        if ($DestinationFolderPath[-1] -ne "\") {$DestinationFolderPath+="\"}
        foreach ($myItem in $FileQueryList.GetEnumerator()) {
            [string]$myFile=$myItem.Key.ToString().Trim()
            [string]$myBlobQuery=$myItem.Value.ToString().Trim()
            $myFilePath=$DestinationFolderPath + $myFile
            If ($myFile.Length -gt 0 -and $DestinationFolderPath.Length -gt 0) {
                Write-Output ("Multiple file downloader: Downloading " + $myFilePath + " ...")
                $myDownloadResult=ExecuteSql -ConnectionString $ConnectionString -CommandText $myBlobQuery -CommandType Binary -DestinationFilePath $myFilePath
            } else {
                $myDownloadResult=$false
            }
            if ($myDownloadResult) {$myDownloadedCount+=1}
        }
        if ($myDownloadedCount -eq $myRequestCount) {$myAnswer=$true}
    } catch {
        $myAnswer=$false
        Write-Error($_.ToString())
    }
    return $myAnswer
}

try{
    $myDataset=ExecuteSql -ConnectionString $myConnectionString -CommandType DataSet -CommandText $myCommand
    if ($null -ne $myDataset) {
        foreach ($myRow in $myDataset.Tables[0].Rows){
            $myFileQueryList.Add($myRow.Item(''ItemName'').ToString(),"SELECT TOP 1 [ItemContent] FROM [SqlDeep].[repository].[Subscriber] WITH (READPAST) WHERE [SubscriberItemId]=" + $myRow.Item(''SubscriberItemId'').ToString())
        }
    }
    DownloadMultipleFilesFromDB -ConnectionString $myConnectionString -FileQueryList $myFileQueryList -DestinationFolderPath $myDestinationFolderPath
}Catch{
    Write-Output(($_.ToString()).ToString())
}
', 
		@database_name=N'master', 
		@flags=32, 
		@proxy_name=N'SqlDeepPowerShell_Proxy'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ExecuteScriptFile]    Script Date: 9/10/2024 10:00:43 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ExecuteScriptFile', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=N'PowerShell.exe -ExecutionPolicy bypass -File "U:\Install\Scripts\JobRepo\$(ESCAPE_SQUOTE(JOBID))\VAR_REPOSITORYITEMNAME" -LimitEventLogScanToRecentMinutes 5 -CurrentInstanceConnectionString "Data Source= $(ESCAPE_SQUOTE(MACH)).sqldeep.local\$(ESCAPE_SQUOTE(INST)),1433;Initial Catalog=SqlDeep;Integrated Security=True;TrustServerCertificate=True;Encrypt=True" -Verb RunAs', 
		@flags=32, 
		@proxy_name=N'SqlDeepPowerShell_Proxy'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [RemoveExportedFile]    Script Date: 9/10/2024 10:00:43 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'RemoveExportedFile', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'
#-----------User Inputs
[string]$myDestinationFolderPath="U:\Install\Scripts\JobRepo\$(ESCAPE_SQUOTE(JOBID))"

#-----------Dont touch bellow scripts

if (-not (Test-Path -Path $myDestinationFolderPath -PathType Container)) {
    throw ($myDestinationFolderPath + " is not found.")
}else{
    Remove-Item -Path $myDestinationFolderPath -Force -Recurse
}', 
		@database_name=N'master', 
		@flags=32, 
		@proxy_name=N'SqlDeepPowerShell_Proxy'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'SqlDeep.VAR_JOBNAME', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=4, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240511, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'ca2b7e2c-3556-471f-ac5b-f16d43aacc8d'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
#Global Variables/Keys for use in API Calls
$apiKey = "CHANGEME"
$userUri = "https://api.opsgenie.com/v2/users/"
$teamsUri = "https://api.opsgenie.com/v2/teams/"
$teamsParams = "?identifierType=id"
$expandParams = "?expand=contact"
$headers = @{
	"Content-Type" = "application/json"
	"Authorization" = 'GenieKey ' + $apikey
}

#Get Date for use with file names
$todaysDate = Get-Date -Format "MM-dd-yy"

#Email Variables/Parameters
$Attachments = ".\OpsgenieUnverifiedSuspendedUsers$todaysDate.csv"
$From = "CHANGEME"
$Subject = "OpsGenie - Unverified/Suspended Users - Action Required"
$Body = "Hello! <br><br> We have found that the users in the attached document are listed as UNVERIFIED or SUSPENDED/BLOCKED within Opsgenie. One or more of these accounts are in a team you are an ADMIN of. Before we can delete the user from Opsgenie we need to ensure that the accounts are removed from any TEAMS,SCHEDULES, or ESCALATIONS. Please review and remove any accounts that are not using the on-call feature or are no longer here.<br><br> Thanks! "

#Page files. This currently allows us to have 500 people. If we go over 500, then we will need to add another page URL.
$pagingUri = @('https://api.opsgenie.com/v2/users?limit=100&offset=0&order=ASC&sort=username','https://api.opsgenie.com/v2/users?limit=100&offset=100&order=ASC&sort=username','https://api.opsgenie.com/v2/users?limit=100&offset=200&order=ASC&sort=username','https://api.opsgenie.com/v2/users?limit=100&offset=300&order=ASC&sort=username','https://api.opsgenie.com/v2/users?limit=100&offset=400&order=ASC&sort=username')
$userBasicData = @()
$allTeamAdminsList = @()

 #Go through each page and pull all user data and put into variable.
 foreach($page in $pagingUri) {
 	$tempUserData = Invoke-RestMethod $page -Headers $headers
 	$userBasicData += $tempUserData.data
 }
 #Pull only the unverified OR blocked/suspended users.
 $unverifiedBlockedUsers = $userBasicData | ?{($_.blocked -match "true" -or $_.verified -match "false")} | select -expandproperty username
 
 #$MAIN Loop to get all user Data
 foreach ($u in $unverifiedBlockedUsers){
 	#Variables for Data
	$teamsList = @()
	$teamAdminsList = @()
	$schedulesList = @()
	$userCSVData = @()
 
 	#User Basic Data Start
 	$userGetRequest = Invoke-RestMethod "$userUri$u$expandParams" -Headers $headers
    $userData = $userGetRequest.data
    #User Basic Data End
    
    #User Team Data Start
    $userTeamsRequest = Invoke-RestMethod "$userUri$u/teams" -Headers $headers
    $teams = $userTeamsRequest.data
    foreach($t in $teams){
        $teamsList += $t.name
    }
    #User Team Data End
    
    #User Team Admins Start
    $userTeamsRequest = Invoke-RestMethod "$userUri$u/teams" -Headers $headers
    $teams = $userTeamsRequest.data.id
    foreach($id in $teams){
        $teamAdminsRequest = Invoke-RestMethod "$teamsUri$id$teamsParams" -Headers $headers
        $teamAdmins = $teamAdminsRequest.data
        foreach($admin in $teamAdmins.members){
            if ($admin.role -eq "admin") {
                $teamAdminsList += $admin.user.username
            }
        }
     }
     #User Team Admins Start
     
     #User Schedules Start
     $userSchedulesRequest = Invoke-RestMethod "$userUri$u/schedules" -Headers $headers
     $schedules = $userSchedulesRequest.data
     foreach($s in $schedules){
        $schedulesList += $s.name
     }
    #User Schedules End
    
    #Build All Admins List for emailing
    $allTeamAdminsList += $teamAdminsList
    
    #Use Join to make the files readable in CSV
    $teamsListJoined = $teamsList -join ","
	$teamAdminsListJoined = $teamAdminsList -join ","
	$schedulesListJoined = $schedulesList -join ","
    
    #Build CSV File
    $csvArray = [pscustomobject]@{'Full Name'=$userData.fullname;'Verified'=$userData.verified;'Teams'=$teamsListJoined;'Team Admins'=$teamAdminsListJoined;'Schedules'=$schedulesListJoined}
    $csvArray | Export-Csv $Attachments -Append
 }
 
 $uniqueTeamAdminsList = $allTeamAdminsList | select -Unique
 
 Send-MailMessage -Attachments $Attachments -To $uniqueTeamAdminsList -From $From -Subject $Subject -Body $Body -BodyAsHtml -SmtpServer CHANGEME

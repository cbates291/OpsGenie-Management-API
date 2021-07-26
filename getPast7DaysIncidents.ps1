#Custom Built API Script for pulling Incidents over the last 7 days from OpsGenie. This can be used for seeing what has happened and for reporting to managers/executives, etc.

#Global Variables/Keys for use in API Calls
$apiKey = "CHANGEME"
$incidentUri = "https://api.opsgenie.com/v1/incidents"
$userUri = "https://api.opsgenie.com/v2/users/"
$teamUri = "https://api.opsgenie.com/v2/teams/"
$servicesUri = "https://api.opsgenie.com/v1/services/"
$headers = @{
	"Content-Type" = "application/json"
	"Authorization" = 'GenieKey ' + $apikey
}

#Get Date for use with file names
$todaysDate = Get-Date -Format "MM-dd-yy"
$7DaysOldDate = (Get-Date).AddDays(-7)

#Page files. This currently allows us to have 100 incidents. If we go over 100, then we will need to add another page URL. Hopefully not as we are only looking to mainly pull those from the last 7 days.
$pagingUri = @('https://api.opsgenie.com/v1/incidents?limit=100&offset=0&order=desc')

#Email Variables/Parameters
$Attachments = ".\OpsgenieIncidentReportingLast7Days$todaysDate.csv"
$To = @("change@change.com","change@change.com")
$From = "OpsGenie@change.com"
$Subject = "OpsGenie - Last 7 Days Incidents Reporting"
$Body = "Hello! <br><br> The attached document contains all of the incidents that have been created within the past 7 days as of the runtime of this script. <br><br> Please review as needed. <br><br> Thanks! "

$incidentDataAll = @()

 foreach($page in $pagingUri) {
 	$incidentData = Invoke-RestMethod $page -Headers $headers
 	$incidentDataAll += $incidentData.data
 }
 
 
 foreach($incident in $incidentDataAll){
 	#Variables for Data
 	$finalResponders = @()
 	$finalImpactedServices = @()
 	
 	$startDate = Get-Date $incident.impactStartdate
 	#$endDate = Get-Date $incident.impactenddate
 	if($incident.impactenddate -eq $null) {
 		$endDate = "No End Date"
 		$totalDuration = "No End Date, Cannot calculate"
 	} else {
 	$endDate = Get-Date $incident.impactenddate
 	$duration = $endDate - $startDate
 	$totalDuration = $duration.ToString("dd\.hh\:mm\:ss")
 	}
 	$creationDate = Get-Date $incident.createdAt
 	
 	#Get Responders
 	$allResponders = $incident.responders
 	foreach ($responder in $allResponders) {
 		if ($responder.type -eq "team"){
 		#lookup team
 		$responderId = $responder.id
 		$team = Invoke-RestMethod "$teamUri$responderId" -Headers $headers
 		$finalResponders += $team.data.name
 		} elseif ($responder.type -eq "user"){
 		#lookup user
 		$responderId = $responder.id
 		$user = Invoke-RestMethod "$userUri$responderId" -Headers $headers
 		$finalResponders += $user.data.fullname
 		} else{
 		$finalResponders = "No Matching Responders"
 		}
 	
 	}
 	
 	#Get Impacted Services if listed
 	$allImpactedServices = $incident.impactedServices
 	foreach ($service in $allImpactedServices) {
 		if ($service -eq $null){
 			$finalImpactedServices = "No Impacted Services Listed"
 		} else {
 			$serviceData = Invoke-RestMethod "$servicesUri$service" -Headers $headers
 			$finalImpactedServices += $serviceData.data.name
 		}
 	
 	}
 	
 	$finalImpactedServicesJoined = $finalImpactedServices -join ","
 	$finalRespondersJoined = $finalResponders -join ","
 	#Build CSV File
    if($creationDate -gt $7DaysOldDate) {
    $csvArray = [pscustomobject]@{'Incident #'=$incident.tinyid;'Priority'=$incident.priority;'Incident Status'=$incident.status;'Incident Name'=$incident.message;'Incident Description'=$incident.description;'Responders'=$finalRespondersJoined;'Impacted Services'=$finalImpactedServicesJoined;'Incident Creation Date'=$creationDate;'Incident Duration'=$totalDuration;'Incident Start'=$startDate;'Incident End'=$endDate}
    $csvArray | Export-Csv $Attachments -Append
    }
 }
  
 Send-MailMessage -Attachments $Attachments -To $To -From $From -Subject $Subject -Body $Body -BodyAsHtml -SmtpServer smtp.change.com

$apiKey = "CHANGEME"
$servicesUri = "https://api.opsgenie.com/v2/services/"
$headers = @{
	"Content-Type" = "application/json"
	"Authorization" = 'GenieKey ' + $apikey
}

#Allows up to 700 services with these paging URL's
$pagingUri = @('https://api.opsgenie.com/v1/services?limit=100&sort=name&offset=0&order=desc','https://api.opsgenie.com/v1/services?limit=100&sort=name&offset=100&order=desc','https://api.opsgenie.com/v1/services?limit=100&sort=name&offset=200&order=desc','https://api.opsgenie.com/v1/services?limit=100&sort=name&offset=300&order=desc','https://api.opsgenie.com/v1/services?limit=100&sort=name&offset=400&order=desc','https://api.opsgenie.com/v1/services?limit=100&sort=name&offset=500&order=desc','https://api.opsgenie.com/v1/services?limit=100&sort=name&offset=600&order=desc')
$allServiceData = @()

foreach($page in $pagingUri) {
 	$serviceData = Invoke-RestMethod $page -Headers $headers
 	$allServiceData += $serviceData.data
 }
 
 $allServiceData | ?{$_.teamid -eq $null} | Export-Csv C:\folder\file.csv -NoTypeInformation

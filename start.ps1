param(
    [Parameter(Mandatory = $false, Position = 0)]
    [Alias("p")]
    [int]$Port = 8080,
    [Parameter(Mandatory = $false)]
    [Alias("i")]
    [int]$InterruptSeconds
)

Write-Host "Starting HTTP server on port $Port"
$httpJob = Start-Job -Name "http-server" -ScriptBlock {
    param($p)
    http-server -p $p
} -ArgumentList $Port
Write-Host "HTTP server started on port $Port (job $($httpJob.Id))"

Write-Host "Starting ngrok tunnel on port $Port"
$ngrokJob = Start-Job -Name "ngrok" -ScriptBlock {
    param($p)
    ngrok http $p
} -ArgumentList $Port
Write-Host "ngrok tunnel started on port $Port (job $($ngrokJob.Id))"

if ($InterruptSeconds) {
    Write-Host "Will stop both processes after $InterruptSeconds seconds. Press Ctrl+C to stop sooner."
} else {
    Write-Host "Press Ctrl+C to stop both processes."
}

$startTime = Get-Date
$alertSeconds = if ($InterruptSeconds -and $InterruptSeconds -lt 60) { $InterruptSeconds } else { 60 }
$alerted = $false
$popupSeconds = 5

function Show-AutoDismissAlert {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [int]$Seconds = 5
    )
    try {
        $wshell = New-Object -ComObject WScript.Shell
        # 0x0 = OK button, 0x40 = Info icon
        $null = $wshell.Popup($Message, $Seconds, "Notice", 0x40)
    } catch {
        Write-Host $Message
    }
}

try {
    while ($true) {
        Start-Sleep -Seconds 1
        $elapsed = (Get-Date) - $startTime

        if (-not $alerted -and $elapsed.TotalSeconds -ge $alertSeconds) {
            if ($alertSeconds -lt 60) {
                Write-Host "Alert: $alertSeconds seconds elapsed."
                Show-AutoDismissAlert -Message "$alertSeconds seconds elapsed." -Seconds $popupSeconds
            } else {
                Write-Host "Alert: 1 minute elapsed."
                Show-AutoDismissAlert -Message "1 minute elapsed." -Seconds $popupSeconds
            }
            $alerted = $true
        }

        if ($InterruptSeconds -and $elapsed.TotalSeconds -ge $InterruptSeconds) {
            Write-Host "Interrupt timer reached. Stopping both processes."
            break
        }

        if ($httpJob.State -ne "Running" -or $ngrokJob.State -ne "Running") {
            Write-Host "One of the processes exited. Stopping the other."
            break
        }
    }
}
finally {
    Get-Job -Id $httpJob.Id, $ngrokJob.Id -ErrorAction SilentlyContinue | Stop-Job -ErrorAction SilentlyContinue
    Get-Job -Id $httpJob.Id, $ngrokJob.Id -ErrorAction SilentlyContinue | Remove-Job -ErrorAction SilentlyContinue
    Write-Host "Done."
}

param (
    #URI to download from
	[System.URI][ValidateScript({$_.IsAbsoluteUri})]$uri       = "http://buildbot.libretro.com/nightly/windows/x86_64/RetroArch.7z",
    #Folder to download to. Should already exist.
	[string][ValidateScript({Test-Path $_ -IsValid})]$download = "F:\Games\",
    #Folder to extract to. 7Zip will create it if it does not already exist.
	[string][ValidateScript({Test-Path $_ -IsValid})]$install  = "F:\Games\RetroArch\",
    #Path to 7zip executable
	[string][ValidateScript({Test-Path $_})]$7z                = "C:\Program Files\7-Zip\7z.exe",
    #Destination filename. Will be pulled from URL if not defined.
    [string]$filename
)

#Validation!
if (-not $uri.IsAbsoluteUri) {
    throw "URI must contain an absolute HTTP address."
} elseif (-not (Test-Path $download)) {
    throw "Download folder `"$download`" does not exist."
} elseif (-not (Test-Path $install -IsValid)) {
    throw "Install path `"$install`" is not a valid local path."
} elseif (-not (Test-Path $7z)) {
    throw "7z executable not found at $7z"
} elseif (-not (([string](& $7z i)).TrimStart().StartsWith("7"))) {
    # 7z.exe's i command executes instantly and starts with an empty space, then the version information.
    # We only check as far as the 7 to avoid changes in format.
    throw "7z executable not recognized."
} else { Echo "All variables validated successfully. Time to work!" }


#Filename not defined? That's cool. We'll default it here.
if (-not $filename) {
    $filename = $uri.AbsolutePath.Split("/")[-1]
    Echo "Defaulting filename to $filename."
}
#We've validated the folder. The file will be created if it doesn't exist.
$download = (Join-Path -Path $download -ChildPath $filename)

Echo "Checking for update..."
#Request JUST the header for now, not the content.
$response=(Invoke-WebRequest $uri -Method HEAD)
if($response.StatusCode -eq 200) {
    $theirDate = Get-Date($response.Headers.'Last-Modified')
    $size = $response.Headers.'Content-Length'
    if ($theirDate) {
        Echo "Their copy is dated $theirDate"
    }
} else {
    Throw "Request to check remote date failed. HTTP status: " + $response.StatusCode + " " + $response.StatusDescription
}

if(Test-Path $download) {
    $myDate = $myDate = (Get-Date(Get-ItemPropertyValue -Path $download -Name "LastWritetime"))
    Echo "Our copy is dated $myDate."
} else {
    $myDate = Get-Date 0
    Echo "We don't seem to have a copy!"
}

#Null is less than everything.
if($myDate -lt $theirDate) {
    Echo "Grabbing new copy." 
    Invoke-WebRequest $uri -Method GET -OutFile $download
    Echo "Extracting to $install"
    & $7z x $download "-o$install" -aoa -bsp1
} else {
    Echo "We're up to date."
}


if ([Environment]::UserInteractive) {
    $message = "Done! Press any key to exit!"
    # Wait for input courtsey of Cullub on StackOverflow
    if ($psISE) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("$message")
    }
    else {
        Write-Host "$message" -ForegroundColor Yellow
        $x = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
else {
    Echo "Done!"
}
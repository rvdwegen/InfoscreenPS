function Start-MPVvideo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$source
    )

    Start-Process -FilePath mpv.exe -ArgumentList "$source --fullscreen --ontop --loop"
}

function Get-FileFromUrl {
    param(
        [Parameter(Mandatory=$true)]
        [uri]$URL,

        [ValidateScript({
            if(-Not ($_ | Test-Path) ){
                New-Item -ItemType Directory -Force -Path $_
                #throw "File or folder does not exist" 
            }
            if(-Not ($_ | Test-Path -PathType Container) ){
                throw "The Path argument must be a folder. File paths are not allowed."
            }
            return $true
        })]
        [System.IO.FileInfo]$Destination
    )
    
    Try {

        $BitsParams = @{
            Source = $URL
            Destination = ($Destination.FullName + "\" + ([uri]$url).Segments[-1])
            DisplayName = "File download in progress..."
            Description = "   "
        }
    
        If (!(Test-Path -Path $BitsParams["Destination"])) {
            Write-Host "Downloading file from $($BitsParams["source"])"
            Start-BitsTransfer @BitsParams -ErrorAction Stop
        }
        Else {
            Write-Host "File from $($BitsParams["source"]) already present on system"
        }
    
        return $BitsParams["Destination"]
    }
    Catch {
        throw $_.Exception
    }
}

# Set root Infoscreen folder
$InfoscreenFolder = "C:\Infoscreen"
If (!(Test-Path -Path $InfoscreenFolder)) {New-Item -ItemType Directory -Force -Path $InfoscreenFolder}
Set-Location -Path $InfoscreenFolder

# Get 7zip
If (!(Test-Path -Path "7zr.exe")) {
    $File7zip = Get-FileFromUrl -URL "https://www.7-zip.org/a/7zr.exe" -Destination $InfoscreenFolder
}

# Get MPV from Sourceforge and extract mpv.exe
If (!(Test-Path -Path "mpv.exe")) {
    $MPVFilename = ((Invoke-RestMethod -Uri 'https://sourceforge.net/projects/mpv-player-windows/rss?path=/64bit').link[0].split("/")[-2])
    $MPVfullurl = "https://download.sourceforge.net/mpv-player-windows/" + $MPVFilename

    $FileMPVplayer = Get-FileFromUrl -URL $MPVfullurl -Destination $InfoscreenFolder

    #Extract mpv.exe
    Set-Location -Path $InfoscreenFolder
    & .\7zr.exe e $FileMPVplayer "mpv.exe"
    Remove-Item -Path $FileMPVplayer -Force
}

# Start/loop playback and update check here
Do {

    # Check for file and update
    $pathtoshare = "\\path\to\share\file.mp4"
    if (Test-Path $pathtoshare -NewerThan (Get-ChildItem ".\Master_video.mp4").LastWriteTime) {
        Write-Host "Downloading updated video..."
        Stop-Process -Name "MPV" # Stop MPV so we can restart it with the new video
        Start-BitsTransfer -Source $pathtoshare -Destination ".\Master_video.mp4"
    }

    # Check if video is playing, if not start it
    If (!(Get-Process -Name "MPV")) {
        Start-MPVvideo -source ".\Master_video.mp4"
    }

    Clear-Host
    Write-Host "If this console is visible for longer than 5 minutes please contact your IT department"
    Write-Host "Pausing for 5 minutes untill next file update/uptime check..."
    Start-Sleep -Seconds 30

    # Do stuff untill we set $Stop to $true which isn't relevant in this script
} Until ($Stop -eq $true)

<#
Manifest Generation:
New-ModuleManifest -Path .\plexTools.psd1 -RootModule "plexTools.psm1" -ModuleVersion "1.0" -Author "jdefr42x" -PowerShellVersion "5.1"
#>
function Export-PlexPlaylists {
  $configFile = "$PSScriptRoot\config.psd1"

  if (-Not (Test-Path -Path $configFile)) {
    Write-Warning "The configuration file '$configFile' does not exist."
    break
  }

  try {
    # Load the configuration
    $data = Import-PowerShellDataFile -Path $configFile

    # Validate required fields
    if (-Not $data.ContainsKey('musicPath')) {
      Write-Warning "Missing required key: musicPath"
      break
    }
    if (-Not $data.ContainsKey('m3uPath')) {
      Write-Warning "Missing required key: m3uPath"
      break
    }
    if (-Not $data.plex -or -Not $data.plex.ContainsKey('url')) {
      Write-Warning "Missing required key: plex.url"
      break
    }
    if (-Not $data.plex.ContainsKey('token')) {
      Write-Warning "Missing required key: plex.token"
      break
    }
    if (-Not $data.plex.ContainsKey('musicPath')) {
      Write-Warning "Missing required key: plex.musicPath"
      break
    }

    # Assign variables
    $localMusicPath = $data.musicPath
    $m3uPath = $data.m3uPath
    $plexUrl = $data.plex.url
    $token = $data.plex.token
    $plexMusicPath = $data.plex.musicPath

  }
  catch {
    Write-Output "Error loading configuration: $_"
    break
  }

  $headers = @{
    "Accept"       = "application/json"
    "X-Plex-Token" = "$token"
  }

  # list plex playlists
  $uri = "$plexUrl/playlists"
  $playlistAll = (Invoke-RestMethod -Method GET -Uri $uri -Headers $headers).MediaContainer.Metadata

  foreach ($playlist in $playlistAll) {
    $playlistId = $playlist.ratingKey
    $playlistName = $playlist.title
    Write-Host "Start of processing of the $playlistName playlist."

    # list the music in the playlist
    $uri = "$plexUrl/playlists/$playlistId/items"
    $musicList = (Invoke-RestMethod -Method GET -Uri $uri -Headers $headers).MediaContainer.Metadata

    $musicFiles = @()
    foreach ($music in $musicList) {
      $musicIndex = $music.ratingKey
      $uri = "$plexUrl/library/metadata/$musicIndex"
      $response = (Invoke-RestMethod -Method GET -Uri $uri -Headers $headers).MediaContainer.Metadata
      If ([string]::IsNullOrEmpty($response.Media)) {
        $response = (Invoke-RestMethod -Method GET -Uri $uri -Headers $headers)
        $json = $response | ConvertFrom-Json -AsHashtable -Depth 20
        $filePath = $json["MediaContainer"]["Metadata"][0]["Media"][0]["Part"] | ForEach-Object { $_["file"] }
      }
      else {
        $filePath = $response.Media.Part.file
      }

      $musicFiles += $filePath
    }

    $musicFiles = $musicFiles | ForEach-Object { $_ -replace "^$plexMusicPath", "$localMusicPath" }

    # creation of the playlist in m3u format
    $outputFile = "$m3uPath\$playlistName.m3u"
    $playlistContent = "#EXTM3U`n"
    $playlistContent += ($musicFiles -join "`n")
    Set-Content -Path $outputFile -Value $playlistContent
    Write-Host "End of processing of the $playlistName playlist."
  }
}

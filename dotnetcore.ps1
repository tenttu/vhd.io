Add-Type -AssemblyName System.IO.Compression.FileSystem

function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

Write-Host "Starting .NET Core VHD Setup"

$VhdPath = $PSScriptRoot+"\dotnetcore.vhd"
If (Test-Path $VhdPath)
{
	Remove-Item $VhdPath
}
$ZipPath = $PSScriptRoot+"\dotnetcore.zip"
If (Test-Path $ZipPath)
{
	Remove-Item $ZipPath
}

$CachePath = $PSScriptRoot+"\cache"
Write-Host "Creating Cache location: $CachePath"
New-Item $CachePath -Type directory -Force | Out-Null

Write-Host "Downloading files"
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?LinkID=809126" -OutFile $CachePath"\dotnet.zip"
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?LinkID=623231" -OutFile $CachePath"\vscode.zip"
Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v2.9.2.windows.1/PortableGit-2.9.2-64-bit.7z.exe" -OutFile $CachePath"\git.7z.exe"
Invoke-WebRequest -Uri "https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe" -OutFile $CachePath"\vc_redist.x64.exe"
Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $CachePath"\nuget.exe"

$DataPath = $PSScriptRoot+"\data"
Write-Host "Creating Data location: $DataPath"
New-Item $DataPath -Type directory -Force | Out-Null

Write-Host "Writing to $VhdPath..."
New-VHD -Path $VhdPath -SizeBytes 256GB -Dynamic | Out-Null
Write-Host "Mounting VHD"
Mount-DiskImage -ImagePath $VhdPath

Write-Host "Formating VHD..."
$DiskNumber = (Get-DiskImage -ImagePath $VhdPath).Number
Initialize-Disk -Number $DiskNumber -PartitionStyle GPT
$Partition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize
$Partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel ".NET Core" -Confirm:$false
$Partition | Add-PartitionAccessPath -AccessPath $PSScriptRoot"\data"
$Partition | Set-Partition -NoDefaultDriveLetter:$false

Write-Host "Writing directory structure"
New-Item $DataPath"\dotnet" -Type directory -Force | Out-Null
New-Item $DataPath"\git" -Type directory -Force | Out-Null
New-Item $DataPath"\redist" -Type directory -Force | Out-Null
New-Item $DataPath"\vscode" -Type directory -Force | Out-Null
New-Item $DataPath"\nuget" -Type directory -Force | Out-Null

Unzip $CachePath"\dotnet.zip" $DataPath"\dotnet"
Unzip $CachePath"\vscode.zip" $DataPath"\vscode"

& "$CachePath\git.7z.exe" -y -gm2 -nr | Out-Null
Copy-Item $CachePath\"PortableGit\*" $DataPath\"git" -Recurse -Force

Copy-Item $CachePath\"vc_redist.x64.exe" $DataPath\"redist" -Force
Copy-Item $CachePath\"nuget.exe" $DataPath\"nuget" -Force

Write-Host "Copying root files"
Copy-Item $PSScriptRoot"\root\*" $DataPath -Recurse -Force

Write-Host "Dismounting VHD"
Dismount-DiskImage -ImagePath $VhdPath

Write-Host "Optimizing VHD"
Optimize-VHD -Path $VhdPath -Mode Full

Write-Host "Removing temporary paths"
Remove-Item -Recurse -Force $DataPath
Remove-Item -Recurse -Force $CachePath

Write-Host "Compressing output"
Compress-Archive $VhdPath -DestinationPath $ZipPath

Write-Host "VHD succesfully created!"
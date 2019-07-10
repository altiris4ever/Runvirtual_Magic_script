Param
(
#Edit the name of your ini file to suit your productname if you want. Scripts could be modified for several ini files for different locations/computers
	[string]$inifile = 'RunVirtual_product.ini',
	[string]$Roule = '',

# Edit this part to a share for central managment "\\share\folder\"	
	[string]$serverIni = "c:\temp\"
)


Function Get-IniContent {
    <#  
    .Synopsis  
        Gets the content of an INI file  
          
    .Description  
        Gets the content of an INI file and returns it as a hashtable  
          
    .Notes  
        Author        : Oliver Lipkau <oliver@lipkau.net>  
        Blog        : http://oliver.lipkau.net/blog/  
        Source        : https://github.com/lipkau/PsIni 
                      http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91 
        Version        : 1.0 - 2010/03/12 - Initial release  
                      1.1 - 2014/12/11 - Typo (Thx SLDR) 
                                         Typo (Thx Dave Stiff) 
          
        #Requires -Version 2.0  
          
    .Inputs  
        System.String  
          
    .Outputs  
        System.Collections.Hashtable  
          
    .Parameter FilePath  
        Specifies the path to the input file.  
          
    .Example  
        $FileContent = Get-IniContent "C:\myinifile.ini"  
        -----------  
        Description  
        Saves the content of the c:\myinifile.ini in a hashtable called $FileContent  
      
    .Example  
        $inifilepath | $FileContent = Get-IniContent  
        -----------  
        Description  
        Gets the content of the ini file passed through the pipe into a hashtable called $FileContent  
      
    .Example  
        C:\PS>$FileContent = Get-IniContent "c:\settings.ini"  
        C:\PS>$FileContent["Section"]["Key"]  
        -----------  
        Description  
        Returns the key "Key" of the section "Section" from the C:\settings.ini file  
          
    .Link  
        Out-IniFile  
    #>	
	
	[CmdletBinding()]
	Param (
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ (Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini") })]
		[Parameter(ValueFromPipeline = $True, Mandatory = $True)]
		[string]$FilePath,
		[string]$NoComment = 'N'
	)
	
	Begin { Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started" }
	
	Process {
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"
		
		$ini = @{ }
		switch -regex -file $FilePath
		{
			"^\[(.+)\]$" # Section  
			{
				$section = $matches[1]
				$ini[$section] = @{ }
				$CommentCount = 0
				$r = 0
			}
			"^(;.*)$" # Comment  
			{
				if (!($section)) {
					$section = "No-Section"
					$ini[$section] = @{ }
				}
				$value = $matches[1]
				$CommentCount = $CommentCount + 1
				$name = "Comment" + $CommentCount
				if ($NoComment -eq 'N') {
					$ini[$section][$name] = $value
				}
			}
			"(.+?)\s*=\s*(.*)" # Key  
			{
				if (!($section)) {
					$section = "No-Section"
					$ini[$section] = @{ }
				}
				if ($CommentCount -eq $r) {
					$name, $value = $matches[1 .. 2]
					$ini[$section][$name] = $value
				} else { $r = $CommentCount }
			}
		}
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath"
		Return $ini
	}
	
	End { Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended" }
}

Function Ini-TrimLeft {
	Param (
		[string]$FilePath
	)
	$a = Get-Content -Path $FilePath
	$a = $a | ForEach-Object{ $_.trim() }
	$a | Out-File -FilePath $FilePath -Encoding ascii | Out-Null
}

function Out-IniFile($InputObject, $FilePath) {
	$outFile = New-Item -ItemType file -Path $Filepath
	foreach ($i in $InputObject.keys) {
		if (!($($InputObject[$i].GetType().Name) -eq "Hashtable")) {
			#No Sections
			Add-Content -Path $outFile -Value "$i=$($InputObject[$i])"
		} else {
			#Sections
			Add-Content -Path $outFile -Value "[$i]"
			Foreach ($j in ($InputObject[$i].keys | Sort-Object)) {
				if ($j -match "^Comment[\d]+") {
					Add-Content -Path $outFile -Value "$($InputObject[$i][$j])"
				} else {
					Add-Content -Path $outFile -Value "$j=$($InputObject[$i][$j])"
				}
				
			}
			Add-Content -Path $outFile -Value ""
		}
	}
}


Function RunVirtual {
	param (
		[string]$ConnectorPackageGUID,
		[string]$ConnectorVersionGUID,
		[Array]$ApplicationExes,
		[Int]$Publish = 1
	)
	
	$AppVRegistryPath = "HKLM:\Software\Microsoft\AppV\Client"
	$RunVirtualRegistryPath = "HKLM:\Software\Microsoft\AppV\Client\RunVirtual"
	
	If ((!(Test-Path $RunVirtualRegistryPath)) -and $Publish) {
		New-Item -Path $AppVRegistryPath -Name RunVirtual –Force | Out-Null
	}
	
	ForEach ($ApplicationExe in $ApplicationExes) {
		$Appname = $ApplicationExe.split('\')[-1]
		$registryPath = $RunVirtualRegistryPath + '\' + $Appname
		
		If ($Publish -eq 1) {
			if (!(Test-Path $registryPath)) {
				New-Item -Path $registryPath -Force | Out-Null
				New-ItemProperty -Path $registryPath -Name $ApplicationExe -Value ($ConnectorPackageGUID + "_" + $ConnectorVersionGUID) -PropertyType string -Force | Out-Null
			} else {
				New-ItemProperty -Path $registryPath -Name $ApplicationExe -Value ($ConnectorPackageGUID + "_" + $ConnectorVersionGUID) -PropertyType string -Force | Out-Null
			}
		}
		
		If (($Publish -eq 0) -and (Test-Path $registryPath)) {
			$RunVirtualRegistryValue = (Get-ItemProperty -LiteralPath $registryPath).$ApplicationExe
			If ($RunVirtualRegistryValue -eq ($ConnectorPackageGUID + "_" + $ConnectorVersionGUID)) {
				Remove-ItemProperty -path $registryPath -Name $ApplicationExe | Out-Null
			}
			$a = Get-Item -Path $registryPath
			
			if (($a.SubKeyCount + $a.Property.Count) -eq 0) { Remove-Item -path $registryPath | Out-Null }
			
		}
	}
}

Function sjk-VersionIni {
	param (
		[string]$IniPath
	)
	
	if (Test-Path -Path $IniPath) {
		$ini = Get-IniContent -filePath $IniPath
		Return $ini['ini']['iniversjon']
	}
}

Function Run-VirtualFromIni {
	param (
		[Int]$Publish = 1,
		[string]$inifile,
		[string]$Roule,	
		[string]$serverIni
	)
	$wk = $PSScriptRoot
	$a = 0
	$b = 0
#Edit this part to suit your companys wanted ini file location we just use c:\company in our example
	if (!(Test-Path -Path "c:\Company\Appv")) { new-item -Path "c:\Company\Appv" -ItemType directory | Out-Null }
	$LocalIni = "c:\Company\Appv\" + $inifile
	$LocalVersjon = '0'
	
	$LocalVersjon = sjk-VersionIni -IniPath $LocalIni
	if ($LocalVersjon -ne '0') { $a = 1 }
	
	$ServerVersion = sjk-VersionIni -IniPath $serverIni
	if ($ServerVersion -ne '0') { $a += 2}
	
	switch ($a) {
		0 {
			#Verken server eller local
			$Fra = $wk + '\' + $inifile
			Copy-Item -Path $Fra -Destination $LocalIni | Out-Null
		}
		1 {
			#Bare Local
			if ($Roule.ToLower() -ne $LocalVersjon.ToLower()) {
				$Fra = $wk + '\' + $inifile
				Copy-Item -Path $Fra -Destination $LocalIni | Out-Null
			}
		}
		2 {
			#Bare server
			$Fra = $serverIni
			Copy-Item -Path $serverIni -Destination $LocalIni | Out-Null
		}
		3 {
			#Både server og Local
			if ($ServerVersion.ToLower() -ne $LocalVersjon.ToLower()) {
				Copy-Item -Path $serverIni -Destination $LocalIni | Out-Null
			}
		}
	}
	
	$Versjon = sjk-VersionIni -IniPath $LocalIni
	if ($Versjon -eq '0') {exit 16001}
	
	
	Ini-TrimLeft -filePath $LocalIni
	$ini = Get-IniContent -filePath $LocalIni
	$Versjon = $ini['ini']['iniversjon']
	$Section = @()
	$Section += $ini.keys
	for ($i = 0; $i -lt $Section.count; $i++) {
		$a = $section[$i]
		$b = Get-AppvClientPackage -Name $a
		if ($b.count -eq 1) {
			$c = $b.Packageid
			$d = $b.Versionid
			if (($a -eq 'INI') -or ($a -eq 'FORBIDDEN')) {
			} else {
				$f = @()
				$e = $Section[$i]
				$f += $ini.$e.Values
				$f = Sjk-IniValues $f
				RunVirtual -ConnectorPackageGUID $c -ConnectorVersionGUID $d -ApplicationExes $f -Publish $Publish
			}
		}
	}
	if ($ini['forbidden'].count -gt 0) {
		$h = @()
		$h += $ini['forbidden'].Values
		$RunVirtualRegistryPath = "HKLM:\Software\Microsoft\AppV\Client\RunVirtual\"
		
		for ($i = 0; $i -lt $h.count; $i++) {
			$g = $h[$i]
			$g = $g.split('\')[-1]
			$r = $RunVirtualRegistryPath + $g
			if (Test-Path $r) { Remove-Item -path $r | Out-Null }
		}
	}
#detectionrule
	set-reg -registryPath "HKLM:\Software\hnikt\RunVirtual_product" -Name 'Versjon' -Value $versjon
}

function set-Reg {
	param (
		[string]$registryPath,
		[string]$Name,
		[string]$Value
	)
	if (!(Test-Path $registryPath)) {
		New-Item -Path $registryPath -Force | Out-Null
		New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType string -Force | Out-Null
	} else {
		New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType string -Force | Out-Null
	}
}


#for ($i = 0 ;$i -lt $b.Count; $i++){$c = $b[$i] ;$d=Get-AppvClientPackage -Name $c  ;Write-host 'name:' $c 'Glo:pending:' $d.GlobalPending 'User:pending' $d.UserPending 'Inuse: ' $d.InUse 'Inuse by:' $d.InUseByCurrentUser}

function sjk-IniValues {
	Param (
		[array]$IniValues
	)
	$d = @()
	for ($i = 0; $i -lt $IniValues.count; $i++) {
		$a = $IniValues[$i]
		$b = $a.Split('\')[-1]
		switch ($b) {
			'*.exe'{
				$path = $a.substring(0, $a.length - $b.Length - 1)
				$c = Get-ChildItem -Path $path -Filter *.exe -Force -File -Name
				if ($c.Count -gt 0) {
					$c = $c | ForEach-Object{ $path + '\' + $_ }
					$d += $c
					
				}
			}
			'*.exe /s'{
				$path = $a.substring(0, $a.length - $b.Length - 1)
				$c += Get-ChildItem -Path $path -Filter *.exe -Recurse -Force -File -Name
				if ($c.Count -gt 0) {
					$c = $c | ForEach-Object{ $path + '\' + $_ }
					$d += $c
					
				}
			}
			default { $d += $a }
		}
	}
	Return $d
}

$serverIni = $serverIni + $inifile
Run-VirtualFromIni -ini $inifile -serverIni $serverIni        

#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests. 
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")

Set-Location $here
Import-Module "$here\LabBuilder.psd1" -Force
$TestConfigPath = "$here\Tests\PesterTestConfig"
$TestConfigOKPath = "$TestConfigPath\PesterTestConfig.OK.xml"

##########################################################################################################################################
Describe "Get-LabConfiguration" {
	Context "No parameters passed" {
		It "Fails" {
			{ Get-LabConfiguration } | Should Throw
		}
	}
	Context "Path is provided but file does not exist" {
		It "Fails" {
			{ Get-LabConfiguration -Path 'c:\doesntexist.xml' } | Should Throw
		}
	}
	Context "Path is provided and valid XML file exists" {
		It "Returns XmlDocument object with valid content" {
			$Config = Get-LabConfiguration -Path $TestConfigOKPath
			$Config.GetType().Name | Should Be 'XmlDocument'
			$Config.labbuilderconfig | Should Not Be $null
		}
	}
	Context "Content is provided but is empty" {
		It "Fails" {
			{ Get-LabConfiguration -Content '' } | Should Throw
		}
	}
	Context "Content is provided and contains valid XML" {
		It "Returns XmlDocument object with valid content" {
			$Config = Get-LabConfiguration -Content (Get-Content -Path $TestConfigOKPath -Raw)
			$Config.GetType().Name | Should Be 'XmlDocument'
			$Config.labbuilderconfig | Should Not Be $null
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Test-LabConfiguration" {

	Context "No parameters passed" {
		It "Fails" {
			{ Test-LabConfiguration } | Should Throw
		}
	}

	$Config = Get-LabConfiguration -Path $TestConfigOKPath

	Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue

	Context "Valid Configuration is provided and VMPath folder does not exist" {
		It "Fails" {
			{ Test-LabConfiguration -Configuration $Config } | Should Throw
		}
	}
	
	New-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -ItemType Directory

	Context "Valid Configuration is provided and VHDParentPath folder does not exist" {
		It "Fails" {
			{ Test-LabConfiguration -Configuration $Config } | Should Throw
		}
	}
	
	New-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath -ItemType Directory

	Context "Valid Configuration is provided and all paths exist" {
		It "Returns True" {
			Test-LabConfiguration -Configuration $Config | Should Be $True
		}
	}
	Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Install-LabHyperV" {

	Context "No parameters passed" {
		It "Fails" {
			{ Install-LabHyperV } | Should Throw
		}
	}
	Context "The function exists" {
		$Config = Get-LabConfiguration -Path $TestConfigOKPath
		If ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
			Mock Get-WindowsOptionalFeature { [PSCustomObject]@{ Name = 'Dummy'; State = 'Enabled'; } }
		} Else {
			Mock Get-WindowsFeature { [PSCustomObject]@{ Name = 'Dummy'; Installed = $false; } }
		}		
		It "Returns True" {
			Install-LabHyperV | Should Be $True
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabHyperV" {
	Context "No parameters passed" {
		It "Fails" {
			{ Initialize-LabHyperV } | Should Throw
		}
	}
	Context "Valid configuration is passed" {
		$Config = Get-LabConfiguration -Path $TestConfigOKPath
	
		$CurrentMacAddressMinimum = (Get-VMHost).MacAddressMinimum
		$CurrentMacAddressMaximum = (Get-VMHost).MacAddressMaximum
		Set-VMHost -MacAddressMinimum '001000000000' -MacAddressMaximum '0010000000FF'

		It "Returns True" {
			Initialize-LabHyperV -Configuration $Config | Should Be $True
		}
		It "MacAddressMinumum should be $($Config.labbuilderconfig.SelectNodes('settings').macaddressminimum)" {
			(Get-VMHost).MacAddressMinimum | Should Be $Config.labbuilderconfig.SelectNodes('settings').macaddressminimum
		}
		It "MacAddressMaximum should be $($Config.labbuilderconfig.SelectNodes('settings').macaddressmaximum)" {
			(Get-VMHost).MacAddressMaximum | Should Be $Config.labbuilderconfig.SelectNodes('settings').macaddressmaximum
		}
		
		Set-VMHost -MacAddressMinimum $CurrentMacAddressMinimum -MacAddressMaximum $CurrentMacAddressMaximum
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabDSC" {

	Context "No parameters passed" {
		It "Fails" {
			{ Initialize-LabDSC } | Should Throw
		}
	}
	Context "Valid configuration is passed" {
		$Config = Get-LabConfiguration -Path $TestConfigOKPath

		It "Returns True" {
			Initialize-LabDSC -Configuration $Config | Should Be $True
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Get-LabSwitches" {
	Context "No parameters passed" {
		It "Fails" {
			{ Get-LabConfiguration } | Should Throw
		}
	}
	Context "Configuration passed with switch missing Switch Name." {
		It "Fails" {
			{ Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.SwitchFail.NoName.xml") } | Should Throw
		}
	}
	Context "Configuration passed with switch missing Switch Type." {
		It "Fails" {
			{ Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.SwitchFail.NoType.xml") } | Should Throw
		}
	}
	Context "Configuration passed with switch invalid Switch Type." {
		It "Fails" {
			{ Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.SwitchFail.BadType.xml") } | Should Throw
		}
	}
	Context "Configuration passed with switch containing adapters but is not External type." {
		It "Fails" {
			{ Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.SwitchFail.AdaptersSet.xml") } | Should Throw
		}
	}
	Context "Valid configuration is passed" {
		$Config = Get-LabConfiguration -Path $TestConfigOKPath
		$Switches = Get-LabSwitches -Configuration $Config
		# Set-Content -Path "$($ENV:Temp)\Switches.json" -Value ($Switches | ConvertTo-Json -Depth 4)
		
		It "Returns Switches Object that matches Expected Object" {
			$ExpectedSwitches = [string] @"
[
    {
        "vlan":  null,
        "name":  "Pester Test External",
        "adapters":  [
                         {
                             "name":  "Cluster",
                             "macaddress":  "00155D010701"
                         },
                         {
                             "name":  "Management",
                             "macaddress":  "00155D010702"
                         },
                         {
                             "name":  "SMB",
                             "macaddress":  "00155D010703"
                         },
                         {
                             "name":  "LM",
                             "macaddress":  "00155D010704"
                         }
                     ],
        "type":  "External"
    },
    {
        "vlan":  "2",
        "name":  "Pester Test Private Vlan",
        "adapters":  null,
        "type":  "Private"
    },
    {
        "vlan":  null,
        "name":  "Pester Test Private",
        "adapters":  null,
        "type":  "Private"
    },
    {
        "vlan":  "3",
        "name":  "Pester Test Internal Vlan",
        "adapters":  null,
        "type":  "Internal"
    },
    {
        "vlan":  null,
        "name":  "Pester Test Internal",
        "adapters":  null,
        "type":  "Internal"
    }
]
"@
			[String]::Compare(($Switches | ConvertTo-Json -Depth 4),$ExpectedSwitches,$true) | Should Be 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabSwitches" {

	Context "No parameters passed" {
		It "Fails" {
			{ Initialize-LabSwitches } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $TestConfigOKPath
		$Switches = Get-LabSwitches -Configuration $Config

		Get-VMSwitch -Name  Pester* | Remove-VMSwitch

		It "Returns True" {
			Initialize-LabSwitches -Configuration $Config -Switches $Switches | Should Be $True
		}
		It "Creates 2 Pester Internal Switches" {
			(Get-VMSwitch -Name Pester* | Where-Object -Property SwitchType -EQ Internal).Count | Should Be 2
		}
		It "Creates 2 Pester Private Switches" {
			(Get-VMSwitch -Name Pester* | Where-Object -Property SwitchType -EQ Private).Count | Should Be 2
		}

		Get-VMSwitch -Name  Pester* | Remove-VMSwitch
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Remove-LabSwitches" {
	Context "No parameters passed" {
		It "Fails" {
			{ Remove-LabSwitches } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $TestConfigOKPath
		$Switches = Get-LabSwitches -Configuration $Config
		New-VMSwitch -Name "Pester Test Private Vlan" -SwitchType "Private"
		New-VMSwitch -Name "Pester Test Private" -SwitchType "Private"
		New-VMSwitch -Name "Pester Test Internal Vlan" -SwitchType "Internal"
		New-VMSwitch -Name "Pester Test Internal" -SwitchType "Internal"

		It "Returns True" {
			Remove-LabSwitches -Configuration $Config -Switches $Switches | Should Be $True
		}
		It "Removes All Pester Switches" {
			(Get-VMSwitch -Name Pester*).Count | Should Be 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Get-LabVMTemplates" {
	Context "No parameters passed" {
		It "Fails" {
			{ Get-LabVMTemplates } | Should Throw
		}
	}
	Context "Configuration passed with template missing Template Name." {
		It "Fails" {
			{ Get-LabVMTemplates -Configuration (Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.TemplateFail.NoName.xml") } | Should Throw
		}
	}
	Context "Configuration passed with template missing VHD Path." {
		It "Fails" {
			{ Get-LabVMTemplates -Configuration (Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.TemplateFail.NoVHD.xml") } | Should Throw
		}
	}
	Context "Configuration passed with template with Source VHD set to non-existent file." {
		It "Fails" {
			{ Get-LabVMTemplates -Configuration (Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.TemplateFail.BadSourceVHD.xml") } | Should Throw
		}
	}
	Context "Valid configuration is passed" {
		$Config = Get-LabConfiguration -Path $TestConfigOKPath
		$Templates = Get-LabVMTemplates -Configuration $Config 
		# Set-Content -Path "$($ENV:Temp)\VMTemplates.json" -Value ($Templates | ConvertTo-Json -Depth 2)
		It "Returns Template Object that matches Expected Object" {
		$ExpectedTemplates = [string] @"
[
    {
        "vhd":  "Windows Server 2012 R2 Datacenter Full.vhdx",
        "name":  "Pester Windows Server 2012 R2 Datacenter Full",
        "templatevhd":  "C:\\Pester Lab\\Virtual Hard Disk Templates\\Windows Server 2012 R2 Datacenter Full.vhdx",
        "installiso":  ".\\Tests\\PesterTestConfig\\9600.16384.130821-1623_x64fre_Server_EN-US_IRM_SSS_DV5.iso",
        "allowcreate":  "Y",
        "edition":  "Windows Server 2012 R2 SERVERDATACENTER",
        "sourcevhd":  ".\\Tests\\PesterTestConfig\\Windows Server 2012 R2 Datacenter Full.vhdx"
    },
    {
        "vhd":  "Windows Server 2012 R2 Datacenter Core.vhdx",
        "name":  "Pester Windows Server 2012 R2 Datacenter Core",
        "templatevhd":  "C:\\Pester Lab\\Virtual Hard Disk Templates\\Windows Server 2012 R2 Datacenter Core.vhdx",
        "installiso":  ".\\Tests\\PesterTestConfig\\9600.16384.130821-1623_x64fre_Server_EN-US_IRM_SSS_DV5.iso",
        "allowcreate":  "Y",
        "edition":  "Windows Server 2012 R2 SERVERDATACENTERCORE",
        "sourcevhd":  ".\\Tests\\PesterTestConfig\\Windows Server 2012 R2 Datacenter Full.vhdx"
    },
    {
        "vhd":  "Windows 10 Enterprise.vhdx",
        "name":  "Pester Windows 10 Enterprise",
        "templatevhd":  "C:\\Pester Lab\\Virtual Hard Disk Templates\\Windows 10 Enterprise.vhdx",
        "installiso":  ".\\Tests\\PesterTestConfig\\10240.16384.150709-1700.TH1_CLIENTENTERPRISE_VOL_X64FRE_EN-US.iso",
        "allowcreate":  "Y",
        "edition":  "Windows 10 Enterprise",
        "sourcevhd":  ".\\Tests\\PesterTestConfig\\Windows 10 Enterprise.vhdx"
    }
]
"@
			[String]::Compare(($Templates | ConvertTo-Json -Depth 2),$ExpectedTemplates,$true) | Should Be 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabVMTemplates" {
	Context "No parameters passed" {
		It "Fails" {
			{ Initialize-LabVMTemplates } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $TestConfigOKPath
		New-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -ItemType Directory
		New-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath -ItemType Directory
		$VMTemplates = Get-LabVMTemplates -Configuration $Config

		It "Returns True" {
			Initialize-LabVMTemplates -Configuration $Config -VMTemplates $VMTemplates | Should Be $True
		}
		It "Creates file C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Full.vhdx" {
			Test-Path "C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Full.vhdx" | Should Be $True
		}
		It "Creates file C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Core.vhdx" {
			Test-Path "C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Core.vhdx" | Should Be $True
		}
		It "Creates file C:\Pester Lab\Virtual Hard Disk Templates\Windows 10 Enterprise.vhdx" {
			Test-Path "C:\Pester Lab\Virtual Hard Disk Templates\Windows 10 Enterprise.vhdx" | Should Be $True
		}

		Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -Recurse -Force -ErrorAction SilentlyContinue
		Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Remove-LabVMTemplates" {
	Context "No parameters passed" {
		It "Fails" {
			{ Remove-LabVMTemplates } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $TestConfigOKPath
		$VMTemplates = Get-LabVMTemplates -Configuration $Config
		New-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -ItemType Directory
		New-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath -ItemType Directory
		Set-Content -Path 'C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Full.vhdx' -Value 'Dummy file'
		Set-Content -Path 'C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Core.vhdx' -Value 'Dummy file'
		Set-Content -Path 'C:\Pester Lab\Virtual Hard Disk Templates\Windows 10 Enterprise.vhdx' -Value 'Dummy file'
		
		It "Returns True" {
			Remove-LabVMTemplates -Configuration $Config -VMTemplates $VMTemplates | Should Be $True
		}
		It "Removes file C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Full.vhdx" {
			Test-Path "C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Full.vhdx" | Should Be $False
		}
		It "Removes file C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Core.vhdx" {
			Test-Path "C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Core.vhdx" | Should Be $False
		}
		It "Removes file C:\Pester Lab\Virtual Hard Disk Templates\Windows 10 Enterprise.vhdx" {
			Test-Path "C:\Pester Lab\Virtual Hard Disk Templates\Windows 10 Enterprise.vhdx" | Should Be $False
		}

		Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -Recurse -Force -ErrorAction SilentlyContinue
		Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Get-LabVMs" {

	Context "No parameters passed" {
		It "Fails" {
			{ Get-LabVMs } | Should Throw
		}
	}
	Context "Configuration passed with VM missing VM Name." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.VMFail.NoName.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM missing Template." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.VMFail.NoTemplate.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM invalid Template." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.VMFail.BadTemplate.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM missing adapter name." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.VMFail.NoAdapterName.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM missing adapter switch name." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.VMFail.NoAdapterSwitch.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM invalid adapter switch name." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.VMFail.BadAdapterSwitch.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM unattend file that can't be found." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$TestConfigPath\PesterTestConfig.VMFail.BadUnattendFile.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Valid configuration is passed" {
		$Config = Get-LabConfiguration -Path $TestConfigOKPath
		$Switches = Get-LabSwitches -Configuration $Config
		$VMTemplates = Get-LabVMTemplates -Configuration $Config
		$VMs = Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches
		# Set-Content -Path "$($ENV:Temp)\VMs.json" -Value ($VMs | ConvertTo-Json -Depth 4)
		It "Returns Template Object that matches Expected Object" {
			$ExpectedVMs = [String] @"
{
    "UseDifferencingDisk":  "Y",
    "TimeZone":  "Pacific Standard Time",
    "ProcessorCount":  "1",
    "ProductKey":  "AAAAA-AAAAA-AAAAA-AAAAA-AAAAA",
    "Template":  "Pester Windows Server 2012 R2 Datacenter Full",
    "MemoryStartupBytes":  536870912,
    "Adapters":  [
                     {
                         "SwitchName":  "Pester Test Private Vlan",
                         "VLan":  "2",
                         "Name":  "Pester Test Private Vlan",
                         "MACAddress":  "00155D010801"
                     },
                     {
                         "SwitchName":  "Pester Test Internal Vlan",
                         "VLan":  "3",
                         "Name":  "Pester Test Internal Vlan",
                         "MACAddress":  "00155D010802"
                     },
                     {
                         "SwitchName":  "Pester Test Private",
                         "VLan":  "3",
                         "Name":  "Pester Test Private",
                         "MACAddress":  "00155D010803"
                     },
                     {
                         "SwitchName":  "Pester Test Internal",
                         "VLan":  "4",
                         "Name":  "Pester Test Internal",
                         "MACAddress":  "00155D010804"
                     }
                 ],
    "Name":  "PESTER.VM1",
    "UnattendFile":  "",
    "TemplateVHD":  "C:\\Pester Lab\\Virtual Hard Disk Templates\\Windows Server 2012 R2 Datacenter Full.vhdx",
    "AdministratorPassword":  "None",
    "DataVHDSize":  10737418240
}
"@
			[String]::Compare(($VMs | ConvertTo-Json -Depth 4),$ExpectedVMs,$true) | Should Be 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabVMs" {

	Context "No parameters passed" {
		It "Fails" {
			{ Initialize-LabVMs } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $TestConfigOKPath
		New-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -ItemType Directory
		New-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath -ItemType Directory

		Set-Content -Path 'C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Full.vhdx' -Value 'Dummy file'
		Set-Content -Path 'C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Core.vhdx' -Value 'Dummy file'
		Set-Content -Path 'C:\Pester Lab\Virtual Hard Disk Templates\Windows 10 Enterprise.vhdx' -Value 'Dummy file'

		$Templates = Get-LabVMTemplates -Configuration $Config
		Initialize-LabVMTemplates -Configuration $Config -VMTemplates $Templates
		$Switches = Get-LabSwitches -Configuration $Config
		Initialize-LabSwitches -Configuration $Config -Switches $Switches
		$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
				
		It "Returns True" {
			Initialize-LabVMs -Configuration $Config -VMs $VMs | Should Be $True
		}

		Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -Recurse -Force -ErrorAction SilentlyContinue
		Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Remove-LabVMs" {
	Context "No parameters passed" {
		It "Fails" {
			{ Remove-LabVMs } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $TestConfigOKPath
		$Templates = Get-LabVMTemplates -Configuration $Config
		$Switches = Get-LabSwitches -Configuration $Config
		$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches

		# Create the dummy VM's that the Remove-LabVMs function 
		New-VM -Name 'PESTER.VM1'
		It "Returns True" {
			Remove-LabVMs -Configuration $Config -VMs $VMs | Should Be $True
		}
		It "Removes the VM PESTER.VM1" {
			(Get-VM -Name 'PESTER.VM1').Count | Should Be 0
		}
		Remove-VM -Name PESTER.* -Confirm:$true
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Wait-LabVMStart" {
	Context "No parameters passed" {
		It "Fails" {
			{ Wait-LabVMStart } | Should Throw
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Wait-LabVMOff" {
	Context "No parameters passed" {
		It "Fails" {
			{ Wait-LabVMOff } | Should Throw
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Set-LabVMInitializationFiles" {
	Context "No parameters passed" {
		It "Fails" {
			{ Set-LabVMInitializationFiles } | Should Throw
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Set-LabVMInitalDSCPushMode" {
	Context "No parameters passed" {
		It "Fails" {
			{ Set-LabVMInitalDSCPushMode } | Should Throw
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Install-Lab" {
	Context "No parameters passed" {
		It "Fails" {
			{ Install-Lab } | Should Throw
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Uninstall-Lab" {
	Context "No parameters passed" {
		It "Fails" {
			{ Uninstall-Lab } | Should Throw
		}
	}
}
##########################################################################################################################################
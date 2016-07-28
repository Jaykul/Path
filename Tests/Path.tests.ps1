function Get-Path {
   param(
      [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
      [Alias("PSPath")][String[]]
      [Path()]
      $Path
   )
   process { $Path }
}

function Get-DrivePath {
   param(
      [Parameter(Mandatory=$true,ParameterSetName="Resolved",Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
      [String[]][Path(ResolveAs="Drive")]
      [Alias("PSPath")]$Path
   )
   process { $Path }
}

function ConvertTo-ProviderPath {
   param(
      [Parameter(Mandatory=$true,ParameterSetName="Resolved",Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
      [String[]][Path(ResolveAs="Provider")]
      [Alias("PSPath")]$Path
   )
   process { $Path }
}

function ConvertTo-RelativePath {
   param(
      [Parameter(Mandatory=$true,ParameterSetName="Resolved",Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
      [String[]][Path(ResolveAs="Relative")]
      [Alias("PSPath")]$Path
   )
   process { $Path }
}


function Copy-WhatIf {
   param(
      [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
      [Alias("PSPath")][String[]]
      [Path()]
      $Source,

      [Parameter(Position=1,Mandatory=$true)]
      [String]
      [Path()]
      $Destination
   )
   process { 
      if(!(Test-Path $Destination)) {
         mkdir $Destination -whatif
      }
      Copy-Item $Source $Destination -whatif
   }
}   


Push-Location | out-null

Describe "Non-Existent Paths" {
   Set-Location C:\Users

   It "Allows paths that don't exist" {
      # Note: Get-Path doesn't require the path to actually EXIST!
      # Paths without folders should be treated as relative, obviously
      Get-Path C:\NotAUser       | Should Be "C:\NotAUser"
      Get-Path C:\users\NotAUser | Should Be "C:\users\NotAUser"
   }

   It "Allows relative paths that don't exist" {
      Get-Path C:NotAUser        | Should Be "C:\users\NotAUser" 
      Get-Path NotAUser          | Should Be "C:\users\NotAUser" 
   }

   It "Can provider-qualify paths that don't exist" {
      ConvertTo-ProviderPath C:\NotAUser       | Should Be "FileSystem::C:\NotAUser"      
      ConvertTo-ProviderPath C:\users\NotAUser | Should Be "FileSystem::C:\users\NotAUser"
   }

   It "Can provider-qualify relative paths that don't exist" {
      ConvertTo-ProviderPath C:NotAUser        | Should Be "FileSystem::C:\users\NotAUser"
      ConvertTo-ProviderPath NotAUser          | Should Be "FileSystem::C:\users\NotAUser"
   }

   It "Can convert paths to relative scope even when they don't exist" {
      ConvertTo-RelativePath C:\NotAUser       | Should Be "..\NotAUser"
      ConvertTo-RelativePath C:\users\NotAUser | Should Be ".\NotAUser"
      ConvertTo-RelativePath C:NotAUser        | Should Be ".\NotAUser"
      ConvertTo-RelativePath NotAUser          | Should Be ".\NotAUser"
   }
}

Describe "Existing FileSystem Paths" {
   # Convert-Path REQUIRES the path to exist
   # Get-Path should behave the same as Convert-Path, as long as the paths exist

   It "Should work just like Convert-Path for paths that exist" {
      get-path Public | Should Be $(convert-path Public)
      get-path C:\users\Public | Should Be $(convert-path C:\users\Public)
      get-path C:Public | Should Be $(convert-path C:Public)
   }

   It "Should support wildcards (just like Convert-Path)" {
      # Including supporting wildcards:
      get-path Public\* | Should Be $(convert-path Public\*)
      get-path C:\*\Public | Should Be $(convert-path C:\*\Public)
      get-path C:*\Documents | Should Be $(convert-path C:*\Documents)
   }

   It "Should work with arrays the same way that Convert-Path does" {
      # Make sure collections work
      get-path C:\Users\*\Documents, C:\Users\*\Desktop | Should Be $(convert-path C:\Users\*\Documents, C:\Users\*\Desktop)
   }

   It "Should support relative paths just like Resolve-Path -Relative" {
      ConvertTo-RelativePath Public | Should Be $(Resolve-Path Public -Relative)
      ConvertTo-RelativePath C:\users\Public | Should Be $(Resolve-Path C:\users\Public -Relative)
      ConvertTo-RelativePath C:Public | Should Be $(Resolve-Path C:Public -Relative)
   }

   It "Should support relative paths with wildcards just like Resolve-Path -Relative" {               
      ConvertTo-RelativePath Public\* | Should Be $(Resolve-Path Public\* -Relative)
      ConvertTo-RelativePath C:\*\Public | Should Be $(Resolve-Path C:\*\Public -Relative)
   }

   It "Should throw useful errors when paths with wildcards don't exist" {
      # The attribute will not work on paths that have wildcards and can't be resolved
      &{ try { get-path C:*\NoSuchFolder } catch { throw } } | Should throw "Cannot bind argument to parameter 'Path'"
   }

}

Describe "Other providers should work too" {

   Context "While in the Registry provider" {
      cd hklm:\software\microsoft | out-null

      It "Should still be able to resolve FileSystem paths" {
         ConvertTo-ProviderPath C:\Test       | Should Be "FileSystem::C:\Test"
         ConvertTo-ProviderPath C:\users\Test | Should Be "FileSystem::C:\users\Test"
         ConvertTo-ProviderPath C:Test        | Should Be "FileSystem::C:\users\Test"
      }
   
      It "Should produce the same output as Convert-Path" {
         get-path Windows | Should Be $(convert-path Windows) 
         get-path hklm:\software\microsoft | Should Be $(convert-path hklm:\software\microsoft) 
         get-path hklm:Windows | Should Be $(convert-path hklm:Windows) 
      }

      It "Should be the native provider syntax" {
         ## Nothing will normally convince other providers to include a drive name
         get-path hklm:\software\microsoft | Should Be "HKEY_LOCAL_MACHINE\software\microsoft" 
         get-path Windows | Should Be "HKEY_LOCAL_MACHINE\software\microsoft\Windows" 
         get-path hklm:Windows | Should Be "HKEY_LOCAL_MACHINE\software\microsoft\Windows" 
      }

      It "Should be able to produce drive qualified paths, when possible" {
         ## Nothing will normally convince other providers to include a drive name
         get-DrivePath hklm:\software\microsoft | Should Be "HKLM:\software\microsoft" 
         get-DrivePath Windows | Should Be "HKLM:\software\microsoft\Windows" 
         get-DrivePath hklm:Windows | Should Be "HKLM:\software\microsoft\Windows" 
      }

      It "Should be able to produce relative paths" {
         ConvertTo-RelativePath hklm:\software\microsoft | Should Be ".\"
         ConvertTo-RelativePath Windows | Should Be ".\Windows"
         ConvertTo-RelativePath hklm:Windows | Should Be ".\Windows"
         ConvertTo-RelativePath hklm:\SOFTWARE\Classes | Should Be "..\Classes"
         ConvertTo-RelativePath hklm:\SYSTEM\CurrentControlSet | Should Be "..\..\SYSTEM\CurrentControlSet"
         ConvertTo-RelativePath hkcu:\Network | Should Be "HKEY_CURRENT_USER\Network"
      }

      It "Should be able to produce provider-qualified paths" {
         ConvertTo-ProviderPath Test | Should Be "Registry::HKEY_LOCAL_MACHINE\software\microsoft\Test"
      }
   }

   Context "While in the Variable provider" {
      cd variable: | out-null

      It "Should able to handle drive-qualified paths for other providers" {
         ConvertTo-ProviderPath Test            | Should Be "Variable::Test"
         ConvertTo-ProviderPath env:\Test       | Should Be "Environment::Test"
         ConvertTo-ProviderPath C:\NoSuchFolder | Should Be "FileSystem::C:\NoSuchFolder"
      }
   }

   Context "While in the Environment provider" {
      cd env: | out-null
      It "Should able to handle drive-qualified paths for other providers" {
         ConvertTo-ProviderPath variable:\Test  | Should Be "Variable::Test"
         ConvertTo-ProviderPath Test            | Should Be "Environment::Test"
         ConvertTo-ProviderPath C:\NoSuchFolder | Should Be "FileSystem::C:\NoSuchFolder"
      }
   }

}

Pop-Location
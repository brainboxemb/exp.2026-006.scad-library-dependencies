$ErrorActionPreference = "Stop"
$Root = (& git rev-parse --show-toplevel).Trim()
Set-Location $Root
$ExpectedRootTool = "9879da589101f41b2b0e634d196ddcc51e1a6102"
$ExpectedScadTool = "8ea81a0c3483770bedda75ccf80fb72797097c0a"
$ExpectedLibraryGitTool = "7c43f37e7b07cfb57638a1d1dad2501de09ba7eb"
$ExpectedLibraryScadTool = "78e26949c6f2397ed90bb7888c1386d3dd423312"
$ExpectedMechint = "bdd39925f2ad391b32fad7ba56770053d4d5e2bc"
$ExpectedUtil = "5c88cd9b6b118d376825927ed67e26aff6eaee2d"
$ExpectedProjectUtil = "da1892a201c3bfc78a65e10df84d4a8d142ae8f6"
$Mechint = "dsg/openscad/ext/lib.scad.mechint"
$Util = "$Mechint/ext/lib.scad.util"
$ProjectUtil = "dsg/openscad/ext/lib.scad.util"
function Assert-Head { param([string] $Path,[string] $Expected); $Actual=(& git -C $Path rev-parse HEAD).Trim(); if($Actual -ne $Expected){ throw "Unexpected HEAD for ${Path}: $Actual (expected $Expected)" } }
function Assert-Uninitialized { param([string] $Owner,[string] $Path,[string] $Expected); $Status=((& git -C $Owner submodule status -- $Path)-join [Environment]::NewLine).TrimEnd(); if(-not($Status.StartsWith("-$Expected ") -or $Status -eq "-$Expected")){ throw "Expected $Owner/$Path to remain uninitialized; got: $Status" } }
Assert-Head "tools/tool.git-project" $ExpectedRootTool
Assert-Head "tools/tool.scad-project" $ExpectedScadTool
Assert-Head $Mechint $ExpectedMechint
Assert-Head $Util $ExpectedUtil
Assert-Head $ProjectUtil $ExpectedProjectUtil
foreach($Owner in @($Mechint,$Util,$ProjectUtil)){ Assert-Uninitialized $Owner "tools/tool.git-project" $ExpectedLibraryGitTool; Assert-Uninitialized $Owner "tools/tool.scad-project" $ExpectedLibraryScadTool }

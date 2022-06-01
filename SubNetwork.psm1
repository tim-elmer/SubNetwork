using namespace System.Net

<#
.SYNOPSIS
Gets an IP address (or mask) from multiple formats.

.PARAMETER Address
The IP address, as a well-formatted string, byte array, or IPAddress object.

.OUTPUTS
An IPAddress object.
#>
function Get-IpAddressFromMultiAddress {
    [OutputType([ipaddress])]
    param (
        [Parameter(Mandatory)]
        $Address
    )

    if (-not $Address -is [ipaddress] -or ($Address -is [byte[]] -and $Address.Length -ne 4)) {
        throw "Invalid Address '$Address'."
    }
    
    [ipaddress] $_address = [ipaddress]::None
    if ($Address -is [string]) {
        if ([ipaddress]::TryParse($Address, [ref] $_address)) {
            return $_address
        }
        else {
            throw "Invalid Address '$Address'."
        }
    }
    if ($Address -is [byte[]]) {
        return [ipaddress]::new($Address)
    }

    return $Address
}

<#
.SYNOPSIS
Gets information about a sub-network.

.PARAMETER Address
The IP address of the sub-network or an IP address within the sub-network.

.PARAMETER Bits
The number of network bits defining the sub-network.

.PARAMETER Mask
The sub-network mask.

.OUTPUTS
An anonymous object where Address, Mask, and MaskBits represent the network address, network mask, and network mask bits respectively.
#>
function Get-SubNetwork {
    [OutputType([PSCustomObject])]
    param (
        # The address
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Address,
        # The number of network bits
        [Parameter(ParameterSetName = "UseCidr")]
        [int] $Bits,
        # The network mask
        [Parameter(ParameterSetName = "UseMask")]
        [string] $Mask 
    )
    
    [bool] $_useMask = -not [string]::IsNullOrWhiteSpace($Mask)
    [byte[]] $_mask = $_useMask ? (Get-IpAddressFromMultiAddress -Address $Mask).GetAddressBytes() : (Get-NetworkMask -Bits $Bits -Raw)
    [ipaddress] $_address = [ipaddress]::Parse($Address)
    [hashtable] $_networkAddressArgs = $_useMask ? @{Mask = $_mask} : @{Bits = $Bits}

    Write-Output -InputObject ([PSCustomObject]@{
        Address = Get-NetworkAddress -Address $_address @_networkAddressArgs
        Mask = [ipaddress]::new($_mask).ToString()
        MaskBits = Get-NetworkBits -Mask $_mask
    })
}

<#
.SYNOPSIS
Gets the network address of a sub-network.

.PARAMETER Address
Specifies an IP address within the sub-network.

.PARAMETER Mask
Specifies the network mask.

.PARAMETER Bits
Specifies the network mask bits.

.PARAMETER Raw
If set, the network address is returned as an IPAddress object.

.OUTPUTS
string or IPAddress
The network address.
#>
function Get-NetworkAddress {
    [OutputType([ipaddress])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Address,
        [Parameter(Mandatory, ParameterSetName = "WithMask")] 
        $Mask,
        [Parameter(Mandatory, ParameterSetName = "WithCidr")]
        [int] $Bits,
        [switch] $Raw
    )

    [byte[]] $_address = (Get-IpAddressFromMultiAddress -Address $Address).GetAddressBytes()
    [byte[]] $_mask = [byte[]]::new(4)
    [byte[]] $_result = [byte[]]::new(4)
    if ($null -ne $Mask) {
        $_mask = (Get-IpAddressFromMultiAddress -Address $Mask).GetAddressBytes()
    }
    else {
        $_mask = Get-NetworkMask -Bits $Bits -Raw
    }

    for ($octet = 0; $octet -lt 4; $octet++) {
        $_result[$octet] = $_address[$octet] -band $_mask[$octet]
    }

    [ipaddress] $_out = [ipaddress]::new($_result)

    if ($Raw) {
        return $_out
    }
    Write-Output -InputObject $_out.ToString()
}

<#
.SYNOPSIS
Gets a network mask that represents a given number of network bits.

.PARAMETER Bits
The number of network bits.

.PARAMETER Raw
If set, the network mask is returned as an array of bytes.

.OUTPUTS
string or byte[]
The network mask.
#>
function Get-NetworkMask {
    param (
        # The number of network bits
        [Parameter(Mandatory, ValueFromPipeline)]
        [int] $Bits,
        [switch] $Raw
    )

    [byte[]] $_mask = [byte[]]::new(4)
        [int] $take = $Bits
        for ($i = 0; $take -gt 0; $i++) {
            [byte] $store = 0xff
            for ([int] $stored = 8; $stored -gt $take; $stored--) {
                $store = $store -shl 1
            }
            $_mask[$i] = $store
            $take -= $stored
        }

    if ($Raw) {
        return $_mask
    }
    else {
        Write-Output -InputObject ([ipaddress]::new($_mask).ToString())
    }
}

<#
.SYNOPSIS
Gets the number of network bits represented by a network mask.

.PARAMETER Mask
Specifies a network mask.

.OUTPUTS
int
The number of network bits.
#>
function Get-NetworkBits {
    [OutputType([int])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Mask
    )

    return ([System.Collections.BitArray]::new((Get-IpAddressFromMultiAddress -Address $Mask).GetAddressBytes()) | Measure-Object -Sum).Sum
}

Export-ModuleMember -Function @('Get-SubNetwork', 'Get-NetworkAddress', 'Get-NetworkMask', 'Get-NetworkBits')
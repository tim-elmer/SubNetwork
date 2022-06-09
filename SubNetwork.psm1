using namespace System.Net
using namespace System.Collections.Specialized
using module 'Modules/IpAddressBits'

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
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string] $Address,
        # The number of network bits
        [Parameter(ParameterSetName = "UseCidr", Position = 1)]
        [int] $Bits,
        # The network mask
        [Parameter(ParameterSetName = "UseMask", Position = 1)]
        [string] $Mask 
    )
    
    [bool] $_useMask = -not [string]::IsNullOrWhiteSpace($Mask)
    [IpAddressBits] $_mask = $_useMask ? [IpAddressBits]::new($Mask) : (Get-NetworkMask -Bits $Bits)
    [ipaddress] $_address = [ipaddress]::Parse($Address)
    [hashtable] $_networkAddressArgs = $_useMask ? @{Mask = $_mask} : @{Bits = $Bits}

    Write-Output -InputObject ([PSCustomObject]@{
        'Network Address' = Get-NetworkAddress -Address $_address @_networkAddressArgs
        'Broadcast Address' = Get-BroadcastAddress -Address $_address @_networkAddressArgs
        Mask = $_mask
        'Mask Bits' = Get-NetworkBits -Mask $_mask
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
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        $Address,
        [Parameter(Mandatory, ParameterSetName = "WithMask", Position = 1)] 
        $Mask,
        [Parameter(Mandatory, ParameterSetName = "WithCidr", Position = 1)]
        [int] $Bits
    )

    return [IpAddressBits]::And(
        [IpAddressBits]::new($Address),
        $null -ne $Mask ? [IpAddressBits]::new($Mask) : [IpAddressBits]::new([byte] $Bits)
    )
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
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [int] $Bits
    )

    return [IPAddressBits]::new($Bits)
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
    [OutputType([byte])]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        $Mask
    )

    return [IPAddressBits]::new($Mask).Count()
}

function Get-BroadcastAddress {
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        $Address,
        [Parameter(Mandatory, ParameterSetName = "WithMask", Position = 1)] 
        $Mask,
        [Parameter(Mandatory, ParameterSetName = "WithCidr", Position = 1)]
        [int] $Bits
    )

    [byte] $_bits = -not [string]::IsNullOrWhiteSpace($Mask) ? [IpAddressBits]::new($Mask).Count() : [byte] $Bits

    return [IpAddressBits]::Or((Get-NetworkAddress -Address $Address -Bits $_bits), [IpAddressBits]::new([UInt32]::MaxValue -shr $_bits))
}

Export-ModuleMember -Function @(
    'Get-BroadcastAddress',
    'Get-NetworkAddress',
    'Get-NetworkBits',
    'Get-NetworkMask',
    'Get-SubNetwork'
)
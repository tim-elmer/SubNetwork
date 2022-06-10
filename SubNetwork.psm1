using namespace System.Net
using namespace System.Collections.Specialized
using module 'Modules/IpAddressBits'

# Gets a mask for the host bits of a network.
function Get-HostMask {
    [OutputType([IpAddressBits])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'WithMask')]
        [IpAddressBits] $Mask,
        [Parameter(Mandatory, ParameterSetName = 'WithCidr')]
        [byte] $Bits
    )

    # Shift a full uint right the number of bits the network covers to mask the host bits
    return [IpAddressBits]::new([UInt32]::MaxValue -shr ($null -ne $Bits ? $Bits : $Mask.Count()))
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
An anonymous object where 'Network Address', 'Broadcast Address', 'Addresses Assignable', 'Network Mask', and 'Mask Bits' representing the respective properties.
#>
function Get-SubNetwork {
    [OutputType([PSCustomObject])]
    param (
        # The address
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string] $Address,
        # The number of network bits
        [Parameter(ParameterSetName = "UseCidr", Position = 1)]
        [byte] $Bits,
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
        'Addresses Assignable' = Measure-NetworkAddresses @_networkAddressArgs -Assignable
        'Network Mask' = $_mask
        'Mask Bits' = Get-NetworkBits -Mask $_mask
    })
}

<#
.SYNOPSIS
Gets the network address of a network.

.PARAMETER Address
Specifies an IP address within the network.

.PARAMETER Mask
Specifies the network mask.

.PARAMETER Bits
Specifies the network mask bits.

.OUTPUTS
IpAddressBits
The network address.
#>
function Get-NetworkAddress {
    [OutputType([IpAddressBits])]
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

.OUTPUTS
IpAddressBits
The network mask.
#>
function Get-NetworkMask {
    [OutputType([IpAddressBits])]
    param (
        # The number of network bits
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [byte] $Bits
    )

    return [IPAddressBits]::new($Bits)
}

<#
.SYNOPSIS
Gets the number of network bits represented by a network mask.

.PARAMETER Mask
Specifies a network mask.

.OUTPUTS
byte
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

<#
.SYNOPSIS
Gets the broadcast address of a network.

.PARAMETER Address
Specifies an IP address within the network.

.PARAMETER Mask
Specifies the network mask.

.PARAMETER Bits
Specifies the network mask bits.

.OUTPUTS
IpAddressBits
The broadcast address.
#>
function Get-BroadcastAddress {
    [OutputType([IpAddressBits])]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        $Address,
        [Parameter(Mandatory, ParameterSetName = "WithMask", Position = 1)] 
        $Mask,
        [Parameter(Mandatory, ParameterSetName = "WithCidr", Position = 1)]
        [int] $Bits
    )

    [hashtable] $hostMaskParam = -not [string]::IsNullOrWhiteSpace($Mask) ? @{ Mask = $Mask } : @{ Bits = $Bits}

    return [IpAddressBits]::Or((Get-NetworkAddress -Address $Address -Bits $_bits), (Get-HostMask @hostMaskParam))
}

<#
.SYNOPSIS
Gets the number of addresses in a network.

.PARAMETER Mask
Specifies the network mask.

.PARAMETER Bits
Specifies the network mask bits.

.PARAMETER Assignable
Specifies that addresses should be limited to those assignable (not network or broadcast).

.OUTPUTS
UInt32
The number of addresses within the network.
#>
function Measure-NetworkAddresses {
    [OutputType([UInt32])]
    param (
        [Parameter(Mandatory, ParameterSetName = "WithMask", Position = 0, ValueFromPipeline)] 
        $Mask,
        [Parameter(Mandatory, ParameterSetName = "WithCidr", Position = 0, ValueFromPipeline)]
        [int] $Bits,
        [switch] $Assignable
    )

    [hashtable] $hostMaskParam = -not [string]::IsNullOrWhiteSpace($Mask) ? @{ Mask = $Mask } : @{ Bits = $Bits}
    return (Get-HostMask @hostMaskParam).ToUInt32() + 1 - ($Assignable ? 2 : 0)
}

Export-ModuleMember -Function @(
    'Get-BroadcastAddress',
    'Get-NetworkAddress',
    'Get-NetworkBits',
    'Get-NetworkMask',
    'Get-SubNetwork',
    'Measure-NetworkAddresses'
)
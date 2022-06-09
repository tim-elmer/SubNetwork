using namespace System
using namespace System.Net

# Based on https://referencesource.microsoft.com/#system.web/Util/SimpleBitVector32.cs
class IpAddressBits {
    hidden static [byte] $OCTET_COUNT = 4
    hidden static [byte] $BITS = 32
    hidden static [byte] $BYTE = 8
    hidden [UInt32] $_data

    # Get the bit offset of a given byte within the backing UInt32
    hidden static [UInt32] GetOffsetForOctet([byte] $octet) {
        # The field width is set to that of a byte.
        # The octet index is subtracted from the count to invert the octet indices; as bits are indexed as little-endian, while the octets are indexed as big-endian.
        return [IpAddressBits]::BYTE * ([IpAddressBits]::OCTET_COUNT - $octet - 1)
    }

    # Get a mask that isolates a specific octet
    hidden static [UInt32] GetMaskForOctet([byte] $octet) {
        # Because the field width is a byte, we can just use a full byte as the mask, and shift it to the correct position in the backing field.
        return ([UInt32] [byte]::MaxValue -shl [IpAddressBits]::GetOffsetForOctet($octet))
    }

    # Helper for byte[] constructor
    hidden Init([byte[]] $bytes) {
        if ($null -eq $bytes) {
            throw [ArgumentNullException]::new('bytes')
        }
        if ($bytes.Length -ne [IpAddressBits]::OCTET_COUNT) {
            throw [ArgumentException]::new('Invalid number of octets.', 'bytes')
        }

        for ([byte] $i = 0; $i -lt [IpAddressBits]::OCTET_COUNT; $i++) {
            # And data with inverse mask to get all bits not set by this octet, then or with incoming data shifted to correct position to set octet bits.
            $this._data = ($this._data -band -bnot [IpAddressBits]::GetMaskForOctet($i)) -bor 
                ([UInt32] $bytes[$i] -shl [IpAddressBits]::GetOffsetForOctet($i))
        }
    }

    # Helper for IPAddress constructor
    hidden Init([ipaddress] $ipAddress) {
        $this.Init($ipAddress.GetAddressBytes())
    }

    # Construct an IP Address from the given array of four bytes.
    IpAddressBits([byte[]] $bytes) {
        $this.Init($bytes)
    }

    # Construct a Network Mask with the given number of bits.
    IpAddressBits([byte] $bits) {
        if ($bits -gt [IpAddressBits]::BITS) {
            throw [ArgumentOutOfRangeException]::new("The maximum number of bits that may be set is $([IpAddressBits]::BITS).", 'bits')
        }

        # Fill a UInt32 and slide it left until only the desired number of bits remain.
        $this._data = [UInt32]::MaxValue -shl [IpAddressBits]::BITS - $bits
    }

    # Construct an IP Address from the System.Net.IPAddress implementation.
    IpAddressBits([IPAddress] $ipAddress) {
        if ($null -eq $ipAddress) {
            throw [ArgumentNullException]::new('ipAddress')
        }
        if ($ipAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
            throw [ArgumentException]::new("Invalid address family '$($ipAddress.AddressFamily.ToString())'.")
        }

        $this.Init($ipAddress)
    }

    IpAddressBits([IPAddressBits] $ipAddress) {
        if ($null -eq $ipAddress) {
            throw [ArgumentNullException]::new('ipAddress')
        }

        $this._data = $ipAddress._data
    }

    # Construct an IP Address from a string.
    IpAddressBits([string] $string) {
        [IPAddress] $address = [IPAddress]::None

        if (-not [IPAddress]::TryParse($string, [ref] $address)) {
            throw [ArgumentException]::new("Invalid or improperly formed address '$string'.")
        }
        
        $this.Init($address)
    }

    # Construct an IP Address from an unsigned integer.
    IpAddressBits([UInt32] $bits) {
        $this._data = $bits
    }

    # Combine an IP Address and Network Mask
    static [IpAddressBits] And([IpAddressBits] $left, [IpAddressBits] $right) {
        if ($null -eq $left) {
            throw [ArgumentNullException]::new('left')
        }
        if ($null -eq $right) {
            throw [ArgumentNullException]::new('right')
        }

        return [IpAddressBits]::new($left._data -band $right._data)
    }

    static [IpAddressBits] Or([IpAddressBits] $left, [IpAddressBits] $right) {
        if ($null -eq $left) {
            throw [ArgumentNullException]::new('left')
        }
        if ($null -eq $right) {
            throw [ArgumentNullException]::new('right')
        }

        return [IpAddressBits]::new($left._data -bor $right._data)
    }

    # Count the number of set bits in an IP Address
    [byte] Count() {
        # PopCount, or "Population Count"
        return [System.Numerics.BitOperations]::PopCount($this._data)
    }

    # Get the IP Address as an array of bytes
    [byte[]] ToBytes() {
        [byte[]] $octets = [byte[]]::new(4)
        for ([byte] $i = 0; $i -lt [IpAddressBits]::OCTET_COUNT; $i++) {
            # Mask off desired octet then shift it to bottom of UInt32 to fit in a byte
            $octets[$i] = ($this._data -band [IpAddressBits]::GetMaskForOctet($i)) -shr [IpAddressBits]::GetOffsetForOctet($i)
        }
        return $octets
    }

    # Get the IP Address as the System.Net.IPAddress implementation
    [IPAddress] ToIpAddress() {
        return [IPAddress]::new($this.ToBytes())
    }

    # Get the IP Address as a string
    [string] ToString() {
        return [string]::Format('{0}.{1}.{2}.{3}', ($this.ToBytes() | ForEach-Object -Process { $PSItem.ToString() }))
    }
}
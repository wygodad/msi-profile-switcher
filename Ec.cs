using System.Management;
using System.Text;

namespace MSIProfileSwitcher;

public readonly record struct HwSnapshot(
    int CpuTemp, int GpuTemp, int CpuFan, int GpuFan, int ChargeLimit, string Firmware);

/// <summary>
/// Dostep do EC przez MSI WMI (root\wmi MSI_ACPI): Get_Data / Set_Data, bufor Package_32.
/// Bytes[0]=adres; zapis Bytes[1]=wartosc; odczyt -> wynik w Bytes[1]. Wymaga admina.
/// </summary>
public static class Ec
{
    // adresy EC (msi-ec CONF_G2_10, firmware 17S1IMS1.114)
    private const byte ADDR_CPU_TEMP = 0x68;
    private const byte ADDR_GPU_TEMP = 0x80;
    private const byte ADDR_CPU_FAN  = 0x71;
    private const byte ADDR_GPU_FAN  = 0x89;
    private const byte ADDR_CHARGE   = 0xD7;

    private static string? _firmwareCache;

    private static ManagementObject GetInstance()
    {
        using var searcher = new ManagementObjectSearcher(@"root\wmi", "SELECT * FROM MSI_ACPI");
        foreach (ManagementObject mo in searcher.Get())
            return mo;
        throw new InvalidOperationException("Interfejs MSI_ACPI WMI nie zostal znaleziony.");
    }

    private static void WriteWith(ManagementObject inst, ManagementClass pkg, byte addr, byte val)
    {
        var p = pkg.CreateInstance();
        var bytes = new byte[32];
        bytes[0] = addr;
        bytes[1] = val;
        p["Bytes"] = bytes;
        using var inParams = inst.GetMethodParameters("Set_Data");
        inParams["Data"] = p;
        inst.InvokeMethod("Set_Data", inParams, null);
    }

    private static byte ReadWith(ManagementObject inst, ManagementClass pkg, byte addr)
    {
        var p = pkg.CreateInstance();
        var bytes = new byte[32];
        bytes[0] = addr;
        p["Bytes"] = bytes;
        using var inParams = inst.GetMethodParameters("Get_Data");
        inParams["Data"] = p;
        using var outParams = inst.InvokeMethod("Get_Data", inParams, null);
        var outPkg = (ManagementBaseObject)outParams["Data"];
        return ((byte[])outPkg["Bytes"])[1];
    }

    public static void Apply(IEnumerable<(byte addr, byte val)> recipe)
    {
        using var inst = GetInstance();
        using var pkg = new ManagementClass(@"root\wmi", "Package_32", null);
        foreach (var (addr, val) in recipe)
            WriteWith(inst, pkg, addr, val);
    }

    public static ProfileId GetCurrent()
    {
        try
        {
            using var inst = GetInstance();
            using var pkg = new ManagementClass(@"root\wmi", "Package_32", null);
            if (ReadWith(inst, pkg, 0xD4) == 0x1D) return ProfileId.Silent;
            return ReadWith(inst, pkg, 0xD2) switch
            {
                0xC4 => ProfileId.Extreme,
                0xC2 => ProfileId.SuperBattery,
                _    => ProfileId.Balanced,
            };
        }
        catch { return ProfileId.Balanced; }
    }

    public static void SetChargeLimit(int percent)
    {
        if (percent < 10 || percent > 100) return;
        using var inst = GetInstance();
        using var pkg = new ManagementClass(@"root\wmi", "Package_32", null);
        WriteWith(inst, pkg, ADDR_CHARGE, (byte)(0x80 | percent));
    }

    public static HwSnapshot ReadHw()
    {
        using var inst = GetInstance();
        using var pkg = new ManagementClass(@"root\wmi", "Package_32", null);
        int cpuT = ReadWith(inst, pkg, ADDR_CPU_TEMP);
        int gpuT = ReadWith(inst, pkg, ADDR_GPU_TEMP);
        int cpuF = ReadWith(inst, pkg, ADDR_CPU_FAN);
        int gpuF = ReadWith(inst, pkg, ADDR_GPU_FAN);
        int chg  = ReadWith(inst, pkg, ADDR_CHARGE) & 0x7F;
        return new HwSnapshot(cpuT, gpuT, cpuF, gpuF, chg, ReadFirmware(inst));
    }

    private static string ReadFirmware(ManagementObject inst)
    {
        if (_firmwareCache != null) return _firmwareCache;
        try
        {
            using var outParams = inst.InvokeMethod("Get_EC", null, null);
            var pkg = (ManagementBaseObject)outParams["Data"];
            var b = (byte[])pkg["Bytes"];
            var sb = new StringBuilder();
            for (int i = 2; i < b.Length && b[i] != 0; i++)
                if (b[i] is >= 32 and < 127) sb.Append((char)b[i]);
            var s = sb.ToString();
            _firmwareCache = s.Length >= 12 ? s[..12] : s;
        }
        catch { _firmwareCache = "—"; }
        return _firmwareCache;
    }
}

namespace MSIProfileSwitcher;

public enum Tier { Tested, Experimental }

/// <summary>
/// Per-model fan-curve layout (read-only for now). Curve = N points of
/// (temperature threshold, fan speed %) stored in consecutive EC bytes, separate
/// tables for CPU (Fan 1) and GPU (Fan 2). Advanced mode value goes in FanMode.
/// Addresses differ per model; null on a DeviceProfile = no curve support.
/// </summary>
public sealed record FanCurveSpec(
    byte AdvancedModeValue,
    byte CpuTempBase, byte CpuSpeedBase,
    byte GpuTempBase, byte GpuSpeedBase,
    int Points,
    bool Verified = false);   // false = read-only preview (addresses unconfirmed on real hardware)

/// <summary>
/// Per-model EC definition: firmware match, EC addresses, per-profile recipes, and a tier.
/// Tested = verified on real hardware. Experimental = built from msi-ec's documented
/// shift/fan registers but NOT verified (the "Silent" power-cap behaviour is unconfirmed).
/// Adding a model = one entry below.
/// </summary>
public sealed class DeviceProfile
{
    public required string Name { get; init; }
    public required string[] FirmwarePrefixes { get; init; }
    public Tier Tier { get; init; } = Tier.Tested;

    // EC register addresses (defaults = G2 family / 17S1IMS1)
    public byte ShiftMode { get; init; } = 0xD2;
    public byte FanMode { get; init; } = 0xD4;
    public byte CpuTemp { get; init; } = 0x68;
    public byte GpuTemp { get; init; } = 0x80;
    public byte CpuFan { get; init; } = 0x71;
    public byte GpuFan { get; init; } = 0x89;
    public byte ChargeCtrl { get; init; } = 0xD7;

    // Fan tachometer registers (0 = unknown -> RPM not shown). RPM = RpmConst / raw.
    public byte CpuRpmAddr { get; init; }
    public byte GpuRpmAddr { get; init; }
    public byte PowerCapAddr { get; init; }   // 0 = unused; if set, Silent vs Balanced is told apart by this byte (0x00 = Silent)
    public FanCurveSpec? FanCurve { get; init; }
    public int RpmConst { get; init; } = 478000;

    public byte FanSilentValue { get; init; } = 0x1D;
    public byte ShiftTurboValue { get; init; } = 0xC4;
    public byte ShiftEcoValue { get; init; } = 0xC2;

    public required Dictionary<ProfileId, (byte addr, byte val)[]> Recipes { get; init; }

    public bool Matches(string firmware) =>
        !string.IsNullOrEmpty(firmware) &&
        FirmwarePrefixes.Any(p => firmware.StartsWith(p, StringComparison.OrdinalIgnoreCase));
}

public static class Devices
{
    // Generic recipe set from documented msi-ec shift_mode + fan_mode (+ optional super_battery).
    // Used for EXPERIMENTAL models. Note: does NOT include our tested model's undocumented
    // 0x34 power-cap co-flag — so on these models "Silent" may not cap power the same way.
    private static Dictionary<ProfileId, (byte, byte)[]> StdRecipes(byte shift, byte fan, byte? superBatt)
    {
        (byte, byte)[] R(byte shiftVal, byte fanVal, bool sbOn)
        {
            var l = new List<(byte, byte)> { (shift, shiftVal), (fan, fanVal) };
            if (superBatt is byte sb) l.Add((sb, (byte)(sbOn ? 0x0F : 0x00)));
            return l.ToArray();
        }
        return new()
        {
            [ProfileId.Silent]       = R(0xC1, 0x1D, false),   // comfort + fan silent
            [ProfileId.Balanced]     = R(0xC1, 0x0D, false),   // comfort + fan auto
            [ProfileId.Extreme]      = R(0xC4, 0x0D, false),   // turbo   + fan auto
            [ProfileId.SuperBattery] = R(0xC2, 0x0D, true),    // eco     + fan auto + super-batt
        };
    }

    // Modern-family fan-curve layout (same as the tested 17S1IMS1). Verified = false, so on these
    // experimental models the curve tab is READ-ONLY preview: users can compare it with MSI Center
    // (Extreme -> Advanced) before we ever enable writes. Never write to unconfirmed EC addresses.
    private static readonly FanCurveSpec ModernCurve =
        new(0x8D, CpuTempBase: 0x69, CpuSpeedBase: 0x72, GpuTempBase: 0x81, GpuSpeedBase: 0x8A, Points: 6, Verified: false);

    public static readonly DeviceProfile[] All =
    {
        // ---------- TESTED ----------
        new()
        {
            Name = "MSI Raider GE78HX 13V",          // 17S1IMS1 also covers Vector GP78HX 13V (same board)
            FirmwarePrefixes = new[] { "17S1IMS1" },
            Tier = Tier.Tested,
            CpuRpmAddr = 0xC9, GpuRpmAddr = 0xCB,    // verified vs MSI Center (RPM = 478000 / raw)
            PowerCapAddr = 0x34,                     // Silent (0x00) vs Balanced (0x01) — independent of fan mode

            // Fan-curve tables located via the test tool; 6 points each (read-only preview for now).
            // First point is the 0°C→0% entry; tables verified 1:1 against MSI Center (6 points each).
            FanCurve = new FanCurveSpec(0x8D, CpuTempBase: 0x69, CpuSpeedBase: 0x72, GpuTempBase: 0x81, GpuSpeedBase: 0x8A, Points: 6, Verified: true),
            Recipes = new()
            {
                [ProfileId.Silent]       = new (byte, byte)[] { (0xD2, 0xC1), (0x34, 0x00), (0xEB, 0x00), (0xD4, 0x1D) },
                [ProfileId.Balanced]     = new (byte, byte)[] { (0xD2, 0xC1), (0x34, 0x01), (0xEB, 0x00), (0xD4, 0x0D) },
                [ProfileId.Extreme]      = new (byte, byte)[] { (0xD2, 0xC4), (0x34, 0x01), (0xEB, 0x00), (0xD4, 0x0D) },
                [ProfileId.SuperBattery] = new (byte, byte)[] { (0xD2, 0xC2), (0x34, 0x01), (0xEB, 0x0F), (0xD4, 0x0D) },
            },
        },

        // ---------- EXPERIMENTAL (from msi-ec, unverified, opt-in) ----------
        // G2 family — same EC layout as the tested model (shift 0xD2 / fan 0xD4 / super-batt 0xEB)
        new() { Name = "MSI Raider GE68HX 13V",          FirmwarePrefixes = new[] { "15M2IMS1" }, Tier = Tier.Experimental, FanCurve = ModernCurve, Recipes = StdRecipes(0xD2, 0xD4, 0xEB) },
        new() { Name = "MSI GS66 Stealth",               FirmwarePrefixes = new[] { "16V1EMS1" }, Tier = Tier.Experimental, FanCurve = ModernCurve, Recipes = StdRecipes(0xD2, 0xD4, 0xEB) },
        new() { Name = "MSI Katana GF66",                FirmwarePrefixes = new[] { "1582EMS1" }, Tier = Tier.Experimental, FanCurve = ModernCurve, Recipes = StdRecipes(0xD2, 0xD4, 0xEB) },
        new() { Name = "MSI Katana GF76",                FirmwarePrefixes = new[] { "17L1EMS1" }, Tier = Tier.Experimental, FanCurve = ModernCurve, Recipes = StdRecipes(0xD2, 0xD4, 0xEB) },
        new() { Name = "MSI GE66 Raider / GP66 Leopard", FirmwarePrefixes = new[] { "1543EMS1" }, Tier = Tier.Experimental, FanCurve = ModernCurve, Recipes = StdRecipes(0xD2, 0xD4, 0xEB) },

        // Crosshair A16 HX (D7W/D8W) — community snapshot (issue #2, fw 15PLIMS1.106) confirms the
        // shift (0xD2: C1/C1/C4/C2) and fan (0xD4: 1D/0D/0D/0D) registers match the G2 recipe exactly
        // for all four scenarios. Note: 0xEB stays 00 even in Super Battery (no super-batt register here,
        // hence null), and 0x34 is constant (not a power-cap co-flag). A secondary fan bit at 0xF4
        // (2D vs 2C on Silent) is left untouched pending real-hardware verification.
        new() { Name = "MSI Crosshair A16 HX (D7W/D8W)", FirmwarePrefixes = new[] { "15PLIMS1" }, Tier = Tier.Experimental, FanCurve = ModernCurve, Recipes = StdRecipes(0xD2, 0xD4, null) },

        // G1 family — shift 0xF2 / fan 0xF4 / charge 0xEF, no super-battery register
        new() { Name = "MSI GS65 Stealth", FirmwarePrefixes = new[] { "16Q4EMS1" }, Tier = Tier.Experimental,
                ShiftMode = 0xF2, FanMode = 0xF4, ChargeCtrl = 0xEF, Recipes = StdRecipes(0xF2, 0xF4, null) },
        new() { Name = "MSI GF65 Thin",    FirmwarePrefixes = new[] { "16W2EMS1" }, Tier = Tier.Experimental,
                ShiftMode = 0xF2, FanMode = 0xF4, ChargeCtrl = 0xEF, Recipes = StdRecipes(0xF2, 0xF4, null) },
    };

    public static DeviceProfile? Detect(string firmware) =>
        All.FirstOrDefault(d => d.Matches(firmware));
}

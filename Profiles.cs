using System.Drawing;

namespace MSIProfileSwitcher;

public enum ProfileId { Silent, Balanced, Extreme, SuperBattery }

public sealed record ProfileDef(
    ProfileId Id,
    string Key,
    string Label,
    string SubKey,            // klucz lokalizacji podtytulu OSD
    Color DefaultColor,
    (byte addr, byte val)[] Recipe);

public static class Profiles
{
    // Przepisy zweryfikowane: 0xD4 (fan mode) to glowny lewar capu mocy.
    // 0x89/0x91 to CZUJNIKI predkosci wentylatorow (read-only), NIE ustawienia -> usuniete.
    public static readonly ProfileDef[] All =
    {
        new(ProfileId.Silent, "Silent", "SILENT", "sub_silent",
            ColorTranslator.FromHtml("#8B5CF6"),
            new (byte, byte)[] { (0xD2,0xC1),(0x34,0x00),(0xEB,0x00),(0xD4,0x1D) }),

        new(ProfileId.Balanced, "Balanced", "BALANCED", "sub_balanced",
            ColorTranslator.FromHtml("#2D7FF0"),
            new (byte, byte)[] { (0xD2,0xC1),(0x34,0x01),(0xEB,0x00),(0xD4,0x0D) }),

        new(ProfileId.Extreme, "Extreme", "EXTREME", "sub_extreme",
            ColorTranslator.FromHtml("#E0533D"),
            new (byte, byte)[] { (0xD2,0xC4),(0x34,0x01),(0xEB,0x00),(0xD4,0x0D) }),

        new(ProfileId.SuperBattery, "SuperBattery", "SUPER BATTERY", "sub_superbattery",
            ColorTranslator.FromHtml("#3FB950"),
            new (byte, byte)[] { (0xD2,0xC2),(0x34,0x01),(0xEB,0x0F),(0xD4,0x0D) }),
    };

    public static readonly ProfileId[] Order =
        { ProfileId.Silent, ProfileId.Balanced, ProfileId.Extreme, ProfileId.SuperBattery };

    public static ProfileDef Get(ProfileId id) => All.First(p => p.Id == id);

    // paleta 12 kolorow do wyboru per profil
    public static readonly string[] Palette =
    {
        "#8B5CF6", "#2D7FF0", "#17C0EB", "#1FB58F", "#3FB950", "#A8CC2C",
        "#F2C037", "#F5871F", "#E0533D", "#E64980", "#B86BFF", "#8895A7",
    };
}

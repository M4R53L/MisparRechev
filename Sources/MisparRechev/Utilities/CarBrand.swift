import Foundation

/// A car maker resolved from the registry's manufacturer string.
///
/// The registry names makers with the factory country appended and often
/// truncated ("מזדה יפן", "פולקסווגן גרמנ", "ב מ וו ארהב\""), so the clean
/// brand name and the bundled logo are found by prefix.
struct CarBrand: Equatable {
    /// Clean Hebrew brand name, without the factory country.
    let name: String
    /// Asset name under `Brands/` in the asset catalog; nil when no logo is bundled.
    let slug: String?
}

enum CarBrands {
    /// (registry prefixes, clean name, logo slug). Longer prefixes come first
    /// where one brand's name starts another's ("פיאט קרייזלר" before "פיאט").
    private static let table: [([String], String, String?)] = [
        (["פיאט קרייזלר", "FCA"], "פיאט קרייזלר", nil),
        (["דיימלר קרייזלר"], "דיימלר קרייזלר", nil),
        (["מרוטי סוזוקי", "MARUTI"], "סוזוקי", "suzuki"),
        (["לנד רובר", "לנדרובר", "LAND ROVER", "רובר"], "לנד רובר", "land-rover"),
        (["אלפא רומיאו", "ALFA"], "אלפא רומיאו", "alfa-romeo"),
        (["אסטון מרטין", "ASTON"], "אסטון מרטין", "aston-martin"),
        (["רולס רויס", "ROLLS"], "רולס רויס", "rolls-royce"),
        (["מרצדס", "MERCEDES"], "מרצדס בנץ", "mercedes-benz"),
        (["גרייט וול", "GREAT WALL", "GWM"], "גרייט וול", "great-wall"),
        (["לינק", "LYNK"], "לינק אנד קו", "lynk-and-co"),
        (["אאודי", "אודי", "AUDI"], "אאודי", "audi"),
        (["אופל", "OPEL"], "אופל", "opel"),
        (["אורה", "ORA"], "אורה", nil),
        (["איווייס", "AIWAYS"], "איווייס", "aiways"),
        (["איסוזו", "ISUZU"], "איסוזו", "isuzu"),
        (["איווקו", "IVECO"], "איווקו", "iveco"),
        (["אינפיניטי", "INFINITI"], "אינפיניטי", "infiniti"),
        (["אבארט", "ABARTH"], "אבארט", "abarth"),
        (["אלפין", "ALPINE"], "אלפין", "alpine"),
        (["אס דבליו אמ", "SWM"], "SWM", nil),
        (["אף איי דבליו", "FAW"], "FAW", "faw"),
        (["אקספנג", "XPENG"], "אקספנג", "xpeng"),
        (["ב מ וו", "ב.מ.וו", "במוו", "BMW"], "ב.מ.וו", "bmw"),
        (["בי ווי די", "בי.ווי.די", "BYD"], "BYD", "byd"),
        (["ביואיק", "BUICK"], "ביואיק", "buick"),
        (["בנטלי", "BENTLEY"], "בנטלי", "bentley"),
        (["ג'אקו", "JAECOO"], "ג'אקו", nil),
        (["ג'ילי", "GEELY"], "ג'ילי", "geely"),
        (["ג'יפ", "JEEP"], "ג'יפ", "jeep"),
        (["ג'נסיס", "GENESIS"], "ג'נסיס", "genesis"),
        (["ג'יאיוואן", "ג'יטור", "JETOUR"], "ג'יטור", "jetour"),
        (["ג'י.אם.סי", "GMC"], "GMC", "gmc"),
        (["דאצ'יה", "DACIA"], "דאצ'יה", "dacia"),
        (["דודג'", "DODGE"], "דודג'", "dodge"),
        (["דונגפנג", "DONGFENG"], "דונגפנג", "dongfeng"),
        (["דייהטסו", "DAIHATSU"], "דייהטסו", "daihatsu"),
        (["דייהו", "DAEWOO"], "דייהו", "daewoo"),
        (["די.אס", "די אס", "DS"], "DS", "ds"),
        (["דאף", "DAF"], "דאף", "daf"),
        (["הונדה", "HONDA"], "הונדה", "honda"),
        (["האמר", "HUMMER"], "האמר", "hummer"),
        (["הוואל", "HAVAL"], "הוואל", "haval"),
        (["הונגצ'י", "HONGQI"], "הונגצ'י", "hongqi"),
        (["וולבו", "VOLVO"], "וולבו", "volvo"),
        (["וויי", "WEY"], "WEY", "wey"),
        (["זיקר", "ZEEKR"], "זיקר", "zeekr"),
        (["טויוטה", "TOYOTA"], "טויוטה", "toyota"),
        (["טסלה", "TESLA"], "טסלה", "tesla"),
        (["יגואר", "JAGUAR"], "יגואר", "jaguar"),
        (["יונדאי", "HYUNDAI"], "יונדאי", "hyundai"),
        (["לקסוס", "LEXUS"], "לקסוס", "lexus"),
        (["לנצ'יה", "LANCIA"], "לנצ'יה", "lancia"),
        (["לאדה", "LADA"], "לאדה", "lada"),
        (["למבורגיני", "LAMBORGHINI"], "למבורגיני", "lamborghini"),
        (["לוטוס", "LOTUS"], "לוטוס", "lotus"),
        (["לינקולן", "LINCOLN"], "לינקולן", "lincoln"),
        (["ליפמוטור", "LEAPMOTOR"], "ליפמוטור", "leapmotor"),
        (["מ.ג'י", "מ.ג", "אם ג'י", "MG"], "MG", "mg"),
        (["מזדה", "MAZDA"], "מזדה", "mazda"),
        (["מזראטי", "MASERATI"], "מזראטי", "maserati"),
        (["מיצובישי", "MITSUBISHI"], "מיצובישי", "mitsubishi"),
        (["מיני", "MINI"], "מיני", "mini"),
        (["מקסוס", "MAXUS"], "מקסוס", "maxus"),
        (["מקלארן", "MCLAREN"], "מקלארן", "mclaren"),
        (["מאן", "MAN "], "מאן", "man"),
        (["ניסאן", "NISSAN"], "ניסאן", "nissan"),
        (["NIO"], "ניו", "nio"),
        (["סאנגיונג", "סאנג יונג", "SSANGYONG"], "סאנגיונג", "ssangyong"),
        (["סאאב", "SAAB"], "סאאב", "saab"),
        (["סובארו", "SUBARU"], "סובארו", "subaru"),
        (["סוזוקי", "SUZUKI"], "סוזוקי", "suzuki"),
        (["סיאט", "SEAT"], "סיאט", "seat"),
        (["סיטרואן", "CITROEN"], "סיטרואן", "citroen"),
        (["סקודה", "SKODA"], "סקודה", "skoda"),
        (["סקיוול", "SKYWELL"], "סקייוול", nil),
        (["סקניה", "SCANIA"], "סקניה", "scania"),
        (["סמארט", "SMART"], "סמארט", "smart"),
        (["פולסטאר", "POLESTAR"], "פולסטאר", "polestar"),
        (["פולקסווגן", "VOLKSWAGEN", "VW"], "פולקסווגן", "volkswagen"),
        (["פורד", "FORD"], "פורד", "ford"),
        (["פורשה", "PORSCHE"], "פורשה", "porsche"),
        (["פיאט", "FIAT"], "פיאט", "fiat"),
        (["פיג'ו", "PEUGEOT"], "פיג'ו", "peugeot"),
        (["פרארי", "FERRARI"], "פרארי", "ferrari"),
        (["צ'רי", "CHERY"], "צ'רי", "chery"),
        (["קאדילאק", "קדילאק", "CADILLAC"], "קאדילאק", "cadillac"),
        (["קופרה", "CUPRA"], "קופרה", "cupra"),
        (["קיה", "KIA"], "קיה", "kia"),
        (["קרייזלר", "CHRYSLER"], "קרייזלר", "chrysler"),
        (["ק.ט.מ", "KTM"], "KTM", "ktm"),
        (["רנו", "RENAULT"], "רנו", "renault"),
        (["ראם", "RAM"], "ראם", "ram"),
        (["שברולט", "CHEVROLET"], "שברולט", "chevrolet")
    ]

    /// Resolves the registry's `tozeret_nm` to a brand, or nil when unknown.
    static func brand(forManufacturer raw: String?) -> CarBrand? {
        guard let raw else { return nil }
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !name.isEmpty else { return nil }
        for (prefixes, clean, slug) in table {
            if prefixes.contains(where: { name.hasPrefix($0) }) {
                return CarBrand(name: clean, slug: slug)
            }
        }
        return nil
    }
}

extension Vehicle {
    /// The maker as a clean brand (name without factory country, logo slug).
    var brand: CarBrand? { CarBrands.brand(forManufacturer: tozeret_nm) }

    /// רמת גימור (trim level, e.g. "S", "ULT HARMONY").
    var trimLevel: String? {
        guard let t = ramat_gimur?.trimmingCharacters(in: .whitespacesAndNewlines),
              !t.isEmpty else { return nil }
        return t
    }

    /// Title for the report: brand + commercial model ("מזדה MX 5").
    var reportTitle: String {
        let makerName = brand?.name ?? manufacturer
        guard let model else { return makerName ?? displayName }
        guard let makerName else { return model }
        // Some records already lead the model with the brand.
        if model.uppercased().hasPrefix(makerName.uppercased()) { return model }
        return "\(makerName) \(model)"
    }
}

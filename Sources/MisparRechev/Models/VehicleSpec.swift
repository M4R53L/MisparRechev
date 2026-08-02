import Foundation

/// A model-specification record from the "מאגר דגמי רכב" resource
/// (`142afde2-6228-49f9-8a29-9b6c3a0cbe40`) — the per-model/trim/year spec
/// sheet: horsepower, gearbox, drive, body, seats/doors, airbags and the
/// safety-assist feature flags.
///
/// Joined to a vehicle on the same four keys as the new-car price resource
/// (`tozeret_cd`, `degem_cd`, `sug_degem`, `shnat_yitzur`) — normally exactly
/// one record. Vehicles resolved from the fallback datasets lack `degem_cd`,
/// so they have no spec and the extra rows hide.
///
/// Note the resource's own spelling quirks: engine displacement here is
/// `nefah_manoa` (the primary registration resource calls it `nefach_manoa`).
/// Feature flags are 0/1 integers; `nikud_betihut` is deliberately NOT decoded
/// (it arrives as a float, e.g. `2.0`, and duplicates `ramat_eivzur_betihuty`).
struct VehicleSpec: Codable, Equatable {
    // Model-identity join keys (used to defensively re-match the record).
    let tozeret_cd: Int?
    let degem_cd: Int?
    let sug_degem: String?
    let shnat_yitzur: Int?

    /// כוח סוס (הספק בכ״ס).
    let koah_sus: Int?
    /// נפח מנוע בסמ"ק — spelled without the `c` in this resource.
    let nefah_manoa: Int?
    /// משקל כולל (ק"ג).
    let mishkal_kolel: Int?
    /// הנעה (למשל "4X2", "4X4").
    let hanaa_nm: String?
    /// תיבת הילוכים אוטומטית (0/1).
    let automatic_ind: Int?
    /// מספר דלתות.
    let mispar_dlatot: Int?
    /// מספר מושבים.
    let mispar_moshavim: Int?
    /// מרכב (סדאן / האצ'בק / קבריולט / סטיישן …).
    let merkav: String?
    /// טכנולוגיית הנעה ("הנעה רגילה" / "PLUG IN" / "היברידי" / "חשמלי").
    let technologiat_hanaa_nm: String?
    /// פליטת CO2 בגרם/ק"מ במחזור הישן (NEDC) — בדגמים ישנים; null בחדשים.
    /// Double: שדות מספריים במאגר זה מגיעים לעיתים כשברים.
    let kamut_CO2: Double?
    /// פליטת CO2 בגרם/ק"מ בתקן WLTP — בדגמים חדשים; null בישנים.
    let CO2_WLTP: Double?

    // Safety equipment.
    /// מספר כריות אוויר.
    let mispar_kariot_avir: Int?
    /// ABS (0/1).
    let abs_ind: Int?
    /// בקרת יציבות (0/1).
    let bakarat_yatzivut_ind: Int?
    /// רמת אבזור בטיחותי (0–8, גבוה = מאובזר יותר). null בדגמים ישנים.
    let ramat_eivzur_betihuty: Int?

    // Towing capacity (ק"ג, 0 = לא מדורג).
    let kosher_grira_im_blamim: Int?
    let kosher_grira_bli_blamim: Int?

    // Driver-assist feature flags (0/1).
    let bakarat_stiya_menativ_ind: Int?
    let bakarat_stiya_activ_s: Int?
    let nitur_merhak_milfanim_ind: Int?
    let zihuy_matzav_hitkarvut_mesukenet_ind: Int?
    let zihuy_beshetah_nistar_ind: Int?
    let bakarat_shyut_adaptivit_ind: Int?
    let zihuy_holchey_regel_ind: Int?
    let zihuy_rechev_do_galgali: Int?
    let zihuy_tamrurey_tnua_ind: Int?
    let maarechet_ezer_labalam_ind: Int?
    let blima_otomatit_nesia_leahor: Int?
    let blimat_hirum_lifnei_holhei_regel_ofanaim: Int?
    let hitnagshut_cad_shetah_met: Int?
    let matzlemat_reverse_ind: Int?
    let hayshaney_lahatz_avir_batzmigim_ind: Int?
    let hayshaney_hagorot_ind: Int?
    let teura_automatit_benesiya_kadima_ind: Int?
    let shlita_automatit_beorot_gvohim_ind: Int?
    let bakarat_mehirut_isa: Int?

    // MARK: - Display helpers

    /// כוח סוס — hidden when 0/absent.
    var horsepower: Int? { positive(koah_sus) }

    /// נפח מנוע בסמ"ק — hidden when 0/absent.
    var displacementCC: Int? { positive(nefah_manoa) }

    /// משקל כולל בק"ג — hidden when 0/absent.
    var grossWeightKg: Int? { positive(mishkal_kolel) }

    /// "אוטומטית" / "ידנית".
    var gearbox: String? {
        guard let automatic_ind else { return nil }
        return automatic_ind != 0 ? "אוטומטית" : "ידנית"
    }

    /// הנעה (4X2 / 4X4).
    var driveType: String? {
        hanaa_nm?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    /// מרכב.
    var bodyType: String? {
        merkav?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    var seats: Int? { positive(mispar_moshavim) }
    var doors: Int? { positive(mispar_dlatot) }

    /// טכנולוגיית הנעה מיוחדת — `nil` להנעה רגילה (שורה מוסתרת), עם עברות
    /// לערכים לועזיים ידועים.
    var driveTechnology: String? {
        guard let raw = technologiat_hanaa_nm?
            .trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty else { return nil }
        if raw == "הנעה רגילה" { return nil }
        if raw.uppercased() == "PLUG IN" { return "היברידי נטען (Plug-in)" }
        return raw
    }

    /// פליטת CO2 בגרם/ק"מ — WLTP עדיף על NEDC; nil כשאין נתון חיובי.
    var co2Display: String? {
        if let wltp = CO2_WLTP, wltp > 0 { return "\(Int(wltp.rounded())) (WLTP)" }
        if let nedc = kamut_CO2, nedc > 0 { return String(Int(nedc.rounded())) }
        return nil
    }

    /// מספר כריות אוויר — 0 הוא ערך אמיתי (אין כריות) ולכן מוצג.
    var airbagCount: Int? { mispar_kariot_avir }

    var hasABS: Bool? { flag(abs_ind) }
    var hasStabilityControl: Bool? { flag(bakarat_yatzivut_ind) }

    /// רמת אבזור בטיחותי 0–8.
    var safetyEquipmentLevel: Int? { ramat_eivzur_betihuty }

    var towingWithBrakesKg: Int? { positive(kosher_grira_im_blamim) }
    var towingWithoutBrakesKg: Int? { positive(kosher_grira_bli_blamim) }

    /// מערכות הסיוע שקיימות ברכב, כתוויות עבריות (רק דגלים שדולקים).
    var safetyFeatures: [String] {
        let mapping: [(Int?, String)] = [
            (nitur_merhak_milfanim_ind, "ניטור מרחק מלפנים"),
            (zihuy_matzav_hitkarvut_mesukenet_ind, "התרעת התקרבות מסוכנת"),
            (maarechet_ezer_labalam_ind, "מערכת עזר לבלם"),
            (blimat_hirum_lifnei_holhei_regel_ofanaim, "בלימת חירום מפני הולכי רגל ורוכבים"),
            (blima_otomatit_nesia_leahor, "בלימה אוטומטית בנסיעה לאחור"),
            (bakarat_stiya_menativ_ind, "בקרת סטייה מנתיב"),
            (bakarat_stiya_activ_s, "בקרת סטייה אקטיבית"),
            (bakarat_shyut_adaptivit_ind, "בקרת שיוט אדפטיבית"),
            (zihuy_beshetah_nistar_ind, "ניטור שטחים מתים"),
            (hitnagshut_cad_shetah_met, "התרעת התנגשות צד"),
            (zihuy_holchey_regel_ind, "זיהוי הולכי רגל"),
            (zihuy_rechev_do_galgali, "זיהוי רכב דו־גלגלי"),
            (zihuy_tamrurey_tnua_ind, "זיהוי תמרורי תנועה"),
            (matzlemat_reverse_ind, "מצלמת רוורס"),
            (hayshaney_lahatz_avir_batzmigim_ind, "חיישני לחץ אוויר בצמיגים"),
            (hayshaney_hagorot_ind, "חיישני חגורות בטיחות"),
            (teura_automatit_benesiya_kadima_ind, "תאורה אוטומטית בנסיעה קדימה"),
            (shlita_automatit_beorot_gvohim_ind, "ניהול אורות גבוהים אוטומטי"),
            (bakarat_mehirut_isa, "בקרת מהירות חכמה (ISA)")
        ]
        return mapping.compactMap { value, label in (value ?? 0) != 0 ? label : nil }
    }

    // MARK: - Private

    private func positive(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func flag(_ value: Int?) -> Bool? {
        guard let value else { return nil }
        return value != 0
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

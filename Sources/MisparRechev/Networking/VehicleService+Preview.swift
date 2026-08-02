import Foundation

/// Sample vehicle data for SwiftUI previews. Mirrors a real data.gov.il
/// record for plate `5970065` (מזדה MX-5, 2008).
extension Vehicle {
    static let preview = Vehicle(
        mispar_rechev: 5970065,
        tozeret_cd: 588,
        degem_cd: 12,
        tozeret_nm: "מזדה יפן",
        kinuy_mishari: "MX 5",
        sug_degem: "P",
        degem_nm: "NC18F",
        shnat_yitzur: 2008,
        tzeva_rechev: "אפור",
        sug_delek_nm: "בנזין",
        nefach_manoa: nil,
        mishkal_kolel: nil,
        mishkal_aa: nil,
        kvutzat_zihum: 15,
        ramat_gimur: "S",
        ramat_eivzur_betihuty: nil,
        tokef_dt: "2027-05-24",
        tokef_rishuy: nil,
        moed_aliya_lakvish: "2008-5",
        mivchan_acharon_dt: "2026-05-24",
        baalut: "פרטי",
        misgeret: "JMZNC18F6-80153489",
        mispar_baalim: nil,
        shilda: nil,
        mispar_shilda: nil,
        mishkal_azmi: nil,
        sug_rechev_nm: nil,
        kvutzat_sug_rechev: nil,
        tozeret_eretz_nm: nil,
        sug_yevu: nil,
        degem_manoa: nil,
        mispar_manoa: nil,
        bitul_dt: nil
    )
}

extension VehicleSpec {
    /// Real model-spec record for plate `5970065` (מזדה MX-5, 2008) —
    /// matches `Vehicle.preview`. A 2008 model: no driver-assist flags.
    static let preview = VehicleSpec(
        tozeret_cd: 588,
        degem_cd: 12,
        sug_degem: "P",
        shnat_yitzur: 2008,
        koah_sus: 160,
        nefah_manoa: 1999,
        mishkal_kolel: 1164,
        hanaa_nm: "4X2",
        automatic_ind: 0,
        mispar_dlatot: 2,
        mispar_moshavim: 2,
        merkav: "קבריולט",
        technologiat_hanaa_nm: "הנעה רגילה",
        kamut_CO2: 181,
        CO2_WLTP: nil,
        mispar_kariot_avir: 4,
        abs_ind: 1,
        bakarat_yatzivut_ind: 1,
        ramat_eivzur_betihuty: nil,
        kosher_grira_im_blamim: 0,
        kosher_grira_bli_blamim: 0,
        bakarat_stiya_menativ_ind: 0,
        bakarat_stiya_activ_s: 0,
        nitur_merhak_milfanim_ind: 0,
        zihuy_matzav_hitkarvut_mesukenet_ind: 0,
        zihuy_beshetah_nistar_ind: 0,
        bakarat_shyut_adaptivit_ind: 0,
        zihuy_holchey_regel_ind: 0,
        zihuy_rechev_do_galgali: 0,
        zihuy_tamrurey_tnua_ind: 0,
        maarechet_ezer_labalam_ind: 0,
        blima_otomatit_nesia_leahor: 0,
        blimat_hirum_lifnei_holhei_regel_ofanaim: 0,
        hitnagshut_cad_shetah_met: 0,
        matzlemat_reverse_ind: 0,
        hayshaney_lahatz_avir_batzmigim_ind: 0,
        hayshaney_hagorot_ind: 0,
        teura_automatit_benesiya_kadima_ind: 0,
        shlita_automatit_beorot_gvohim_ind: 0,
        bakarat_mehirut_isa: 0
    )
}

extension NewCarPrice {
    /// Real list-price record for plate `5970065` (מזדה MX-5, 2008) —
    /// matches `Vehicle.preview`.
    static let preview = NewCarPrice(
        mehir: 184000,
        shem_yevuan: "דלק מוטורס בע\"מ",
        kinuy_mishari: "MX 5",
        shnat_yitzur: 2008,
        tozeret_cd: 588,
        degem_cd: 12
    )
}

extension RecallRecord {
    /// Real open-recall record for plate `5569379` (קיה RIO 2012).
    static let preview = RecallRecord(
        MISPAR_RECHEV: 5569379,
        RECALL_ID: 15947,
        SUG_RECALL: "תקלה סידרתית בטיחותית",
        SUG_TAKALA: "מנוע ומערכותיו",
        TEUR_TAKALA: "במקרים מסוימים תתכן תקלה ביחידת הבקרה (HECU) בתא המנוע",
        TAARICH_PTICHA: "2025-03-12"
    )
}

extension VehicleHistory {
    static let preview = VehicleHistory(
        mispar_rechev: 3256880,
        mispar_manoa: "CZE 289985",
        kilometer_test_aharon: 159816,
        shinui_mivne_ind: 1,
        gapam_ind: 0,
        shnui_zeva_ind: 0,
        shinui_zmig_ind: 1,
        rishum_rishon_dt: "2017-03-16 00:00:00",
        mkoriut_nm: ""
    )
}
import Foundation

/// Sample vehicle data for SwiftUI previews. Mirrors a real data.gov.il
/// record for plate `5970065` (מזדה MX-5, 2008).
extension Vehicle {
    static let preview = Vehicle(
        mispar_rechev: 5970065,
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
        mispar_manoa: nil
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
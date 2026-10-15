//
//  MOTRegionFactory.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

#if canImport(OBAKitCore)
import OBAKitCore
#endif

public enum MOTRegionFactory {
    public static let israelRegionIdentifier = 972

    public static let israelCenterCoordinate = CLLocationCoordinate2D(latitude: 31.7683, longitude: 35.2137) // Jerusalem

    public static func isIsrael(regionIdentifier: Int) -> Bool {
        return regionIdentifier == israelRegionIdentifier
    }

    public static func makeIsraelRegionJSON() -> [String: Any] {
        return [
            "id": israelRegionIdentifier,
            "regionName": "ישראל (משרד התחבורה)",
            "sidecarBaseUrl": nil as Any?,
            "plausibleAnalyticsServerUrl": nil as Any?,
            "obaBaseUrl": "https://api.bus.gov.il/prod/mot-scheduler-prod/",
            "siriBaseUrl": nil as Any?,
            "bounds": [
                [
                    "lat": 31.5,
                    "lon": 35.0,
                    "latSpan": 3.8,
                    "lonSpan": 2.2
                ]
            ],
            "language": "he_IL",
            "contactEmail": "support@bus.gov.il",
            "supportsObaDiscoveryApis": true,
            "supportsObaRealtimeApis": true,
            "supportsSiriRealtimeApis": false,
            "active": true,
            "obaVersionInfo": "1.0.0-mot|1|0|0|mot|israel",
            "twitterUrl": "",
            "facebookUrl": "",
            "experimental": false,
            "stopInfoUrl": nil as Any?,
            "open311Servers": [] as [Any],
            "otpBaseUrl": "https://api.bus.gov.il/prod/route-planner-prod/",
            "otpBaseGraphqlUrl": nil as Any?,
            "otpContactEmail": nil as Any?,
            "supportsEmbeddedSocial": false,
            "supportsOtpBikeshare": false,
            "supportsOtpGraphqlBikeshare": false,
            "paymentAndroidAppId": nil as Any?,
            "paymentWarningTitle": nil as Any?,
            "paymentWarningBody": nil as Any?,
            "paymentiOSAppStoreIdentifier": nil as Any?,
            "paymentiOSAppUrlScheme": nil as Any?,
            "travelBehaviorDataCollectionEnabled": false,
            "enrollParticipantsInStudy": false
        ]
    }
}

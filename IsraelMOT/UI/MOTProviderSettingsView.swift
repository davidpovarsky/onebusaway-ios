//
//  MOTProviderSettingsView.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import SwiftUI

public struct MOTProviderSettingsView: View {
    public init() {}

    public var body: some View {
        List {
            Section(header: Text("ספק נתונים")) {
                HStack {
                    Text("שם הספק")
                    Spacer()
                    Text("משרד התחבורה והבטיחות בדרכים")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("פורטל אינטרנט")
                    Spacer()
                    Link("route.bus.gov.il", destination: URL(string: "https://route.bus.gov.il")!)
                }
                HStack {
                    Text("מוקד מידע ארצי")
                    Spacer()
                    Text("*8787")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("מצב שירות וקישוריות")) {
                HStack {
                    Text("חיפוש תחנות וקווים")
                    Spacer()
                    Label("פעיל", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                HStack {
                    Text("זמני הגעה מתוכננים")
                    Spacer()
                    Label("פעיל", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                HStack {
                    Text("תכנון מסלול ישיר")
                    Spacer()
                    Label("מוגבל ע״י WAF", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }

            Section(footer: Text("OneBusAway פועלת על פי תקני קוד פתוח ומאפשרת חיבור שקוף לשרתי משרד התחבורה בישראל.")) {
                EmptyView()
            }
        }
        .navigationTitle("הגדרות ספק ישראל")
    }
}

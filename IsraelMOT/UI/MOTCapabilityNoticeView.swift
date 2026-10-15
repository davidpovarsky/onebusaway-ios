//
//  MOTCapabilityNoticeView.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import SwiftUI

public struct MOTCapabilityNoticeView: View {
    public let message: String

    public init(message: String = "נתוני זמן אמת מוצגים בהתאם לדיווח המפעילים וזמינות ה-GPS של משרד התחבורה.") {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
                .font(.subheadline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

//
//  StepButtonView.swift
//  MultiCamMac
//
//  Created by ZSS on 2025/8/6.
//

import SwiftUI

struct StepButtonView: View {
    var title: String
    var isSelected: Bool

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.3) : Color.lightGrayBox)
            )
            .foregroundColor(.black)
    }
}



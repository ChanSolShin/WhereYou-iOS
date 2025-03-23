//
//  KeyboardHelper.swift
//  iOS_Project
//
//  Created by CHOI on 3/23/25.
//

import SwiftUI

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

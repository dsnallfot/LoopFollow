//
//  DexcomSettingsView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-18.

//

import SwiftUI

@available(iOS 16.0, *)
struct DexcomSettingsView: View {
    @ObservedObject var viewModel: DexcomSettingsViewModel

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            Form {
                Section(footer: Text("Använd Dexcom share för att hämta glukosvärden")) {
                    Toggle("Använd Dexcom Share", isOn: $viewModel.shareActive)
                }
                .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
                if UserDefaultsRepository.dexcomShareActive.value {
                    Section(header: Text("Användaruppgifter")) {
                        TextField("Ange användarnamn", text: $viewModel.userName)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        TextField("Ange lösenord", text: $viewModel.password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Picker("Server", selection: $viewModel.server) {
                            Text("US").tag("US")
                            Text("EU").tag("NON-US")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Toggle("Endast adhoc hämtningar", isOn: $viewModel.adhocOnly)
                    }
                    .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }
}

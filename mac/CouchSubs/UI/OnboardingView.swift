// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    private let total = AppModel.Step.allCases.count - 1

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(model.step.rawValue + 1), total: Double(total))
                .padding(.horizontal, 32)
                .padding(.top, 24)

            Group {
                switch model.step {
                case .welcome: WelcomeStep()
                case .secondAccount: SecondAccountStep()
                case .psnLogin: PSNLoginStep()
                case .console: ConsoleStep()
                case .tv: TVStep()
                case .test, .done: TestStep()
                }
            }
            .padding(32)
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()
            HStack {
                if model.step != .welcome {
                    Button("Back") { model.back() }
                }
                Spacer()
                if model.step != .test {
                    Button("Continue") { model.advance() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!model.canAdvance)
                }
            }
            .controlSize(.large)
            .padding(20)
        }
    }
}

// DateFilterSheet.swift — shared date-range picker sheet for Mind and Library

import SwiftUI

struct DateFilterSheet: View {
    @Binding var option: DateFilterOption
    @Binding var customStart: Date
    @Binding var customEnd: Date
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Handle
            HStack {
                Capsule()
                    .fill(AppColors.ink.opacity(0.18))
                    .frame(width: 36, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 20)

            Text("filter by date")
                .appFont(22, .bold, relativeTo: .title2)
                .tracking(-0.5)
                .foregroundStyle(AppColors.primaryText)
                .padding(.bottom, 20)

            // Preset options
            VStack(spacing: 0) {
                ForEach([DateFilterOption.today, .thisWeek, .thisMonth], id: \.label) { preset in
                    Button {
                        withAnimation(AppAnimation.springSnappy) {
                            option = (option == preset) ? .none : preset
                        }
                    } label: {
                        HStack {
                            Text(preset.label)
                                .font(.system(size: 15, weight: option == preset ? .medium : .light))
                                .foregroundStyle(AppColors.primaryText)
                            Spacer()
                            if option == preset {
                                Image(systemName: "checkmark")
                                    .appFont(13, .medium, relativeTo: .subheadline)
                                    .foregroundStyle(AppColors.primaryText)
                            }
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.1)
                }

                // Custom range
                Button {
                    withAnimation(AppAnimation.springSnappy) {
                        option = (option == .custom) ? .none : .custom
                    }
                } label: {
                    HStack {
                        Text("custom range")
                            .font(.system(size: 15, weight: option == .custom ? .medium : .light))
                            .foregroundStyle(AppColors.primaryText)
                        Spacer()
                        if option == .custom {
                            Image(systemName: "checkmark")
                                .appFont(13, .medium, relativeTo: .subheadline)
                                .foregroundStyle(AppColors.primaryText)
                        }
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                if option == .custom {
                    VStack(spacing: 10) {
                        DatePicker("from", selection: $customStart, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .appFont(14, .light, relativeTo: .subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                        DatePicker("to", selection: $customEnd, in: customStart..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .appFont(14, .light, relativeTo: .subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.bottom, 16)

            // Clear
            if option != .none {
                Button {
                    withAnimation(AppAnimation.springFluid) { option = .none }
                } label: {
                    Text("clear filter")
                        .appFont(13, .light, relativeTo: .subheadline)
                        .foregroundStyle(AppColors.tertiaryText)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 28)
        .animation(AppAnimation.springFluid, value: option)
    }
}

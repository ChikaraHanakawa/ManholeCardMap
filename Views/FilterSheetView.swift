//
//  FilterSheetView.swift
//  ManholeCardMap
//
//  絞り込みシート（収集状態・地方・都道府県・弾）
//
import SwiftUI

struct FilterSheetView: View {
    @ObservedObject var viewModel: LocationViewModel
    @Binding var isPresented: Bool

    private let chipColumns = [GridItem(.adaptive(minimum: 76))]

    var displayPrefectures: [String] {
        guard !viewModel.filterRegions.isEmpty else { return viewModel.availablePrefectures }
        return viewModel.availablePrefectures.filter {
            viewModel.filterRegions.contains(viewModel.getRegion(from: $0))
        }
    }

    var body: some View {
        NavigationView {
            List {
                // 収集状態フィルタ
                Section("収集状態") {
                    Picker("収集状態", selection: $viewModel.collectedFilter) {
                        ForEach(LocationViewModel.CollectedFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                Section("地方") {
                    LazyVGrid(columns: chipColumns, spacing: 8) {
                        ForEach(Region.allCases.filter { $0 != .unknown }, id: \.self) { region in
                            FilterChip(
                                title: region.rawValue,
                                color: region.color,
                                isSelected: viewModel.filterRegions.contains(region)
                            ) {
                                if viewModel.filterRegions.contains(region) {
                                    viewModel.filterRegions.remove(region)
                                    viewModel.filterPrefectures = viewModel.filterPrefectures.filter {
                                        viewModel.getRegion(from: $0) != region
                                    }
                                } else {
                                    viewModel.filterRegions.insert(region)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("都道府県") {
                    if displayPrefectures.isEmpty {
                        Text("該当する都道府県がありません")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                    } else {
                        LazyVGrid(columns: chipColumns, spacing: 8) {
                            ForEach(displayPrefectures, id: \.self) { pref in
                                FilterChip(
                                    title: pref,
                                    color: viewModel.getRegion(from: pref).color,
                                    isSelected: viewModel.filterPrefectures.contains(pref)
                                ) {
                                    if viewModel.filterPrefectures.contains(pref) {
                                        viewModel.filterPrefectures.remove(pref)
                                    } else {
                                        viewModel.filterPrefectures.insert(pref)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("弾") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 68))], spacing: 8) {
                        ForEach(viewModel.availableSeries, id: \.self) { series in
                            FilterChip(
                                title: series,
                                color: .blue,
                                isSelected: viewModel.filterSeries.contains(series)
                            ) {
                                if viewModel.filterSeries.contains(series) {
                                    viewModel.filterSeries.remove(series)
                                } else {
                                    viewModel.filterSeries.insert(series)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("絞り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("クリア") { viewModel.clearFilters() }
                        .disabled(!viewModel.hasActiveFilters)
                }
            }
        }
    }
}

// 絞り込み用の選択チップ部品
struct FilterChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

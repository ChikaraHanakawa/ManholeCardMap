//
//  LocationListView.swift
//  ManholeCardMap
//
//  マンホールカード一覧画面（検索・並べ替え・詳細表示）
//
import SwiftUI
import CoreLocation

enum SortOrder: String, CaseIterable {
    case `default` = "デフォルト"
    case nearestFirst = "近い順"
    case bySeries = "弾の順"
}

struct LocationListView: View {
    @ObservedObject var viewModel: LocationViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .default
    @State private var selectedDetailLocation: Location?

    var displayLocations: [Location] {
        var base = viewModel.filteredLocations
        if !searchText.isEmpty {
            base = base.filter { $0.title.contains(searchText) || $0.municipality.contains(searchText) }
        }
        switch sortOrder {
        case .default:
            return base
        case .nearestFirst:
            guard let userLoc = viewModel.userLocation else { return base }
            let user = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
            return base.sorted {
                let a = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                let b = CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)
                return user.distance(from: a) < user.distance(from: b)
            }
        case .bySeries:
            return base.sorted {
                let a = Int(String($0.series.filter(\.isNumber))) ?? 0
                let b = Int(String($1.series.filter(\.isNumber))) ?? 0
                return a < b
            }
        }
    }

    var body: some View {
        NavigationView {
            List(displayLocations) { location in
                Button(action: { selectedDetailLocation = location }) {
                    HStack {
                        Circle()
                            .fill(viewModel.isCollected(location) ? Color.gray : location.region.color)
                            .frame(width: 14, height: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.title)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Text(location.municipality)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(location.prefecture)
                                .font(.system(size: 12)).foregroundColor(.gray)
                            if !location.series.isEmpty {
                                Text(location.series)
                                    .font(.system(size: 11)).foregroundColor(.blue)
                            }
                        }
                        if viewModel.isCollected(location) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                        }
                    }
                }
            }
            .navigationTitle("一覧 (\(displayLocations.count)件)")
            .searchable(text: $searchText, prompt: "場所・市区町村を検索")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Picker("並び順", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .sheet(item: $selectedDetailLocation) { location in
            LocationDetailView(
                location: location,
                viewModel: viewModel,
                onNavigate: {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.errorMessage = nil
                        viewModel.selectedLocation = location
                        if viewModel.userLocation != nil { viewModel.calculateRoute() }
                    }
                }
            )
        }
    }
}

//
//  LocationViewModel.swift
//  ManholeCardMap
//
//  アプリの中心となるロジック（状態の保持・絞り込み・収集済み管理）
//  データ読み込みは LocationViewModel+DataLoading.swift、
//  経路計算は LocationViewModel+Routing.swift、
//  位置情報の取得は LocationViewModel+Location.swift に分かれています
//
import SwiftUI
import MapKit
import CoreLocation

class LocationViewModel: NSObject, ObservableObject {
    @Published var locations: [Location] = []
    @Published var selectedLocation: Location?
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var route: MKRoute?
    @Published var errorMessage: ErrorMessage?

    // 絞り込みフィルタ
    @Published var filterRegions: Set<Region> = []
    @Published var filterPrefectures: Set<String> = []
    @Published var filterSeries: Set<String> = []

    enum CollectedFilter: String, CaseIterable {
        case all = "すべて"
        case uncollectedOnly = "未収集のみ"
        case collectedOnly = "収集済みのみ"
    }
    @Published var collectedFilter: CollectedFilter = .all

    // 収集済みカード（cardImageURL を識別子として使用）
    @Published var collectedCardURLs: Set<String> = []

    // 位置情報の状態を表すプロパティ
    @Published var locationStatus: LocationStatus = .unknown

    // 計算された各交通手段のルートを保持する変数
    @Published var availableRoutes: [TransportTypeKey: MKRoute] = [:]
    @Published var selectedTransportType: MKDirectionsTransportType = .automobile

    var locationManager: CLLocationManager!

    // 進行中のすべての経路計算リクエストを保持
    var directionsRequests: [MKDirections] = []
    var localSearchRequests: [MKLocalSearch] = []

    override init() {
        super.init()
        loadCollectedCards()
        loadSampleData()
        setupLocationManager()
    }

    // MARK: - 絞り込み

    var filteredLocations: [Location] {
        locations.filter { loc in
            let matchesRegion = filterRegions.isEmpty || filterRegions.contains(loc.region)
            let matchesPrefecture = filterPrefectures.isEmpty || filterPrefectures.contains(loc.prefecture)
            let matchesSeries = filterSeries.isEmpty || filterSeries.contains(loc.series)
            let matchesCollected: Bool
            switch collectedFilter {
            case .all: matchesCollected = true
            case .collectedOnly: matchesCollected = isCollected(loc)
            case .uncollectedOnly: matchesCollected = !isCollected(loc)
            }
            return matchesRegion && matchesPrefecture && matchesSeries && matchesCollected
        }
    }

    var availableSeries: [String] {
        let set = Set(locations.map { $0.series }).filter { !$0.isEmpty }
        return set.sorted {
            let a = Int(String($0.filter(\.isNumber))) ?? 0
            let b = Int(String($1.filter(\.isNumber))) ?? 0
            return a < b
        }
    }

    // 北海道から沖縄県の地理順
    static let orderedPrefectures: [String] = [
        "北海道",
        "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県", "静岡県", "愛知県",
        "三重県", "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
        "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県",
        "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]

    var availablePrefectures: [String] {
        let existing = Set(locations.map { $0.prefecture })
        return Self.orderedPrefectures.filter { existing.contains($0) }
    }

    var hasActiveFilters: Bool {
        !filterRegions.isEmpty || !filterPrefectures.isEmpty || !filterSeries.isEmpty || collectedFilter != .all
    }

    var activeFilterCount: Int {
        filterRegions.count + filterPrefectures.count + filterSeries.count + (collectedFilter != .all ? 1 : 0)
    }

    func clearFilters() {
        filterRegions.removeAll()
        filterPrefectures.removeAll()
        filterSeries.removeAll()
        collectedFilter = .all
    }

    // MARK: - 収集済み管理

    func isCollected(_ location: Location) -> Bool {
        guard !location.cardImageURL.isEmpty else { return false }
        return collectedCardURLs.contains(location.cardImageURL)
    }

    func toggleCollected(_ location: Location) {
        guard !location.cardImageURL.isEmpty else { return }
        if collectedCardURLs.contains(location.cardImageURL) {
            collectedCardURLs.remove(location.cardImageURL)
        } else {
            collectedCardURLs.insert(location.cardImageURL)
        }
        saveCollectedCards()
    }

    private func saveCollectedCards() {
        UserDefaults.standard.set(Array(collectedCardURLs), forKey: "collectedCardURLs")
    }

    private func loadCollectedCards() {
        let arr = UserDefaults.standard.stringArray(forKey: "collectedCardURLs") ?? []
        collectedCardURLs = Set(arr)
    }
}

//
//  Map.swift
//  ManholeCardMap
//
//  Created by ChikaraHanakawa on 2025/04/18.
//
import SwiftUI
import MapKit
import CoreLocation

// MKDirectionsTransportTypeはすでにHashableに準拠しています
// Appleがこの準拠を将来的に追加する場合に備えて、拡張を削除しました

// MKDirectionsTransportType をHashableにするためのラッパー
struct TransportTypeKey: Hashable {
    let transportType: MKDirectionsTransportType
    
    init(_ transportType: MKDirectionsTransportType) {
        self.transportType = transportType
    }
    
    func hash(into hasher: inout Hasher) {
        // MKDirectionsTransportType は整数値を使って区別できる
        // if-else文を使用して警告を回避
        let hashValue: Int
        
        if transportType == .automobile {
            hashValue = 1
        } else if transportType == .walking {
            hashValue = 2
        } else if transportType == .transit {
            hashValue = 3
        } else if transportType == .any {
            hashValue = 4
        } else {
            // 将来追加される可能性のあるケースに対応
            hashValue = 0
        }
        
        hasher.combine(hashValue)
    }
    
    static func == (lhs: TransportTypeKey, rhs: TransportTypeKey) -> Bool {
        // 同じケースであるかどうかを判断 (if-else文を使用して警告を回避)
        if lhs.transportType == .automobile && rhs.transportType == .automobile {
            return true
        } else if lhs.transportType == .walking && rhs.transportType == .walking {
            return true
        } else if lhs.transportType == .transit && rhs.transportType == .transit {
            return true
        } else if lhs.transportType == .any && rhs.transportType == .any {
            return true
        } else {
            return false
        }
    }
}

struct Location: Identifiable {
    let id = UUID()
    let title: String
    let coordinate: CLLocationCoordinate2D
    let prefecture: String
    let region: Region
}

enum Region: String {
    case hokkaido = "北海道"
    case tohoku = "東北"
    case kanto = "関東"
    case hokuriku = "北陸"
    case chubu = "中部"
    case kinki = "近畿"
    case chugoku = "中国"
    case shikoku = "四国"
    case kyushuOkinawa = "九州・沖縄"
    case unknown = "不明"
    
    var color: Color {
        switch self {
        case .hokkaido:
            return .green
        case .tohoku:
            return Color(red: 0.5, green: 0.8, blue: 0.5)
        case .kanto:
            return Color(red: 0.7, green: 0.9, blue: 1.0)
        case .hokuriku:
            return Color(red: 0.0, green: 0.2, blue: 0.6)
        case .chubu:
            return .yellow
        case .kinki:
            return .orange
        case .chugoku:
            return .red
        case .shikoku:
            return .purple
        case .kyushuOkinawa:
            return .pink
        case .unknown:
            return .gray
        }
    }
}

struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
}

class LocationViewModel: NSObject, ObservableObject {
    @Published var locations: [Location] = []
    @Published var selectedLocation: Location?
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var route: MKRoute?
    @Published var errorMessage: ErrorMessage?
    
    // 位置情報の状態を表すプロパティ
    @Published var locationStatus: LocationStatus = .unknown
    
    // 計算された各交通手段のルートを保持する変数を追加
    @Published var availableRoutes: [TransportTypeKey: MKRoute] = [:]
    @Published var selectedTransportType: MKDirectionsTransportType = .automobile

    private var locationManager: CLLocationManager!
    
    // 進行中のすべての経路計算リクエストを保持
    private var directionsRequests: [MKDirections] = []
    private var localSearchRequests: [MKLocalSearch] = []
    
    enum LocationStatus: String {
        case unknown = "不明"
        case denied = "拒否"
        case restricted = "制限"
        case notDetermined = "未決定"
        case authorizedWhenInUse = "使用中のみ許可"
        case authorizedAlways = "常に許可"
        
        var description: String {
            return self.rawValue
        }
        
        var icon: String {
            switch self {
            case .authorizedWhenInUse, .authorizedAlways:
                return "location.fill"
            case .denied, .restricted:
                return "location.slash.fill"
            case .unknown, .notDetermined:
                return "location"
            }
        }
        
        var color: Color {
            switch self {
            case .authorizedWhenInUse, .authorizedAlways:
                return .green
            case .denied, .restricted:
                return .red
            case .unknown, .notDetermined:
                return .yellow
            }
        }
    }
    
    override init() {
        super.init()
        // サンプルデータを使用
        loadSampleData()
        setupLocationManager()
    }
    
    func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // 10m移動ごとに更新
        locationManager.activityType = .automotiveNavigation // 車両ナビゲーション用に最適化
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func getRegion(from prefecture: String) -> Region {
        let hokkaido = ["北海道"]
        let tohoku = ["青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県"]
        let kanto = ["茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県"]
        let hokuriku = ["新潟県", "富山県", "石川県", "福井県"]
        let chubu = ["山梨県", "長野県", "岐阜県", "静岡県", "愛知県"]
        let kinki = ["三重県", "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県"]
        let chugoku = ["鳥取県", "島根県", "岡山県", "広島県", "山口県"]
        let shikoku = ["徳島県", "香川県", "愛媛県", "高知県"]
        let kyushuOkinawa = ["福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"]
        
        if hokkaido.contains(where: { prefecture.contains($0) }) {
            return .hokkaido
        } else if tohoku.contains(where: { prefecture.contains($0) }) {
            return .tohoku
        } else if kanto.contains(where: { prefecture.contains($0) }) {
            return .kanto
        } else if hokuriku.contains(where: { prefecture.contains($0) }) {
            return .hokuriku
        } else if chubu.contains(where: { prefecture.contains($0) }) {
            return .chubu
        } else if kinki.contains(where: { prefecture.contains($0) }) {
            return .kinki
        } else if chugoku.contains(where: { prefecture.contains($0) }) {
            return .chugoku
        } else if shikoku.contains(where: { prefecture.contains($0) }) {
            return .shikoku
        } else if kyushuOkinawa.contains(where: { prefecture.contains($0) }) {
            return .kyushuOkinawa
        }
        
        return .unknown
    }
    
    // CSVファイルが見つからない場合のサンプルデータ
    func loadSampleData() {
        // CSV読み込みを試みる
        if !loadCSV() {
            // 失敗した場合はサンプルデータを使用
            print("サンプルデータを使用します")
            
            // 各地域のサンプルデータ
            let sampleLocations: [(String, String, Double, Double)] = [
                ("東京駅", "東京都", 35.6812, 139.7671),
                ("大阪城", "大阪府", 34.6873, 135.5260),
                ("名古屋城", "愛知県", 35.1851, 136.8995),
                ("札幌市時計台", "北海道", 43.0632, 141.3544),
                ("弘前城", "青森県", 40.6075, 140.4636),
                ("金沢駅", "石川県", 36.5780, 136.6480),
                ("広島平和記念公園", "広島県", 34.3955, 132.4536),
                ("高知城", "高知県", 33.5597, 133.5311),
                ("福岡タワー", "福岡県", 33.5936, 130.3513)
            ]
            
            for (title, prefecture, lat, lon) in sampleLocations {
                let region = getRegion(from: prefecture)
                let location = Location(
                    title: title,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    prefecture: prefecture,
                    region: region
                )
                locations.append(location)
            }
        }
    }
    
    func loadCSV() -> Bool {
        // ManholeCardLists.csvファイルを読み込む
        if let path = Bundle.main.path(forResource: "ManholeCardLists", ofType: "csv") {
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                let rows = data.components(separatedBy: "\n").dropFirst()
                
                for row in rows {
                    if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        continue
                    }
                    
                    let columns = row.components(separatedBy: ",")
                    if columns.count >= 8 {
                        let place = columns[3]
                        let prefecture = columns[4]
                        let coordString = columns[7]
                        
                        let coords = coordString.components(separatedBy: " : ")
                        
                        if coords.count == 2,
                           let lon = Double(coords[0].trimmingCharacters(in: .whitespaces)),
                           let lat = Double(coords[1].trimmingCharacters(in: .whitespaces)) {
                            
                            let region = getRegion(from: prefecture)
                            
                            let location = Location(
                                title: place,
                                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                prefecture: prefecture,
                                region: region
                            )
                            locations.append(location)
                        } else {
                            print("座標の変換に失敗: \(place)")
                        }
                    } else {
                        print("カラム数が不足: \(columns.count)")
                    }
                }
                return true
            } catch {
                print("CSV読み込みエラー: \(error)")
                return false
            }
        } else {
            print("CSVファイルが見つかりません")
            return false
        }
    }
    
    func calculateRoute() {
        // 新しい経路計算を始める前に、以前のリクエストをすべてキャンセル
        cancelAllDirectionsRequests()
        cancelAllLocalSearchRequests()
        
        // 現在位置の確認とデバッグ情報の出力
        if userLocation == nil {
            print("デバッグ: 現在位置が取得できていません")
            errorMessage = ErrorMessage(message: "現在地を特定できません。位置情報の使用を許可して、GPSの電波が届く場所にいることを確認してください。")
            return
        }
        
        if selectedLocation == nil {
            print("デバッグ: 目的地が選択されていません")
            errorMessage = ErrorMessage(message: "目的地が設定されていません。マンホールカード一覧から目的地を選択してください。")
            return
        }
        
        guard let userLocation = userLocation, let selectedLocation = selectedLocation else {
            errorMessage = ErrorMessage(message: "現在地または目的地が設定されていません")
            return
        }
        
        print("デバッグ: 現在位置 - 緯度: \(userLocation.latitude), 経度: \(userLocation.longitude)")
        print("デバッグ: 目的地 - 緯度: \(selectedLocation.coordinate.latitude), 経度: \(selectedLocation.coordinate.longitude)")
        
        // 座標が有効かチェック
        if !CLLocationCoordinate2DIsValid(userLocation) || !CLLocationCoordinate2DIsValid(selectedLocation.coordinate) {
            errorMessage = ErrorMessage(message: "無効な座標があります")
            return
        }
        
        // 距離が近すぎる場合は警告（10メートル以内）
        let startLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let endLocation = CLLocation(latitude: selectedLocation.coordinate.latitude, longitude: selectedLocation.coordinate.longitude)
        
        if startLocation.distance(from: endLocation) < 10 {
            errorMessage = ErrorMessage(message: "現在地と目的地が近すぎます")
            return
        }
        
        // 直線距離をチェック - 極端に離れている場合は警告
        let distanceInKm = startLocation.distance(from: endLocation) / 1000
        if distanceInKm > 300 { // 300km以上離れている場合
            errorMessage = ErrorMessage(message: "目的地が遠すぎます（約\(Int(distanceInKm))km）。経路検索できない可能性があります。")
            // 警告を表示するが、経路検索は続行する
        }
        
        // 経路計算を実行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 既存の経路をクリア
            self.route = nil
            self.availableRoutes.removeAll()
            
            // 現在地と目的地を道路にスナップする試み
            print("デバッグ: 道路へのスナップを試みています...")
            self.snapToRoad(coordinate: userLocation) { snappedUserLocation in
                let finalUserLocation = snappedUserLocation ?? userLocation
                if snappedUserLocation != nil {
                    print("デバッグ: 現在地を道路にスナップしました - 緯度: \(finalUserLocation.latitude), 経度: \(finalUserLocation.longitude)")
                }
                
                self.snapToRoad(coordinate: selectedLocation.coordinate) { snappedDestLocation in
                    let finalDestLocation = snappedDestLocation ?? selectedLocation.coordinate
                    if snappedDestLocation != nil {
                        print("デバッグ: 目的地を道路にスナップしました - 緯度: \(finalDestLocation.latitude), 経度: \(finalDestLocation.longitude)")
                    }
                    
                    let sourcePlacemark = MKPlacemark(coordinate: finalUserLocation, addressDictionary: nil)
                    let destinationPlacemark = MKPlacemark(coordinate: finalDestLocation, addressDictionary: nil)
                    
                    let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
                    let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
                    
                    // 複数の交通手段を試す
                    let transportTypes: [MKDirectionsTransportType] = [.automobile, .walking, .transit]
                    var remainingTypesCount = transportTypes.count
                    var anyRouteFound = false
                    
                    // 各交通手段でルート検索を行う
                    for transportType in transportTypes {
                        self.tryCalculateRoute(sourceMapItem: sourceMapItem, destinationMapItem: destinationMapItem, transportType: transportType) { [weak self] success, route in
                            guard let self = self else { return }
                            
                            remainingTypesCount -= 1
                            
                            if success, let route = route {
                                anyRouteFound = true
                                self.availableRoutes[TransportTypeKey(transportType)] = route
                                
                                // すべての交通手段を試し終わった場合、最速のルートを選択
                                if remainingTypesCount == 0 {
                                    self.selectFastestRoute()
                                }
                            }
                            
                            // すべての交通手段を試し終わり、どのルートも見つからなかった場合
                            if remainingTypesCount == 0 && !anyRouteFound {
                                DispatchQueue.main.async {
                                    self.errorMessage = ErrorMessage(message: "経路検索エラー：経路を検索できません。目的地が到達不可能です。")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func selectFastestRoute() {
        guard !availableRoutes.isEmpty else {
            print("利用可能なルートがありません")
            return
        }
        
        // 利用可能なルートの情報をログに出力
        print("デバッグ: 利用可能なルート一覧:")
        for (typeKey, route) in availableRoutes {
            let distance = String(format: "%.1f", route.distance / 1000)
            let time = Int(route.expectedTravelTime / 60)
            print("- \(transportTypeName(typeKey.transportType)): 距離 \(distance)km, 所要時間 \(time)分")
        }
        
        // 最速のルートを探す
        var fastestRoute: (type: MKDirectionsTransportType, route: MKRoute)? = nil
        
        for (typeKey, route) in availableRoutes {
            if fastestRoute == nil || route.expectedTravelTime < fastestRoute!.route.expectedTravelTime {
                fastestRoute = (typeKey.transportType, route)
            }
        }
        
        if let fastest = fastestRoute {
            let distance = String(format: "%.1f", fastest.route.distance / 1000)
            let time = Int(fastest.route.expectedTravelTime / 60)
            print("デバッグ: 最速のルート - 交通手段: \(transportTypeName(fastest.type)), 距離: \(distance)km, 予想所要時間: \(time)分")
            self.route = fastest.route
            self.selectedTransportType = fastest.type
        }
    }
    
    func selectLocation(_ location: Location) {
        // 同じ場所を再度選択した場合は何もしない
        if let selected = selectedLocation, selected.id == location.id {
            return
        }
        
        selectedLocation = location
        
        // ユーザーの現在地が取得できている場合のみ経路を計算
        if userLocation != nil {
            calculateRoute()
        }
    }
    
    // 特定の交通手段を手動で選択するメソッド
    func selectTransportType(_ type: MKDirectionsTransportType) {
        guard let route = availableRoutes[TransportTypeKey(type)] else {
            print("指定された交通手段 (\(transportTypeName(type))) のルートは利用できません")
            errorMessage = ErrorMessage(message: "\(transportTypeName(type))でのルートは利用できません")
            return
        }
        
        print("交通手段を変更: \(transportTypeName(type))")
        self.route = route
        self.selectedTransportType = type
    }
    
    func tryCalculateRoute(sourceMapItem: MKMapItem, destinationMapItem: MKMapItem, transportType: MKDirectionsTransportType, completion: @escaping (Bool, MKRoute?) -> Void) {
        let request = MKDirections.Request()
        request.source = sourceMapItem
        request.destination = destinationMapItem
        request.transportType = transportType
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        
        // リクエストリストに追加して追跡
        directionsRequests.append(directions)
        
        directions.calculate { [weak self] response, error in
            guard let self = self else {
                completion(false, nil)
                return
            }
            
            // 完了後、リクエストリストから削除
            if let index = self.directionsRequests.firstIndex(where: { $0 === directions }) {
                self.directionsRequests.remove(at: index)
            }
            
            if let error = error {
                print("経路検索エラー (\(transportType)): \(error)")
                completion(false, nil)
                return
            }
            
            guard let response = response, !response.routes.isEmpty else {
                print("経路が見つかりませんでした (\(transportType))")
                completion(false, nil)
                return
            }
            
            // 交通手段ごとに最速ルートを選択
            if let bestRoute = response.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) {
                print("デバッグ: \(transportType)での経路が見つかりました - 予想所要時間: \(Int(bestRoute.expectedTravelTime / 60))分")
                completion(true, bestRoute)
            } else {
                print("デバッグ: \(transportType)での経路が見つかりました")
                completion(true, response.routes.first)
            }
        }
    }
    
    // 座標を最寄りの道路にスナップする関数
    func snapToRoad(coordinate: CLLocationCoordinate2D, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        _ = MKPlacemark(coordinate: coordinate)
        // 未使用の変数を削除
        // または必要に応じて _ = MKMapItem(placemark: location) として使用
        
        // MKMapItemを使って最寄りの道路を検索
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "道路"
        request.region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
        
        let search = MKLocalSearch(request: request)
        
        // リクエストリストに追加して追跡
        localSearchRequests.append(search)
        
        search.start { [weak self] response, error in
            guard let self = self else { 
                completion(nil)
                return 
            }
            
            // 完了後、リクエストリストから削除
            if let index = self.localSearchRequests.firstIndex(where: { $0 === search }) {
                self.localSearchRequests.remove(at: index)
            }
            
            guard let response = response, let nearestItem = response.mapItems.first else {
                print("道路へのスナップに失敗しました: \(error?.localizedDescription ?? "不明なエラー")")
                completion(nil)
                return
            }
            
            completion(nearestItem.placemark.coordinate)
        }
    }
    
    // 交通手段の名前を取得するヘルパーメソッド
    func transportTypeName(_ type: MKDirectionsTransportType) -> String {
        // if-else文を使用して警告を回避
        if type == .automobile {
            return "車"
        } else if type == .walking {
            return "徒歩"
        } else if type == .transit {
            return "公共交通機関"
        } else if type == .any {
            return "任意"
        } else {
            return "不明"
        }
    }
    
    // すべての経路計算リクエストをキャンセルする
    private func cancelAllDirectionsRequests() {
        for request in directionsRequests {
            request.cancel()
        }
        directionsRequests.removeAll()
        print("デバッグ: すべての経路計算リクエストをキャンセルしました")
    }
    
    // すべてのローカルサーチリクエストをキャンセルする
    private func cancelAllLocalSearchRequests() {
        for request in localSearchRequests {
            request.cancel()
        }
        localSearchRequests.removeAll()
        print("デバッグ: すべてのローカルサーチリクエストをキャンセルしました")
    }
}

extension LocationViewModel: CLLocationManagerDelegate {
    @objc func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 位置情報の精度をデバッグ出力
        print("デバッグ: 位置情報更新 - 精度: \(location.horizontalAccuracy)m")
        
        // 位置情報の精度に関わらず、とりあえず位置情報を更新
        // 精度の低い位置情報でも、完全に位置情報がない状態より良い
        let newCoordinate = location.coordinate
        let previousLocation = userLocation
        userLocation = newCoordinate
        
        // 精度に関するログ
        if location.horizontalAccuracy <= 10 {
            print("デバッグ: 高精度な位置情報を取得しました (精度: \(location.horizontalAccuracy)m)")
        } else if location.horizontalAccuracy <= 100 {
            print("デバッグ: まあまあの精度の位置情報です (精度: \(location.horizontalAccuracy)m)")
        } else {
            print("デバッグ: 低精度の位置情報です (精度: \(location.horizontalAccuracy)m)")
        }
        
        // 選択済みの場所があれば経路を計算
        // 1. 初めての位置取得時
        // 2. 選択された場所が変更された時
        // 3. 現在位置が大きく変わった時（10m以上）
        if selectedLocation != nil {
            let needsRecalculation: Bool
            
            if previousLocation == nil {
                // 初めての位置取得
                needsRecalculation = true
            } else if let previous = previousLocation {
                // 前回の位置から10m以上移動した場合
                let previousCLLocation = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
                let currentCLLocation = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
                needsRecalculation = previousCLLocation.distance(from: currentCLLocation) > 10
            } else {
                needsRecalculation = false
            }
            
            if needsRecalculation {
                calculateRoute()
            }
        }
    }
    
    @objc func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置情報取得エラー: \(error.localizedDescription)")
        
        // 位置情報が取得できなかった場合のフォールバック
        // シミュレータでテスト中やGPS信号が弱い場合に便利
        if userLocation == nil {
            // 東京駅をデフォルトの位置として使用
            let defaultLocation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
            print("デバッグ: デフォルトの位置（東京駅）を使用します")
            userLocation = defaultLocation
            
            // ユーザーに通知
            errorMessage = ErrorMessage(message: "現在地を特定できないため、デフォルトの位置（東京駅）を使用します。実際の位置情報を使用するには、位置情報の許可と良好なGPS信号が必要です。")
        } else {
            errorMessage = ErrorMessage(message: "位置情報の更新に失敗しました: \(error.localizedDescription)")
        }
    }
    
    @objc func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("デバッグ: 位置情報の許可状態が変更されました: \(manager.authorizationStatus.rawValue)")
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            locationStatus = .authorizedWhenInUse
            print("デバッグ: 位置情報の使用が許可されました（使用中のみ）")
            manager.startUpdatingLocation()
            
        case .authorizedAlways:
            locationStatus = .authorizedAlways
            print("デバッグ: 位置情報の使用が許可されました（常に）")
            manager.startUpdatingLocation()
            
        case .denied:
            locationStatus = .denied
            print("デバッグ: 位置情報の使用が拒否されました")
            errorMessage = ErrorMessage(message: "位置情報の使用が許可されていないため、経路検索ができません。設定アプリから「プライバシーとセキュリティ > 位置情報サービス」で許可してください。")
            
            // デフォルトの位置を設定（東京駅）
            userLocation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
            
        case .restricted:
            print("デバッグ: 位置情報の使用が制限されています")
            errorMessage = ErrorMessage(message: "位置情報の使用に制限があります。このアプリの位置情報アクセスを許可するには、設定アプリから「プライバシーとセキュリティ > 位置情報サービス」で変更してください。")
            locationStatus = .restricted
            
        case .notDetermined:
            print("デバッグ: 位置情報の許可状態が未決定です")
            manager.requestWhenInUseAuthorization()
            locationStatus = .notDetermined
            
        @unknown default:
            print("デバッグ: 不明な位置情報の許可状態です")
            locationStatus = .unknown
            break
        }
    }
}

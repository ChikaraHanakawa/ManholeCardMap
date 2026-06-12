//
//  LocationViewModel+Location.swift
//  ManholeCardMap
//
//  位置情報（GPS）の取得と許可状態の管理
//
import SwiftUI
import CoreLocation

extension LocationViewModel {

    // 位置情報の許可状態
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

    func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // 10m移動ごとに更新
        locationManager.activityType = .automotiveNavigation // 車両ナビゲーション用に最適化
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
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
        }
    }
}

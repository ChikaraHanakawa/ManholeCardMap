//
//  LocationViewModel+Routing.swift
//  ManholeCardMap
//
//  経路計算（車・徒歩）と交通機関の純正マップ連携
//
import Foundation
import MapKit
import CoreLocation

extension LocationViewModel {

    func calculateRoute() {
        print("デバッグ: calculateRoute() が呼び出されました")

        // 新しい経路計算を始める前に、以前のリクエストをすべてキャンセル
        cancelAllDirectionsRequests()
        cancelAllLocalSearchRequests()

        // 現在位置の確認とデバッグ情報の出力
        guard let userLocation = userLocation else {
            print("デバッグ: 現在位置が取得できていません - locationStatus: \(locationStatus)")
            errorMessage = ErrorMessage(message: "現在地を特定できません。位置情報の使用を許可して、GPSの電波が届く場所にいることを確認してください。\n\n現在の状態: \(locationStatus.description)")
            return
        }

        guard let selectedLocation = selectedLocation else {
            print("デバッグ: 目的地が選択されていません")
            errorMessage = ErrorMessage(message: "目的地が設定されていません。マンホールカード一覧から目的地を選択してください。")
            return
        }

        print("デバッグ: 現在位置 - 緯度: \(userLocation.latitude), 経度: \(userLocation.longitude)")
        print("デバッグ: 目的地 - \(selectedLocation.title) - 緯度: \(selectedLocation.coordinate.latitude), 経度: \(selectedLocation.coordinate.longitude)")

        // 座標が有効かチェック
        if !CLLocationCoordinate2DIsValid(userLocation) {
            print("デバッグ: 現在位置の座標が無効です")
            errorMessage = ErrorMessage(message: "現在地の座標が無効です")
            return
        }

        if !CLLocationCoordinate2DIsValid(selectedLocation.coordinate) {
            print("デバッグ: 目的地の座標が無効です")
            errorMessage = ErrorMessage(message: "目的地の座標が無効です")
            return
        }

        // 距離の計算と検証
        let startLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let endLocation = CLLocation(latitude: selectedLocation.coordinate.latitude, longitude: selectedLocation.coordinate.longitude)
        let distanceInMeters = startLocation.distance(from: endLocation)
        let distanceInKm = distanceInMeters / 1000

        print("デバッグ: 直線距離 - \(String(format: "%.2f", distanceInKm))km (\(String(format: "%.0f", distanceInMeters))m)")

        // 距離が近すぎる場合は警告（50メートル以内）
        if distanceInMeters < 50 {
            errorMessage = ErrorMessage(message: "現在地と目的地が近すぎます（\(String(format: "%.0f", distanceInMeters))m）。もう少し離れた場所を選択してください。")
            return
        }

        // 距離が遠すぎる場合は警告（500km以上）
        if distanceInKm > 500 {
            errorMessage = ErrorMessage(message: "目的地が遠すぎます（約\(String(format: "%.0f", distanceInKm))km）。経路検索に時間がかかるか、失敗する可能性があります。")
            // 警告を表示するが、経路検索は続行する
        }

        // 経路計算を実行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            print("デバッグ: 経路計算を開始します")

            // 既存の経路をクリア
            self.route = nil
            self.availableRoutes.removeAll()

            let sourcePlacemark = MKPlacemark(coordinate: userLocation, addressDictionary: nil)
            let destinationPlacemark = MKPlacemark(coordinate: selectedLocation.coordinate, addressDictionary: nil)

            let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
            let destinationMapItem = MKMapItem(placemark: destinationPlacemark)

            // 複数の交通手段を試す（優先順位順）
            // 交通機関(.transit)はMKDirectionsの経路計算に非対応のため、純正マップアプリに任せる
            let transportTypes: [MKDirectionsTransportType] = [.automobile, .walking]
            var completedCount = 0
            var anyRouteFound = false
            var errorCount = 0

            print("デバッグ: \(transportTypes.count)種類の交通手段で経路検索を試行します")

            // 各交通手段でルート検索を行う
            for (_, transportType) in transportTypes.enumerated() {
                print("デバッグ: \(transportTypeName(transportType))での経路検索を開始")

                self.tryCalculateRoute(sourceMapItem: sourceMapItem, destinationMapItem: destinationMapItem, transportType: transportType) { [weak self] success, route in
                    guard let self = self else { return }

                    completedCount += 1
                    print("デバッグ: \(transportTypeName(transportType))の結果 - 成功: \(success), 完了数: \(completedCount)/\(transportTypes.count)")

                    if success, let route = route {
                        anyRouteFound = true
                        self.availableRoutes[TransportTypeKey(transportType)] = route
                        print("デバッグ: \(transportTypeName(transportType))のルートを保存しました")
                    } else {
                        errorCount += 1
                        print("デバッグ: \(transportTypeName(transportType))の経路検索に失敗しました")
                    }

                    // すべての交通手段を試し終わった場合
                    if completedCount == transportTypes.count {
                        print("デバッグ: すべての交通手段の検索が完了 - 成功: \(anyRouteFound), エラー数: \(errorCount)")

                        if anyRouteFound {
                            self.selectFastestRoute()
                        } else {
                            DispatchQueue.main.async {
                                let errorMsg = "経路を見つけることができませんでした。\n\n考えられる原因:\n• ネットワーク接続の問題\n• 目的地が到達不可能\n• Mapサービスの一時的な問題\n\n距離: \(String(format: "%.1f", distanceInKm))km"
                                self.errorMessage = ErrorMessage(message: errorMsg)
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

    // 交通機関の経路はMapKitで計算できないため、純正マップアプリで開く
    func openTransitInMaps() {
        guard let selectedLocation = selectedLocation else {
            errorMessage = ErrorMessage(message: "目的地が設定されていません。マンホールカード一覧から目的地を選択してください。")
            return
        }

        let placemark = MKPlacemark(coordinate: selectedLocation.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = selectedLocation.title

        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit
        ])
    }

    // 経路をクリアするメソッド
    func clearRoute() {
        print("デバッグ: 経路をクリアします")

        // すべての経路関連データをクリア
        route = nil
        availableRoutes.removeAll()
        selectedLocation = nil

        // 進行中のリクエストもキャンセル
        cancelAllDirectionsRequests()
        cancelAllLocalSearchRequests()

        // エラーメッセージもクリア
        errorMessage = nil
    }

    func tryCalculateRoute(sourceMapItem: MKMapItem, destinationMapItem: MKMapItem, transportType: MKDirectionsTransportType, completion: @escaping (Bool, MKRoute?) -> Void) {
        let request = MKDirections.Request()
        request.source = sourceMapItem
        request.destination = destinationMapItem
        request.transportType = transportType
        request.requestsAlternateRoutes = false  // 最初は代替ルートを無効にして高速化

        let directions = MKDirections(request: request)

        // リクエストリストに追加して追跡
        directionsRequests.append(directions)

        print("デバッグ: \(transportTypeName(transportType))の経路計算リクエストを送信")

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
                print("デバッグ: \(transportTypeName(transportType))の経路検索エラー - \(error.localizedDescription)")
                completion(false, nil)
                return
            }

            guard let response = response, !response.routes.isEmpty else {
                print("デバッグ: \(transportTypeName(transportType))の経路が見つかりませんでした")
                completion(false, nil)
                return
            }

            let bestRoute = response.routes.first!
            let distance = String(format: "%.1f", bestRoute.distance / 1000)
            let time = Int(bestRoute.expectedTravelTime / 60)
            print("デバッグ: \(transportTypeName(transportType))の経路取得成功 - 距離: \(distance)km, 時間: \(time)分")

            completion(true, bestRoute)
        }
    }

    // 座標を最寄りの道路にスナップする関数
    func snapToRoad(coordinate: CLLocationCoordinate2D, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
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
    func cancelAllDirectionsRequests() {
        for request in directionsRequests {
            request.cancel()
        }
        directionsRequests.removeAll()
        print("デバッグ: すべての経路計算リクエストをキャンセルしました")
    }

    // すべてのローカルサーチリクエストをキャンセルする
    func cancelAllLocalSearchRequests() {
        for request in localSearchRequests {
            request.cancel()
        }
        localSearchRequests.removeAll()
        print("デバッグ: すべてのローカルサーチリクエストをキャンセルしました")
    }
}

//
//  ContentView.swift
//  ManholeCardMap
//
//  Created by ChikaraHanakawa on 2025/04/18.
//
import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var viewModel = LocationViewModel()
    @State private var position: MapCameraPosition = .automatic
    @State private var showLocationList = false
    @State private var showDebugInfo = false
    @State private var showAllMarkers = true // マーカー表示制御用
    
    var body: some View {
        ZStack {
            Map(position: $position) {
                // マンホールカードの位置を地域ごとに色分け
                // 経路表示中は選択された場所以外のマーカーを非表示にするオプション
                ForEach(viewModel.locations) { location in
                    if showAllMarkers || viewModel.selectedLocation?.id == location.id {
                        if viewModel.selectedLocation?.id == location.id {
                            Marker(location.title, coordinate: location.coordinate)
                                .tint(.red) // 選択中は赤色
                        } else {
                            Marker(location.title, coordinate: location.coordinate)
                                .tint(location.region.color)
                        }
                    }
                }
                
                // 選択された場所には特別なマーカーと情報を表示
                if let selectedLocation = viewModel.selectedLocation {
                    Annotation(selectedLocation.title, coordinate: selectedLocation.coordinate) {
                        VStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                            Text(selectedLocation.title)
                                .font(.caption)
                                .padding(5)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(5)
                        }
                    }
                }
                
                // 経路の表示
                if let route = viewModel.route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 5)
                }
                
                // 改良版ユーザーの現在地表示
                UserAnnotation()
            }
            .mapStyle(.standard)
            .mapControls {
                // コントロールの位置を調整（中央よりに配置）
                MapUserLocationButton()
                    .padding(.trailing) // 右端からのパディングを増やして中央よりに
                    .buttonBorderShape(.circle)
                
                MapCompass()
                    .padding(.trailing, 40) // 右端からのパディングを増やして中央よりに
                
                MapScaleView()
            }
            .onAppear {
                // 日本全体を表示
                position = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
                        span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
                    )
                )
                
                // デバッグ: 位置情報の状態を確認
                print("デバッグ: アプリ起動時の位置情報状態 - \(viewModel.locationStatus)")
            }
            .onChange(of: viewModel.route) { _, newRoute in
                // 経路が更新されたときの処理
                if let route = newRoute {
                    // 経路表示時は他のマーカーを非表示にする
                    showAllMarkers = false
                    
                    // 経路全体が見えるようにカメラ位置を調整
                    let rect = route.polyline.boundingMapRect
                    let region = MKCoordinateRegion(rect)
                    
                    // 少し余裕を持たせるためにspanを拡大
                    let expandedRegion = MKCoordinateRegion(
                        center: region.center,
                        span: MKCoordinateSpan(
                            latitudeDelta: region.span.latitudeDelta * 1.3,
                            longitudeDelta: region.span.longitudeDelta * 1.3
                        )
                    )
                    
                    // アニメーション付きでカメラ位置を更新
                    withAnimation(.easeInOut(duration: 1.0)) {
                        position = .region(expandedRegion)
                    }
                } else {
                    // 経路がクリアされたときは全マーカーを表示
                    showAllMarkers = true
                }
            }
            
            VStack {
                // 位置情報とデバッグ情報の表示
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: viewModel.locationStatus.icon)
                            .foregroundColor(viewModel.locationStatus.color)
                        Text("位置情報: \(viewModel.locationStatus.description)")
                            .font(.system(size: 12))
                        
                        Spacer()
                        
                        // マーカー表示切り替えボタン（経路表示中のみ表示）
                        if viewModel.route != nil {
                            Button(action: {
                                showAllMarkers.toggle()
                            }) {
                                Image(systemName: showAllMarkers ? "eye.fill" : "eye.slash.fill")
                                    .foregroundColor(showAllMarkers ? .green : .gray)
                            }
                        }
                        
                        // デバッグ情報トグルボタン
                        Button(action: {
                            showDebugInfo.toggle()
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(5)
                    .padding(.horizontal)
                    .padding(.top, 5)
                    
                    // デバッグ情報の表示
                    if showDebugInfo {
                        VStack(alignment: .leading, spacing: 2) {
                            if let userLocation = viewModel.userLocation {
                                Text("現在地: \(String(format: "%.4f", userLocation.latitude)), \(String(format: "%.4f", userLocation.longitude))")
                                    .font(.system(size: 10))
                            } else {
                                Text("現在地: 未取得")
                                    .font(.system(size: 10))
                            }
                            
                            if let selectedLocation = viewModel.selectedLocation {
                                Text("目的地: \(selectedLocation.title)")
                                    .font(.system(size: 10))
                                Text("座標: \(String(format: "%.4f", selectedLocation.coordinate.latitude)), \(String(format: "%.4f", selectedLocation.coordinate.longitude))")
                                    .font(.system(size: 10))
                            } else {
                                Text("目的地: 未選択")
                                    .font(.system(size: 10))
                            }
                            
                            Text("利用可能ルート: \(viewModel.availableRoutes.count)件")
                                .font(.system(size: 10))
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(5)
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // 経路情報表示エリア
                if let route = viewModel.route {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("\(viewModel.selectedLocation?.title ?? "目的地") までの経路")
                                .font(.headline)
                            
                            Spacer()
                            
                            // 経路をクリアするボタン
                            Button(action: {
                                viewModel.clearRoute()
                                showAllMarkers = true
                                
                                // 日本全体に戻る
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    position = .region(
                                        MKCoordinateRegion(
                                            center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
                                            span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
                                        )
                                    )
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Text("距離: \(formatDistance(route.distance))")
                        Text("所要時間: \(formatTime(route.expectedTravelTime))")
                        
                        // 交通手段の表示
                        HStack {
                            Text("交通手段: \(viewModel.transportTypeName(viewModel.selectedTransportType))")
                            
                            Spacer()
                            
                            // 他の交通手段がある場合、切り替えボタンを表示
                            if viewModel.availableRoutes.count > 1 {
                                Menu {
                                    // 交通手段のIDと値のペアを使用して明示的にHashableに準拠させる
                                    ForEach([
                                        (id: 0, type: MKDirectionsTransportType.automobile),
                                        (id: 1, type: MKDirectionsTransportType.walking),
                                        (id: 2, type: MKDirectionsTransportType.transit)
                                    ], id: \.id) { pair in
                                        let type = pair.type
                                        if viewModel.availableRoutes[TransportTypeKey(type)] != nil && type != viewModel.selectedTransportType {
                                            Button(action: {
                                                viewModel.selectTransportType(type)
                                            }) {
                                                Label(viewModel.transportTypeName(type), systemImage: transportTypeIcon(type))
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "arrow.triangle.swap")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .padding()
                }
                
                // 場所一覧ボタン
                Button(action: {
                    showLocationList.toggle()
                }) {
                    Text("マンホールカード一覧")
                        .font(.system(size: 16, weight: .medium))
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                }
                .padding(.bottom)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .sheet(isPresented: $showLocationList) {
            LocationListView(viewModel: viewModel, isPresented: $showLocationList)
        }
        .alert(item: $viewModel.errorMessage) { errorMessage in
            Alert(
                title: Text("エラー"),
                message: Text(errorMessage.message),
                primaryButton: .default(Text("OK")),
                secondaryButton: .cancel(Text("別の場所を選択")) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showLocationList = true
                    }
                }
            )
        }
    }
    
    func transportTypeIcon(_ type: MKDirectionsTransportType) -> String {
        // Use if-else instead of switch to avoid exhaustiveness warnings
        if type == .automobile {
            return "car.fill"
        } else if type == .walking {
            return "figure.walk"
        } else if type == .transit {
            return "tram.fill"
        } else {
            // Handles .any and any future cases
            return "map"
        }
    }
    
    func formatDistance(_ distance: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .medium
        
        let measurement = Measurement(value: distance, unit: UnitLength.meters)
        return formatter.string(from: measurement)
    }
    
    func formatTime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "不明"
    }
}

struct LocationListView: View {
    @ObservedObject var viewModel: LocationViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""
    
    var filteredLocations: [Location] {
        if searchText.isEmpty {
            return viewModel.locations
        } else {
            return viewModel.locations.filter { $0.title.contains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            List(filteredLocations) { location in
                Button(action: {
                    // まずシートを閉じる
                    isPresented = false
                    
                    // 少し遅延させてから場所の選択と経路計算を行う
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // メソッド呼び出しをインラインのコードに置き換え
                        let selectedLocation = location
                        // 同じ場所を再度選択した場合は何もしない
                        if viewModel.selectedLocation?.id != selectedLocation.id {
                            // 既存のエラーメッセージをクリア
                            viewModel.errorMessage = nil
                            
                            viewModel.selectedLocation = selectedLocation
                            // ユーザーの現在地が取得できている場合のみ経路を計算
                            if viewModel.userLocation != nil {
                                viewModel.calculateRoute()
                            }
                        }
                    }
                }) {
                    HStack {
                        // 地域の色を表すカラーインジケーター
                        Circle()
                            .fill(location.region.color)
                            .frame(width: 14, height: 14)
                        
                        Text(location.title)
                            .font(.system(size: 16))
                        
                        Spacer()
                        
                        // 都道府県名を表示
                        Text(location.prefecture)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("マンホールカード一覧")
            .searchable(text: $searchText, prompt: "検索")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

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
    
    var body: some View {
        ZStack {
            Map(position: $position) {
                // マンホールカードの位置を地域ごとに色分け
                ForEach(viewModel.locations) { location in
                    if viewModel.selectedLocation?.id == location.id {
                        Marker(location.title, coordinate: location.coordinate)
                            .tint(.red) // 選択中は赤色
                    } else {
                        Marker(location.title, coordinate: location.coordinate)
                            .tint(location.region.color)
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
            .mapStyle(.standard) // マップスタイルを明示的に指定
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
            }
            
            VStack {
                // 位置情報の状態を表示するインジケーター
                if viewModel.userLocation != nil {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                        Text("位置情報: 取得済み")
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(5)
                    .padding(.horizontal)
                    .padding(.top, 5)
                } else {
                    HStack {
                        Image(systemName: "location.slash.fill")
                            .foregroundColor(.red)
                        Text("位置情報: 未取得")
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(5)
                    .padding(.horizontal)
                    .padding(.top, 5)
                }
                
                Spacer()
                
                // 経路情報表示エリア
                if let route = viewModel.route {
                    VStack(alignment: .leading) {
                        Text("\(viewModel.selectedLocation?.title ?? "目的地") までの経路")
                            .font(.headline)
                        
                        Text("距離: \(formatDistance(route.distance))")
                        Text("所要時間: \(formatTime(route.expectedTravelTime))")
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
                    // アラートを閉じた後、少し遅延させてから場所リストを表示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showLocationList = true
                    }
                }
            )
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

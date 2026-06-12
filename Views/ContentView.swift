//
//  ContentView.swift
//  ManholeCardMap
//
//  メイン画面（地図・経路情報パネル・下部ボタン）
//
import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @StateObject private var viewModel = LocationViewModel()
    @State private var position: MapCameraPosition = .automatic
    @State private var showLocationList = false
    @State private var showDebugInfo = false
    @State private var showAllMarkers = true
    @State private var showFilterSheet = false
    @State private var selectedMapDetailLocation: Location?

    var body: some View {
        ZStack {
            Map(position: $position) {
                ForEach(viewModel.filteredLocations) { location in
                    if showAllMarkers || viewModel.selectedLocation?.id == location.id {
                        if viewModel.selectedLocation?.id == location.id {
                            Marker(location.title, coordinate: location.coordinate)
                                .tint(.red)
                        } else {
                            // 収集済みはグレー、未収集は地域カラー
                            Marker(location.title, coordinate: location.coordinate)
                                .tint(viewModel.isCollected(location) ? .gray : location.region.color)
                        }
                    }
                }

                if let sel = viewModel.selectedLocation {
                    Annotation(sel.title, coordinate: sel.coordinate) {
                        VStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                            Text(sel.title)
                                .font(.caption)
                                .padding(5)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(5)
                        }
                    }
                }

                if let route = viewModel.route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 5)
                }

                UserAnnotation()
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onAppear {
                position = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
                        span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
                    )
                )
                print("デバッグ: アプリ起動時の位置情報状態 - \(viewModel.locationStatus)")
            }
            .onChange(of: viewModel.route) { _, newRoute in
                if let route = newRoute {
                    showAllMarkers = false
                    let rect = route.polyline.boundingMapRect
                    let region = MKCoordinateRegion(rect)
                    let expanded = MKCoordinateRegion(
                        center: region.center,
                        span: MKCoordinateSpan(
                            latitudeDelta: region.span.latitudeDelta * 1.3,
                            longitudeDelta: region.span.longitudeDelta * 1.3
                        )
                    )
                    withAnimation(.easeInOut(duration: 1.0)) { position = .region(expanded) }
                } else {
                    showAllMarkers = true
                }
            }

            VStack {
                // 位置情報ステータスバー
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: viewModel.locationStatus.icon)
                            .foregroundColor(viewModel.locationStatus.color)
                        Text("位置情報: \(viewModel.locationStatus.description)")
                            .font(.system(size: 12))
                        Spacer()
                        if viewModel.route != nil {
                            Button(action: { showAllMarkers.toggle() }) {
                                Image(systemName: showAllMarkers ? "eye.fill" : "eye.slash.fill")
                                    .foregroundColor(showAllMarkers ? .green : .gray)
                            }
                        }
                        Button(action: { showDebugInfo.toggle() }) {
                            Image(systemName: "info.circle").foregroundColor(.blue)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(5)
                    .padding(.horizontal)
                    .padding(.top, 5)

                    if showDebugInfo {
                        VStack(alignment: .leading, spacing: 2) {
                            if let ul = viewModel.userLocation {
                                Text("現在地: \(String(format: "%.4f", ul.latitude)), \(String(format: "%.4f", ul.longitude))")
                                    .font(.system(size: 10))
                            } else {
                                Text("現在地: 未取得").font(.system(size: 10))
                            }
                            if let sel = viewModel.selectedLocation {
                                Text("目的地: \(sel.title)").font(.system(size: 10))
                                Text("座標: \(String(format: "%.4f", sel.coordinate.latitude)), \(String(format: "%.4f", sel.coordinate.longitude))")
                                    .font(.system(size: 10))
                            } else {
                                Text("目的地: 未選択").font(.system(size: 10))
                            }
                            Text("利用可能ルート: \(viewModel.availableRoutes.count)件").font(.system(size: 10))
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(5)
                        .padding(.horizontal)
                    }
                }

                Spacer()

                // 経路情報パネル
                if let route = viewModel.route {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(viewModel.selectedLocation?.title ?? "目的地") までの経路")
                                .font(.headline)
                            Spacer()
                            // 詳細ボタン
                            if let sel = viewModel.selectedLocation {
                                Button(action: { selectedMapDetailLocation = sel }) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                            Button(action: {
                                viewModel.clearRoute()
                                showAllMarkers = true
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    position = .region(
                                        MKCoordinateRegion(
                                            center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
                                            span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
                                        )
                                    )
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                            }
                        }
                        Text("距離: \(formatDistance(route.distance))")
                        Text("所要時間: \(formatTime(route.expectedTravelTime))")
                        HStack {
                            Text("交通手段: \(viewModel.transportTypeName(viewModel.selectedTransportType))")
                            Spacer()
                            Menu {
                                ForEach([
                                    (id: 0, type: MKDirectionsTransportType.automobile),
                                    (id: 1, type: MKDirectionsTransportType.walking)
                                ], id: \.id) { pair in
                                    let type = pair.type
                                    if viewModel.availableRoutes[TransportTypeKey(type)] != nil && type != viewModel.selectedTransportType {
                                        Button(action: { viewModel.selectTransportType(type) }) {
                                            Label(viewModel.transportTypeName(type), systemImage: transportTypeIcon(type))
                                        }
                                    }
                                }
                                // 交通機関はMapKitで経路計算できないため、純正マップアプリで開く
                                Button(action: { viewModel.openTransitInMaps() }) {
                                    Label("交通機関（マップで開く）", systemImage: "tram.fill")
                                }
                            } label: {
                                Image(systemName: "arrow.triangle.swap").foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                // 下部ボタン群（Spacerで等間隔）
                HStack {
                    Spacer()

                    // 絞り込みボタン（バッジ付き）
                    Button(action: { showFilterSheet = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 22))
                                .foregroundColor(viewModel.hasActiveFilters ? .blue : .primary)
                                .padding(14)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                            if viewModel.activeFilterCount > 0 {
                                Text("\(viewModel.activeFilterCount)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }

                    Spacer()

                    Button(action: { showLocationList.toggle() }) {
                        Text("マンホールカード一覧")
                            .font(.system(size: 16, weight: .medium))
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                    }

                    Spacer()

                    // 現在地ボタン（カスタム実装）
                    Button(action: {
                        if let userLoc = viewModel.userLocation {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                position = .region(MKCoordinateRegion(
                                    center: userLoc,
                                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                ))
                            }
                        }
                    }) {
                        Image(systemName: viewModel.userLocation != nil ? "location.fill" : "location")
                            .font(.system(size: 22))
                            .foregroundColor(viewModel.userLocation != nil ? .blue : .gray)
                            .padding(14)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }

                    Spacer()
                }
                .padding(.bottom)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .sheet(isPresented: $showLocationList) {
            LocationListView(viewModel: viewModel, isPresented: $showLocationList)
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView(viewModel: viewModel, isPresented: $showFilterSheet)
        }
        .sheet(item: $selectedMapDetailLocation) { location in
            LocationDetailView(location: location, viewModel: viewModel, onNavigate: nil)
        }
        .alert(item: $viewModel.errorMessage) { err in
            Alert(
                title: Text("エラー"),
                message: Text(err.message),
                primaryButton: .default(Text("OK")),
                secondaryButton: .cancel(Text("別の場所を選択")) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showLocationList = true }
                }
            )
        }
    }

    func transportTypeIcon(_ type: MKDirectionsTransportType) -> String {
        if type == .automobile { return "car.fill" }
        else if type == .walking { return "figure.walk" }
        else if type == .transit { return "tram.fill" }
        else { return "map" }
    }

    func formatDistance(_ distance: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .medium
        return formatter.string(from: Measurement(value: distance, unit: UnitLength.meters))
    }

    func formatTime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "不明"
    }
}

#Preview {
    ContentView()
}

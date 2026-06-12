//
//  LocationDetailView.swift
//  ManholeCardMap
//
//  カード詳細画面（カード画像・配布情報・収集済みトグル・経路検索ボタン）
//
import SwiftUI
import CoreLocation

struct LocationDetailView: View {
    let location: Location
    @ObservedObject var viewModel: LocationViewModel
    var onNavigate: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var secureImageURL: URL? {
        URL(string: location.cardImageURL.replacingOccurrences(of: "http://", with: "https://"))
    }

    var distanceText: String? {
        guard let userLoc = viewModel.userLocation else { return nil }
        let user = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let dest = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let dist = user.distance(from: dest)
        if dist >= 1000 {
            return String(format: "現在地から約 %.1f km", dist / 1000)
        } else {
            return String(format: "現在地から約 %.0f m", dist)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // カード画像
                    if let url = secureImageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit().cornerRadius(8)
                            case .failure:
                                imagePlaceholder
                            case .empty:
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)).frame(height: 200)
                                    ProgressView()
                                }
                            @unknown default:
                                imagePlaceholder
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // 基本情報
                    VStack(alignment: .leading, spacing: 6) {
                        if !location.series.isEmpty {
                            Text(location.series)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        Text(location.municipality)
                            .font(.title2).fontWeight(.bold)
                        HStack(spacing: 4) {
                            Circle().fill(location.region.color).frame(width: 10, height: 10)
                            Text("\(location.region.rawValue) / \(location.prefecture)")
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        if let dist = distanceText {
                            Label(dist, systemImage: "location.circle")
                                .font(.subheadline).foregroundColor(.blue)
                        }
                    }

                    Divider()

                    // 配布情報
                    VStack(alignment: .leading, spacing: 10) {
                        DetailRow(icon: "mappin.circle", label: "配布場所", value: location.title)
                        if !location.distributionTime.isEmpty {
                            DetailRow(icon: "clock", label: "配布時間", value: location.distributionTime)
                        }
                        if !location.telephone.isEmpty {
                            DetailRow(icon: "phone", label: "電話番号", value: location.telephone)
                        }
                        if !location.note.isEmpty {
                            DetailRow(icon: "info.circle", label: "備考", value: location.note)
                        }
                    }

                    Divider()

                    // 収集済みトグル
                    let collected = viewModel.isCollected(location)
                    Button(action: { viewModel.toggleCollected(location) }) {
                        HStack {
                            Image(systemName: collected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(collected ? .green : .gray)
                            Text(collected ? "収集済み" : "未収集")
                                .fontWeight(.medium)
                            Spacer()
                            Text(collected ? "タップで解除" : "タップして記録")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(collected ? Color.green.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    // 経路検索ボタン
                    Button(action: {
                        dismiss()
                        onNavigate?()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            Text("ここへの経路を検索")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("カード詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray6))
            .frame(height: 200)
            .overlay(
                Image(systemName: "photo").font(.largeTitle).foregroundColor(.gray)
            )
    }
}

// アイコン付きの情報1行分の表示部品
struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption).foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
        }
    }
}

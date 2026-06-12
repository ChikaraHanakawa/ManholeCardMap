//
//  Models.swift
//  ManholeCardMap
//
//  アプリ全体で使うデータ型の定義
//
import SwiftUI
import MapKit
import CoreLocation

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

// マンホールカードの配布場所1件分のデータ
struct Location: Identifiable {
    let id = UUID()
    let title: String
    let coordinate: CLLocationCoordinate2D
    let prefecture: String
    let region: Region
    let municipality: String
    let telephone: String
    let distributionTime: String
    let note: String
    let cardImageURL: String
    let series: String
}

// 地方区分（地図のピンの色分けに使用）
enum Region: String, CaseIterable {
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

// アラート表示用のエラーメッセージ
struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
}

//
//  LocationViewModel+DataLoading.swift
//  ManholeCardMap
//
//  マンホールカードのデータ読み込み（JSON / CSV / サンプルデータ）
//
import Foundation
import CoreLocation

// JSONファイルの構造に対応するデコード用の型（このファイル内でのみ使用）
private struct ManholeCardJSON: Decodable {
    let municipality: String
    let card_image: String
    let series: String
    let publication_date: String
    let distributions: [DistributionJSON]
}

private struct DistributionJSON: Decodable {
    let type: String
    let place: String
    let place_url: String
    let address: String
    let telephone: String
    let distribution_time: String
    let location: LocationCoordinateJSON?
    let note: String
}

private struct LocationCoordinateJSON: Decodable {
    let lon: Double
    let lat: Double
}

extension LocationViewModel {

    // 都道府県名から地方区分を判定する
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

    // manhole_cards.jsonが見つからない場合のサンプルデータ
    func loadSampleData() {
        // JSON読み込みを試みる
        if !loadJSON() {
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
                    region: region,
                    municipality: "",
                    telephone: "",
                    distributionTime: "",
                    note: "",
                    cardImageURL: "",
                    series: ""
                )
                locations.append(location)
            }
        }
    }

    func loadJSON() -> Bool {
        guard let url = Bundle.main.url(forResource: "manhole_cards", withExtension: "json") else {
            print("manhole_cards.jsonが見つかりません")
            return false
        }

        do {
            let data = try Data(contentsOf: url)
            let cards = try JSONDecoder().decode([ManholeCardJSON].self, from: data)

            for card in cards {
                // addressが空の配布情報用に、同じカード内の他のaddressから都道府県を補完する
                let fallbackPrefecture = card.distributions
                    .compactMap { d -> String? in
                        let p = extractPrefecture(from: d.address)
                        return p.isEmpty ? nil : p
                    }
                    .first ?? ""

                for distribution in card.distributions {
                    guard let coord = distribution.location else { continue }

                    let prefecture = extractPrefecture(from: distribution.address)
                    let resolvedPrefecture = prefecture.isEmpty ? fallbackPrefecture : prefecture
                    let region = getRegion(from: resolvedPrefecture)

                    let location = Location(
                        title: distribution.place,
                        coordinate: CLLocationCoordinate2D(
                            latitude: coord.lat,
                            longitude: coord.lon
                        ),
                        prefecture: resolvedPrefecture,
                        region: region,
                        municipality: card.municipality,
                        telephone: distribution.telephone,
                        distributionTime: distribution.distribution_time,
                        note: distribution.note,
                        cardImageURL: card.card_image,
                        series: card.series
                    )
                    locations.append(location)
                }
            }
            print("JSON読み込み完了: \(locations.count)件")
            return true
        } catch {
            print("JSON読み込みエラー: \(error)")
            return false
        }
    }

    func extractPrefecture(from address: String) -> String {
        // 47都道府県への前方一致マッチング（「京都府」を「京都」と誤認しない）
        return Self.orderedPrefectures.first { address.hasPrefix($0) } ?? ""
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
                                region: region,
                                municipality: "",
                                telephone: "",
                                distributionTime: "",
                                note: "",
                                cardImageURL: "",
                                series: ""
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
}

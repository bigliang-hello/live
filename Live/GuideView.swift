import SwiftUI

struct HealthArticle: Identifiable {
    var id: String { section + title }
    let section: String
    let title: String
    let body: String

    var evidence: String? { value(after: "证据等级：") }
    var cost: String? { value(after: "成本：") }
    var benefit: String? { value(after: "收益：") }
    var source: String? { value(after: "来源：") }
    var note: String? { value(after: "备注：") }

    private func value(after marker: String) -> String? {
        body.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.hasPrefix("- \(marker)") }
            .map { String($0.dropFirst(marker.count + 2)) }
    }

    static func parse(_ markdown: String) -> [HealthArticle] {
        var result: [HealthArticle] = []
        var section = "", title = "", lines: [String] = []
        let allowed = ["1.", "2.", "3.", "6.", "16."]
        func append() {
            if !title.isEmpty && allowed.contains(where: { section.hasPrefix($0) }) {
                result.append(HealthArticle(section: section, title: title, body: lines.joined(separator: "\n")))
            }
        }
        for line in markdown.components(separatedBy: .newlines) {
            if line.hasPrefix("## ") {
                append(); title = ""; lines = []; section = String(line.dropFirst(3))
            } else if line.hasPrefix("### ") {
                append(); title = String(line.dropFirst(4)); lines = []
            } else if !line.hasPrefix("<!--"), line != "---" {
                lines.append(line)
            }
        }
        append()
        return result
    }
}

private struct HealthSection: Identifiable {
    let title: String
    let articles: [HealthArticle]
    var id: String { title }
    var shortTitle: String { title.split(separator: ".", maxSplits: 1).last.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? title }
    var number: String { title.split(separator: ".").first.map(String.init) ?? "" }
    var symbol: String {
        switch number {
        case "1": "shield.checkered"
        case "2": "heart.text.square"
        case "3": "battery.75percent"
        case "6": "cart.badge.questionmark"
        case "16": "cross.case"
        default: "book.closed"
        }
    }
}

struct GuideView: View {
    @AppStorage("guide.cachedMarkdown") private var cached = ""
    @AppStorage("guide.updated") private var updated = ""
    @State private var loading = false
    @State private var error: String?
    @State private var query = ""
    @State private var selection = "全部"
    @State private var articles: [HealthArticle] = []
    @State private var expandedArticle: String?
    private let repository = URL(string: "https://github.com/eternity4719/HowToLiveBetter")!

    private var allSections: [HealthSection] {
        Dictionary(grouping: articles, by: \.section)
            .map { HealthSection(title: $0.key, articles: $0.value) }
            .sorted { sectionNumber($0.title) < sectionNumber($1.title) }
    }

    private var visibleSections: [HealthSection] {
        allSections.compactMap { section in
            guard selection == "全部" || section.title == selection else { return nil }
            let matches = section.articles.filter {
                query.isEmpty || ($0.title + $0.body).localizedCaseInsensitiveContains(query)
            }
            return matches.isEmpty ? nil : HealthSection(title: section.title, articles: matches)
        }
    }

    private var resultCount: Int { visibleSections.reduce(0) { $0 + $1.articles.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            categoryGrid
            searchBar

            if loading { ProgressView("正在同步…") }
            if let error { Label(error, systemImage: "wifi.exclamationmark").foregroundStyle(.orange) }

            HStack {
                Text(selection == "全部" ? "全部健康主题" : selection)
                    .font(.title3.bold())
                Spacer()
                Text("\(resultCount) 条")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 20) {
                ForEach(visibleSections) { section in
                    sectionCard(section)
                }
            }

            if visibleSections.isEmpty {
                ContentUnavailableView("没有找到提示", systemImage: "magnifyingglass", description: Text("换个关键词，或选择全部主题。"))
            }

            Text("来源：eternity4719/HowToLiveBetter · Unlicense（公有领域）")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task { load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("好好生活，有据可查。")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("先按主题找到方向，再展开一条具体建议。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Link(destination: repository) { Label("原项目", systemImage: "arrow.up.right") }
                    Text(updated.isEmpty ? "内置快照 · 2026.09.08" : "同步于 \(updated)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Label("保留证据等级与来源", systemImage: "checkmark.seal")
                Text("·")
                Text("内容供了解，不替代个体诊疗建议")
                Spacer()
                Button { Task { await fetch() } } label: {
                    Label("同步", systemImage: "arrow.clockwise")
                }
                .disabled(loading)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(14)
            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
            spacing: 10
        ) {
            categoryButton(title: "全部", subtitle: "\(articles.count) 条", symbol: "square.grid.2x2")
            ForEach(allSections) { section in
                categoryButton(
                    title: section.title,
                    subtitle: "\(section.articles.count) 条细分建议",
                    symbol: section.symbol
                )
            }
        }
    }

    private func categoryButton(title: String, subtitle: String, symbol: String) -> some View {
        let selected = selection == title
        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                selection = title
                expandedArticle = nil
            }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 26)
                    .foregroundStyle(selected ? .white : Color(red: 0.18, green: 0.43, blue: 0.35))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title == "全部" ? title : title.split(separator: ".", maxSplits: 1).last.map(String.init) ?? title)
                        .font(.callout.bold())
                        .lineLimit(2)
                    Text(subtitle).font(.caption).opacity(0.75)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(13)
            .contentShape(Rectangle())
        }
        .buttonStyle(GuideCategoryStyle(selected: selected))
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("在当前主题中搜索建议、收益或来源…", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).stroke(Color.black.opacity(0.06)) }
    }

    private func sectionCard(_ section: HealthSection) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: section.symbol)
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.18, green: 0.43, blue: 0.35))
                    .frame(width: 42, height: 42)
                    .background(Color(red: 0.85, green: 0.92, blue: 0.86), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("主题 \(section.number)").font(.caption).foregroundStyle(.secondary)
                    Text(section.shortTitle).font(.title3.bold())
                }
                Spacer()
                Text("\(section.articles.count) 条")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.045), in: Capsule())
            }
            .padding(18)

            Divider().opacity(0.6)

            ForEach(Array(section.articles.enumerated()), id: \.element.id) { index, article in
                articleRow(article)
                if index < section.articles.count - 1 { Divider().padding(.leading, 68).opacity(0.45) }
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.black.opacity(0.045)) }
    }

    private func articleRow(_ article: HealthArticle) -> some View {
        let expanded = expandedArticle == article.id
        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    expandedArticle = expanded ? nil : article.id
                }
            } label: {
                HStack(spacing: 14) {
                    Text(itemNumber(article.title))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.04), in: Circle())
                    Text(cleanTitle(article.title))
                        .font(.system(size: 15, weight: .medium))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let evidence = article.evidence {
                        Text(evidence)
                            .font(.caption2.bold())
                            .foregroundStyle(evidence == "A" ? Color.green : Color.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((evidence == "A" ? Color.green : Color.gray).opacity(0.10), in: Capsule())
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("\(cleanTitle(article.title))，点击\(expanded ? "收起" : "展开")")

            if expanded {
                articleDetails(article)
                    .transition(.opacity)
            }
        }
        .background(expanded ? Color(red: 0.96, green: 0.98, blue: 0.96) : .clear)
    }

    private func articleDetails(_ article: HealthArticle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().opacity(0.5)
            if let cost = article.cost { detailBlock("要付出的", cost, "clock") }
            if let benefit = article.benefit { detailBlock("可能换回", benefit, "heart") }
            if let source = article.source { detailBlock("证据来源", source, "doc.text.magnifyingglass") }
            if let note = article.note { detailBlock("阅读备注", note, "note.text") }
        }
        .padding(.horizontal, 66)
        .padding(.bottom, 20)
        .textSelection(.enabled)
    }

    private func detailBlock(_ label: String, _ value: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .foregroundStyle(Color(red: 0.18, green: 0.43, blue: 0.35))
                .frame(width: 18)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                Text(label).font(.caption.bold()).foregroundStyle(.secondary)
                Text(.init(value)).font(.callout).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sectionNumber(_ title: String) -> Int {
        Int(title.split(separator: ".").first ?? "999") ?? 999
    }

    private func itemNumber(_ title: String) -> String {
        title.split(separator: ".").first.map(String.init) ?? "·"
    }

    private func cleanTitle(_ title: String) -> String {
        title.split(separator: ".", maxSplits: 1).last.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? title
    }

    private func load() {
        let bundled = Bundle.main.url(forResource: "HealthGuide", withExtension: "md")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        articles = HealthArticle.parse(cached.isEmpty ? bundled : cached)
    }

    private func fetch() async {
        loading = true; error = nil
        defer { loading = false }
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/eternity4719/HowToLiveBetter/readme")!)
            request.timeoutInterval = 20
            request.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let markdown = String(data: data, encoding: .utf8),
                  !HealthArticle.parse(markdown).isEmpty else { throw URLError(.cannotParseResponse) }
            cached = markdown
            updated = Date().formatted(date: .numeric, time: .shortened)
            selection = "全部"
            expandedArticle = nil
            load()
        } catch {
            self.error = "同步失败，仍显示已保存的指南。请检查网络后重试。"
        }
    }
}

private struct GuideCategoryStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? .white : Color.primary)
            .background(
                selected
                    ? Color(red: 0.16, green: 0.38, blue: 0.32)
                    : configuration.isPressed ? Color.black.opacity(0.055) : Color.white,
                in: RoundedRectangle(cornerRadius: 15)
            )
            .overlay { RoundedRectangle(cornerRadius: 15).stroke(Color.black.opacity(selected ? 0 : 0.05)) }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

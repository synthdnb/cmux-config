func projectName(_ dir: String) -> String {
    if dir.count == 0 {
        return "other"
    }
    let comps = dir.split(separator: "/")
    for comp in comps {
        if comp.hasSuffix("__worktrees") {
            return comp.replacingOccurrences(of: "__worktrees", with: "")
        }
    }
    for i in comps.indices {
        if comps[i] == "ws" {
            if i + 1 < comps.count {
                return comps[i + 1]
            }
        }
    }
    if let last = comps.last {
        return last
    }
    return "other"
}

let allProjectNames = workspaces.map { w in projectName(w.directory) }.sorted()

let uniqueProjectNames = allProjectNames.indices.filter { i in
    i == 0 || allProjectNames[i] != allProjectNames[i - 1]
}.map { i in allProjectNames[i] }

VStack(alignment: .leading, spacing: 8) {
    HStack {
        Text("Projects").font(.title3).bold()
        Spacer()
        Text("\(workspaceCount) sessions").font(.caption).foregroundColor(.secondary)
        if unreadTotal > 0 {
            Text("\(unreadTotal)")
                .font(.caption2)
                .foregroundColor("#FFFFFF")
                .padding(4)
                .background("#E0554D")
                .cornerRadius(8)
        }
    }
    Divider()
    if workspaces.count == 0 {
        Text("No sessions").foregroundColor(.secondary).font(.caption)
    } else {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(uniqueProjectNames) { project in
                    let projectWorkspaces = workspaces.filter { w in projectName(w.directory) == project }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill").imageScale(.small).foregroundColor(.secondary)
                            Text(project)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .textCase(.uppercase)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(projectWorkspaces.count)").font(.caption2).foregroundColor(.secondary)
                        }
                        ForEach(projectWorkspaces.prefix(30)) { w in
                            Button(action: { cmux("workspace.select", workspace_id: w.id) }) {
                                HStack(spacing: 6) {
                                    let dotColor = w.selected ? "#4C9AFF" : (w.progress != nil ? "#F5A623" : "#8E8E93")
                                    Circle().fill(dotColor).frame(width: 6, height: 6)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(w.title)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .foregroundColor(w.selected ? .primary : .secondary)
                                        if let b = w.branch {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.triangle.branch").imageScale(.small)
                                                Text(b).font(.caption2).monospaced().lineLimit(1)
                                                if w.dirty == true {
                                                    Text("\u{25CF}").font(.caption2).foregroundColor("#F5A623")
                                                }
                                            }
                                            .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if w.unread > 0 {
                                        Text("\(w.unread)")
                                            .font(.caption2)
                                            .foregroundColor("#FFFFFF")
                                            .padding(4)
                                            .background("#E0554D")
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(4)
                                .background {
                                    RoundedRectangle(cornerRadius: 6).fill(w.selected ? "#264C9AFF" : "#00000000")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
.padding(10)

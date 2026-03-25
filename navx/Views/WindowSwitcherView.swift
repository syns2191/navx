import SwiftUI
import Combine

struct WindowSwitcherView: View {
    @StateObject private var vm = WindowSwitcherViewModel()
    @FocusState private var isSearchFocused: Bool
    @State private var localEventMonitor: Any?
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            windowList
        }
        .frame(width: 600, height: 400)
        .background(VisualEffectView().ignoresSafeArea())
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        // React to mode changes & system triggers
        .onChange(of: vm.mode) { newMode in
            isSearchFocused = (newMode == .insert)
        }
        .onReceive(NotificationCenter.default.publisher(for: .windowSwithcerOpened)) { _ in
            vm.resetToNormalMode()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            guard WindowSwitcherPanelManager.shared.panel?.isVisible == true else { return }
            // Only live-update if we are not actively typing a search query to prevent selection jumps
            if vm.searchText.isEmpty {
                vm.loadWindows()
            }
        }
        .onAppear {
            setupKeyboardMonitor()
        }
    }
    
    // MARK: - Sub-Views
    
    private var searchBar: some View {
        HStack {
            Text(vm.mode == .normal ? "NORMAL" : "INSERT")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(vm.mode == .normal ? .black : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(vm.mode == .normal ? Color.green : Color.blue)
                .cornerRadius(4)
            
            TextField("Search apps or windows...", text: $vm.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .light))
                .focused($isSearchFocused)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }
    
    private var windowList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(vm.filteredWindows.indices, id: \.self) { index in
                        windowRow(for: vm.filteredWindows[index], index: index)
                            .id(index) // Required for ScrollViewReader scrolling
                    }
                }
                .padding(8)
            }
            .onChange(of: vm.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    private func windowRow(for window: WindowInfo, index: Int) -> some View {
        HStack {
            if let url = window.appURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading) {
                Text(window.appName)
                    .font(.system(size: 14, weight: .medium))
                Text(window.windowTitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(index == vm.selectedIndex ? Color.accentColor : Color.clear)
        )
        .foregroundColor(index == vm.selectedIndex ? .white : .primary)
    }
    
    // MARK: - Vim Keyboard Traps
    
    private func setupKeyboardMonitor() {
        if localEventMonitor != nil { return }
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard WindowSwitcherPanelManager.shared.panel?.isVisible == true else { return event }
            
            // Enter key -> Execute
            if event.keyCode == 36 {
                vm.focusSelectedWindow()
                return nil
            }
            
            // Escape key -> Always close the panel, regardless of mode
            if event.keyCode == 53 {
                WindowSwitcherPanelManager.shared.hideSwitcher()
                return nil
            }
            
            // === NORMAL MODE TRAPS ===
            if vm.mode == .normal {
                // j (38) or Down Arrow (125)
                if event.keyCode == 38 || event.keyCode == 125 {
                    vm.moveSelectionDown()
                    return nil
                }
                
                // k (40) or Up Arrow (126)
                if event.keyCode == 40 || event.keyCode == 126 {
                    vm.moveSelectionUp()
                    return nil
                }
                
                // i (34) -> Switch to Insert Mode
                if event.keyCode == 34 {
                    vm.mode = .insert
                    return nil
                }
                
                // If it's any other character key, SWALLOW IT so we don't accidentally type in Normal mode
                if let chars = event.characters, !chars.isEmpty {
                    return nil
                }
            }
            
            // === INSERT MODE TRAPS ===
            // Allow everything to pass through to the TextField.
            // (The "jk" escape sequence is handled automatically by the ViewModel's `didSet` observer)
            
            return event
        }
    }
}

//
//  CustomPopover.swift
//  Video Mute
//
//  Created by 狒狒 on 2025/10/23.
//

import SwiftUI

struct CustomPopover<Content: View>: View {
    @Binding var isPresented: Bool
    let arrowDirection: Edge
    let content: Content
    let anchorPoint: CGPoint?
    @State private var contentSize: CGSize = .zero
    
    init(isPresented: Binding<Bool>, arrowDirection: Edge = .top, anchorPoint: CGPoint? = nil, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.arrowDirection = arrowDirection
        self.anchorPoint = anchorPoint
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            if isPresented {
                // Background overlay
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPresented = false
                        }
                    }
                
                // Popover content with arrow
                VStack(spacing: 0) {
                    if arrowDirection == .bottom {
                        ArrowShape(direction: .top)
                            .fill(Color(.systemBackground))
                            .frame(width: 16, height: 8)
                    }
                    
                    content
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        contentSize = geometry.size
                                    }
                            }
                        )
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                        .frame(maxWidth: 200) // Limit maximum width
                    
                    if arrowDirection == .top {
                        ArrowShape(direction: .bottom)
                            .fill(Color(.systemBackground))
                            .frame(width: 16, height: 8)
                    }
                }
                .overlay(
                    // Add arrow indicator to ensure it points to anchor
                    Group {
                        if arrowDirection == .top && anchorPoint != nil {
                            ArrowShape(direction: .bottom)
                                .fill(Color(.systemBackground))
                                .frame(width: 16, height: 8)
                                .position(x: contentSize.width / 2, y: 0)
                        } else if arrowDirection == .bottom && anchorPoint != nil {
                            ArrowShape(direction: .top)
                                .fill(Color(.systemBackground))
                                .frame(width: 16, height: 8)
                                .position(x: contentSize.width / 2, y: contentSize.height + 8)
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.easeInOut(duration: 0.2), value: isPresented)
                .position(getPosition())
            }
        }
    }
    
    private func getPosition() -> CGPoint {
        guard let anchorPoint = anchorPoint else {
            return CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
        }
        
        // Calculate position based on arrow direction
        switch arrowDirection {
        case .top:
            // Arrow points up, content below button
            // Ensure popover doesn't exceed right screen boundary
            let maxX = UIScreen.main.bounds.width - contentSize.width / 2 - 20
            let adjustedX = min(max(anchorPoint.x, contentSize.width / 2 + 20), maxX)
            
            return CGPoint(
                x: adjustedX,
                y: anchorPoint.y + 30 + contentSize.height / 2
            )
        case .bottom:
            // Arrow points down, content above button
            let maxX = UIScreen.main.bounds.width - contentSize.width / 2 - 20
            let adjustedX = min(max(anchorPoint.x, contentSize.width / 2 + 20), maxX)
            
            return CGPoint(
                x: adjustedX,
                y: anchorPoint.y - 30 - contentSize.height / 2
            )
        case .leading:
            // Arrow points left, content to the right of button
            let maxY = UIScreen.main.bounds.height - contentSize.height / 2 - 20
            let adjustedY = min(max(anchorPoint.y, contentSize.height / 2 + 20), maxY)
            
            return CGPoint(
                x: anchorPoint.x + 30 + contentSize.width / 2,
                y: adjustedY
            )
        case .trailing:
            // Arrow points right, content to the left of button
            let maxY = UIScreen.main.bounds.height - contentSize.height / 2 - 20
            let adjustedY = min(max(anchorPoint.y, contentSize.height / 2 + 20), maxY)
            
            return CGPoint(
                x: anchorPoint.x - 30 - contentSize.width / 2,
                y: adjustedY
            )
        }
    }
}

struct ArrowShape: Shape {
    let direction: Edge
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch direction {
        case .top:
            path.move(to: CGPoint(x: rect.width / 2, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
        case .bottom:
            path.move(to: CGPoint(x: rect.width / 2, y: 0))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        default:
            break
        }
        
        return path
    }
}

struct PopoverMenuItem: View {
    let icon: String
    let title: String
    let iconColor: Color
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 20, height: 20)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(textColor)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity) // Ensure menu items fill available width
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PopoverMenu: View {
    let items: [PopoverMenuItem]
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
                items[index]
                
                if index < items.count - 1 {
                    Divider()
                        .background(Color(.systemGray5))
                }
            }
        }
        .background(Color(.systemBackground))
        .frame(maxWidth: 180) // Limit maximum menu width
    }
}

// Usage example:
struct CustomPopoverExample: View {
    @State private var showPopover = false
    
    var body: some View {
        ZStack {
            Button(action: {
                showPopover = true
            }) {
                Text("Show Popover")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            CustomPopover(isPresented: $showPopover) {
                PopoverMenu(items: [
                    PopoverMenuItem(
                        icon: "photo",
                        title: "Save to Photos",
                        iconColor: .blue,
                        textColor: .primary
                    ) {
                        print("Save to Photos")
                    },
                    PopoverMenuItem(
                        icon: "trash",
                        title: "Delete Record",
                        iconColor: .red,
                        textColor: .red
                    ) {
                        print("Delete Record")
                    }
                ])
            }
        }
    }
}
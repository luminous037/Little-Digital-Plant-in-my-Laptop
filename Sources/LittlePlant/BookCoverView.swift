import SwiftUI

struct BookCoverView: View {
    var english: Bool
    var onOpen: () -> Void
    var isPhotoAlbum = false
    var body: some View {
        Button(action:onOpen) {
            Image(nsImage:RetroBookGraphic.cover(english:english,isPhotoAlbum:isPhotoAlbum))
                .interpolation(.none).resizable().scaledToFit()
                .frame(width:380,height:340)
                .shadow(color:.black.opacity(0.25),radius:9,x:3,y:8)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(isPhotoAlbum ? (english ? "Open Plant Records" : "식물 기록 펼치기") : (english ? "Open Plant Stories" : "식물 이야기 펼치기"))
            .help(english ? "Open book" : "책 펼치기")
    }
}

/// Artwork becomes a low-resolution texture on a real SceneKit book mesh.
struct BookCoverArtwork: View {
    var english: Bool
    var isPhotoAlbum = false
    private let gold = Color(red:0.72,green:0.62,blue:0.36)
    var body: some View {
        if isPhotoAlbum { PhotoAlbumCoverArtwork(english:english) }
        else {

        ZStack {
            Rectangle().fill(Color(red:0.22,green:0.30,blue:0.20))
            Image(nsImage:RetroTexture.image(NSColor(red:0.22,green:0.30,blue:0.20,alpha:1),surface:.leather))
                .interpolation(.none).resizable().opacity(0.65)
            Rectangle().stroke(Color(red:0.36,green:0.41,blue:0.24).opacity(0.45),lineWidth:1).padding(.horizontal,14).padding(.vertical,8)
            HStack(spacing:3) {
                Rectangle().fill(.black.opacity(0.18)).frame(width:2)
                Rectangle().fill(.white.opacity(0.06)).frame(width:1)
                Spacer()
            }.padding(.leading,8)
            VStack(spacing:0) {
                Rectangle().fill(gold).frame(width:100,height:2.5)
                Spacer()
                CoverLeaf(juvenile:false).fill(gold,style:FillStyle(eoFill:true)).frame(width:53,height:57)
                    .shadow(color:.black.opacity(0.22),radius:0,x:1,y:1)
                Text(english ? "Plant Stories" : "식물 이야기")
                    .font(.custom(RetroFonts.clock,size:22)).fontWeight(.bold)
                    .foregroundStyle(Color(red:1.0,green:0.91,blue:0.62))
                    .shadow(color:.black.opacity(0.65),radius:0,x:1,y:1)
                    .padding(.top,24)
                Spacer()
                Rectangle().fill(gold).frame(width:100,height:2.5)
            }.padding(.vertical,42)
        }
        .frame(width:BookOpeningRenderer.artworkSize.width,height:BookOpeningRenderer.artworkSize.height)
            }
    }
}

private struct CoverLeaf: Shape {
    var juvenile = false
    func path(in rect: CGRect) -> Path {
        let source = MonsteraLeaf.outline(juvenile:juvenile)
        let bounds = source.bounds
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(x:rect.minX+(point.x-bounds.minX)/bounds.width*rect.width,
                    y:rect.maxY-(point.y-bounds.minY)/bounds.height*rect.height)
        }
        var path = Path()
        let points = UnsafeMutablePointer<NSPoint>.allocate(capacity:3)
        defer { points.deallocate() }
        for index in 0..<source.elementCount {
            switch source.element(at:index,associatedPoints:points) {
            case .moveTo: path.move(to:map(points[0]))
            case .lineTo: path.addLine(to:map(points[0]))
            case .curveTo, .cubicCurveTo: path.addCurve(to:map(points[2]),control1:map(points[0]),control2:map(points[1]))
            case .quadraticCurveTo: path.addQuadCurve(to:map(points[1]),control:map(points[0]))
            case .closePath: path.closeSubpath()
            @unknown default: break
            }
        }
        return path
    }
}

private struct PhotoAlbumCoverArtwork: View {
    var english: Bool
    var body: some View {
        ZStack {
            Color(white:0.94)
            Image(nsImage:RetroTexture.image(NSColor(white:0.94,alpha:1),surface:.ceramic)).interpolation(.none).resizable().opacity(0.18)
            Rectangle().stroke(Color.gray.opacity(0.25),lineWidth:1).padding(13)
            Rectangle().fill(Color.black.opacity(0.07)).frame(width:3).frame(maxWidth:.infinity,alignment:.leading).padding(.leading,8)
            VStack(spacing:26) {
                Rectangle().stroke(Color(white:0.55),lineWidth:3).frame(width:60,height:66)
                Text(english ? "Plant Records" : "식물 기록").font(.custom(RetroFonts.clock,size:22)).fontWeight(.bold).foregroundStyle(Color(white:0.10))
            }
        }.frame(width:BookOpeningRenderer.artworkSize.width,height:BookOpeningRenderer.artworkSize.height)
    }
}

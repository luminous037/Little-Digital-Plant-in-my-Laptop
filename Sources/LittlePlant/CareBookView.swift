import SwiftUI

struct CareBookView: View {
    var english: Bool
    var onClose: () -> Void
    var isPhotoAlbum = false
    @ObservedObject private var photos = PhotoLibrary.shared
    @State private var targetSpread: Int?
    @State private var deleting: PlantPhoto?
    @State private var enlargedPhoto: PlantPhoto?
    @State private var toast: String?
    @State private var toastID = UUID()
    private var lastSpread: Int { isPhotoAlbum ? max(0,(max(2,photos.entries.count+photos.entries.count%2)/2)-1) : 1 }
    @State private var spread = ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] == "book-about" ? 1 : 0
    @State private var showCover = !["book-open", "book-about", "book-turn", "book-curl", "book-curl-back"].contains(ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] ?? "")
    @State private var openingRenderer: BookOpeningRenderer?
    @State private var openingProgress = 0.0
    @State private var openingTask: Task<Void,Never>?
    @State private var turning = false
    @State private var angle = 0.0
    @State private var forward = true
    @State private var frontImage: NSImage?
    @State private var backImage: NSImage?
    @State private var turnTask: Task<Void, Never>?
    private let ink = Color(red:0.20,green:0.29,blue:0.24)
    private let paper = Color(red:0.985,green:0.968,blue:0.925)
    private let pageWidth: CGFloat = 185
    private func t(_ ko: String,_ en: String) -> String { english ? en : ko }
    private var notes: [String] {
        english ? [
            "Water your plant so its leaves don't dry out.",
            "Don't water too often; avoid soggy soil.",
            "Open the window after watering for airflow.",
            "Fertilizer helps leaves grow faster.",
            "Your plant won't wilt without fertilizer.",
            "Trim wilted leaves to make room for new ones."
        ] : [
            "잎이 마르지 않도록 물을 주세요.",
            "흙이 과습되지 않게 물을 너무 자주 주지 마세요.",
            "물을 준 후엔 창문을 열어 통풍해주세요.",
            "비료는 잎이 빨리 자라게 해줘요.",
            "비료는 주지 않아도 시들지 않아요.",
            "시든 잎은 잘라주면 새 잎이 나요."
        ]
    }
    var body: some View {
        ZStack(alignment:.topTrailing) {
            if let openingRenderer {
                BookOpeningGraphic(renderer:openingRenderer,progress:openingProgress)
            } else if showCover {
                BookCoverView(english:english,onOpen:openCover,isPhotoAlbum:isPhotoAlbum)
                    .transition(.opacity.combined(with:.scale(scale:0.97)))
            } else {
            ZStack {
                HStack(spacing:0) {
                    pageView(turning ? min(spread,targetSpread ?? spread)*2 : spread*2)
                    pageView(turning ? max(spread,targetSpread ?? spread)*2+1 : spread*2+1)
                }
                .clipShape(RoundedRectangle(cornerRadius:3))
                LinearGradient(colors:[.clear,ink.opacity(0.16),.white.opacity(0.2),.clear],startPoint:.leading,endPoint:.trailing)
                    .frame(width:12).allowsHitTesting(false)
                if turning, let frontImage, let backImage {
                    CurledBookPage(front:frontImage,back:backImage,progress:angle,forward:forward)
                        .frame(width:370,height:330).allowsHitTesting(false)
                }
            }
            .frame(width:370,height:330)
            .padding(5)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius:4).fill((isPhotoAlbum ? Color(white:0.84) : Color(red:0.20,green:0.27,blue:0.21))).offset(y:5)
                    ForEach(0..<3,id:\.self) { layer in
                        Rectangle().fill(Color(red:0.79+Double(layer)*0.025,green:0.77+Double(layer)*0.025,blue:0.67+Double(layer)*0.025))
                            .padding(.horizontal,4).offset(y:CGFloat(3-layer))
                    }
                    RoundedRectangle(cornerRadius:4).stroke(isPhotoAlbum ? Color(white:0.78) : Color(red:0.19,green:0.26,blue:0.21),lineWidth:5)
                }
            }
            .shadow(color:.black.opacity(0.25),radius:12,y:5)
            }
            Button(action:onClose) {
                Image(systemName:"xmark").font(.system(size:10)).frame(width:24,height:24)
            }.buttonStyle(.plain).foregroundStyle(showCover && !isPhotoAlbum ? Color.white.opacity(0.55) : ink.opacity(0.65)).padding(.top,7).padding(.trailing,showCover ? 80 : 7)
                .accessibilityLabel(t("책 닫기", "Close book"))
        }
        .foregroundStyle(ink)
        .overlay {
            if let entry = enlargedPhoto, let image = photos.image(for:entry) {
                ZStack {
                    Color.black.opacity(0.48).contentShape(Rectangle()).onTapGesture { dismissPhoto() }
                    Button(action:dismissPhoto) {
                        Image(nsImage:PolaroidGraphic.card(scene:image,record:entry))
                            .interpolation(.none).resizable().scaledToFit().frame(width:290,height:319)
                            .shadow(color:.black.opacity(0.4),radius:15,y:12)
                    }.buttonStyle(.plain).accessibilityLabel(t("확대 사진 닫기", "Close enlarged photo"))
                }.frame(width:410,height:410)
                    .transition(.opacity.combined(with:.scale(scale:0.55)))
                    .zIndex(10)
            }
        }
        .overlay(alignment:.bottom) {
            if let toast { Text(toast).font(.system(size:10)).padding(9).background(.regularMaterial,in:RoundedRectangle(cornerRadius:7)).padding(.bottom,20).transition(.opacity).allowsHitTesting(false) }
        }
        .alert(deleting.map { t("\($0.dateText) 사진을 삭제합니다.", "Delete the photo from \($0.dateText)?") } ?? "",isPresented:Binding(get:{ deleting != nil },set:{ if !$0 { deleting = nil } })) {
            Button(t("예", "Yes"),role:.destructive) { if let deleting { _ = photos.delete(deleting) }; deleting = nil; spread = min(spread,lastSpread) }
            Button(t("아니오", "No"),role:.cancel) { deleting = nil }
        }
        .onChange(of:photos.entries.count) { _ in if isPhotoAlbum { spread = min(spread,lastSpread) } }
        .onDisappear { turnTask?.cancel(); openingTask?.cancel(); BookPageSound.stop() }
        .task {
            guard CommandLine.arguments.contains("--render-preview") else { return }
            let scenario = ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"]
            if isPhotoAlbum && ["photo-album-open","photo-empty","photo-enlarged"].contains(scenario ?? "") {
                showCover = false
                if scenario == "photo-enlarged" {
                    try? await Task.sleep(nanoseconds:300_000_000)
                    withAnimation(.spring(response:0.4,dampingFraction:0.82)) { enlargedPhoto = photos.entries.first }
                    precondition(enlargedPhoto != nil,"Album card must open enlarged")
                }
                return
            }
            if isPhotoAlbum && scenario == "photo-book-cycle" {
                BookPageSound.verify()
                openCover()
                try? await Task.sleep(nanoseconds:1_100_000_000)
                precondition(!showCover && openingRenderer == nil)
                turnPage(back:false)
                try? await Task.sleep(nanoseconds:950_000_000)
                precondition(spread == 1 && !turning,"Photo album must turn forward")
                turnPage(back:true)
                try? await Task.sleep(nanoseconds:950_000_000)
                precondition(spread == 0 && !turning,"Photo album must turn backward")
                closeCover()
                try? await Task.sleep(nanoseconds:1_100_000_000)
                precondition(showCover && openingRenderer == nil,"Photo album must close in 3D")
                fputs("PASS: white album 3D opening, forward/back paper curl, paper sound and closing thud\n",stderr)
                return
            }
            if scenario == "book-cover-cycle" {
                precondition(showCover,"Cycle must begin at the cover")
                BookPageSound.verify()
                let image = RetroBookGraphic.cover(english:english)
                precondition(image.size == BookOpeningRenderer.framebufferSize,"Cover must retain its retro framebuffer")
                let artworkSize = BookOpeningRenderer.artworkSize
                precondition(abs(artworkSize.width/artworkSize.height - 1.85/3.3) < 0.00001,"Artwork must match the mesh without stretching")
                precondition(abs(image.size.width/image.size.height - 380.0/340.0) < 0.00001,"Framebuffer must match the displayed aspect ratio")
                openCover()
                do { try await Task.sleep(nanoseconds:1_100_000_000) } catch { return }
                precondition(!showCover && openingRenderer == nil,"Opening must reach the first spread")
                closeCover()
                closeCover() // A repeated click must not restart an active hinge.
                precondition(openingRenderer != nil && openingProgress == 1,"Closing must start from the open mesh")
                do { try await Task.sleep(nanoseconds:1_100_000_000) } catch { return }
                precondition(showCover && openingRenderer == nil && openingProgress == 0,"Closing must finish at the closed cover")
                fputs("PASS: retro cover resolution, unstretched artwork and framebuffer ratios, 3D open/close cycle, repeated-click guard\n",stderr)
                return
            }
            if scenario == "book-closing" {
                let left = ImageRenderer(content:pageView(0)), right = ImageRenderer(content:pageView(1))
                left.scale = 2; right.scale = 2
                showCover = false
                openingRenderer = BookOpeningRenderer(english:english,left:left.nsImage,right:right.nsImage,isPhotoAlbum:isPhotoAlbum)
                openingProgress = 0.36
                return
            }
            if scenario == "book-opening" || scenario == "book-opening-test" {
                if scenario == "book-opening" {
                    let left = ImageRenderer(content:pageView(0)), right = ImageRenderer(content:pageView(1))
                    left.scale = 2; right.scale = 2
                    openingRenderer = BookOpeningRenderer(english:english,left:left.nsImage,right:right.nsImage,isPhotoAlbum:isPhotoAlbum)
                    openingProgress = 0.62
                } else {
                    precondition(showCover,"Book must begin with its cover")
                    openCover()
                    do { try await Task.sleep(nanoseconds:1_200_000_000) } catch { return }
                    precondition(!showCover && openingRenderer == nil && spread == 0,"3D cover must reveal the first reading spread")
                    fputs("PASS: 3D cover opens continuously into the first spread\n",stderr)
                }
                return
            }
            if scenario == "book-curl" || scenario == "book-curl-back" {
                let backward = scenario == "book-curl-back"
                let front = ImageRenderer(content:pageView(backward ? 2 : 1)), back = ImageRenderer(content:pageView(backward ? 1 : 2))
                front.scale = 2; back.scale = 2
                frontImage = front.nsImage; backImage = back.nsImage
                forward = !backward; angle = 0.42; turning = true
                return
            }
            guard scenario == "book-turn" else { return }
            let flat = PaperCurl.sample(distance:185,width:185,progress:0)
            let bent = PaperCurl.sample(distance:92.5,width:185,progress:0.5)
            let turned = PaperCurl.sample(distance:185,width:185,progress:1)
            precondition(abs(flat.x-185)<0.001 && abs(flat.z)<0.001 && bent.z>40 && abs(turned.x+185)<0.001, "Paper must bend between two flat endpoints")
            PaperCurl.verifyTextureDirections()
            BookPageSound.verify()
            do {
                try await Task.sleep(nanoseconds:150_000_000)
                turnPage(back:false)
                turnPage(back:false) // A second click during the turn must be ignored.
                try await Task.sleep(nanoseconds:950_000_000)
                precondition(spread == 1 && !turning && angle == 0, "Forward turn must settle on the next spread")
                turnPage(back:true)
                try await Task.sleep(nanoseconds:950_000_000)
                precondition(spread == 0 && !turning && angle == 0, "Backward turn must restore the first spread")
                fputs("PASS: book forward/back animation, repeated-click guard, final page state, bundled paper sound\n",stderr)
            } catch { return }
        }
        .accessibilityLabel(isPhotoAlbum ? t("식물 기록 앨범", "Plant records album") : t("몬스테라 돌봄 책", "Monstera care book"))
    }
    @ViewBuilder private func pageView(_ number: Int) -> some View {
        if isPhotoAlbum { photoPage(number) }
        else {
        ZStack {
            paper
            BotanicalSprig().fill(ink.opacity(number % 2 == 0 ? 0.65 : 0.12))
                .frame(width:48,height:42)
                .rotationEffect(.degrees(number % 2 == 0 ? 0 : 180))
                .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:number % 2 == 0 ? .topLeading : .bottomTrailing)
            VStack(spacing:0) {
                VStack(spacing:9) {
                    Text(number < 2 ? "PLANT CARE" : "MONSTERA")
                        .font(.custom(RetroFonts.temperature,size:15)).tracking(1.4)
                        .foregroundStyle(ink.opacity(0.55))
                    Text(number < 2 ? t("식물을 돌보는 법", "Plant care") : t("몬스테라", "Monstera"))
                        .font(.custom(RetroFonts.clock,size:16))
                    Rectangle().fill(ink.opacity(0.2)).frame(width:24,height:1).padding(.top,4)
                }
                .opacity(number % 2 == 0 ? 1 : 0)
                .padding(.top,28)
                if number < 2 {
                    VStack(alignment:.leading,spacing:17) {
                        ForEach(Array(notes[(number == 0 ? 0..<3 : 3..<6)]),id:\.self) { note in
                            HStack(alignment:.top,spacing:5) {
                                Text("-").foregroundStyle(ink.opacity(0.5))
                                Text(note).fixedSize(horizontal:false,vertical:true)
                            }
                        }
                    }
                    .font(.custom(RetroFonts.clock,size:12)).lineSpacing(4)
                    .frame(maxWidth:.infinity,alignment:.leading)
                    .padding(.horizontal,17).padding(.top,20)
                } else if number == 2 {
                    Image(nsImage:MonsteraPortrait.image).interpolation(.none).resizable().scaledToFit()
                        .frame(width:126,height:175).padding(.top,17)
                } else {
                    Text(t("몬스테라는 열대 우림 출신의 잎이 넓은 식물이에요. 실내 공기를 깨끗하게 정화하고 습도를 조절해 줘요. 빛을 충분히 준다면 잎이 예쁘게 갈라져 독특한 모양을 띄어요.",
                           "Monstera is a broad-leaved plant from tropical rainforests. It helps purify indoor air and regulate humidity. With enough light, its leaves develop beautiful splits that give them their distinctive shape."))
                        .font(.custom(RetroFonts.clock,size:12)).lineSpacing(4)
                        .fixedSize(horizontal:false,vertical:true).padding(.horizontal,18).padding(.top,19)
                }
                Spacer(minLength:5)
                HStack {
                    if number % 2 == 0 { pageButton(back:true) }
                    Spacer(minLength:0)
                    Text(String(format:"%02d",number+1)).font(.custom(RetroFonts.temperature,size:16)).foregroundStyle(ink.opacity(0.5))
                    Spacer(minLength:0)
                    if number % 2 == 1 { pageButton(back:false).opacity(number == 3 ? 0 : 1) }
                }.padding(.horizontal,16).padding(.bottom,14)
            }
        }.frame(width:pageWidth,height:330).foregroundStyle(ink)
        }
    }
    private func photoPage(_ number:Int) -> some View {
        VStack(spacing:9) {
            Text(t("식물 기록", "Plant Records")).font(.custom(RetroFonts.clock,size:12)).foregroundStyle(.secondary).padding(.top,20)
            Spacer(minLength:0)
            if photos.entries.indices.contains(number), let image = photos.image(for:photos.entries[number]) {
                let entry = photos.entries[number]
                Button {
                    withAnimation(.spring(response:0.4,dampingFraction:0.82)) { enlargedPhoto = entry }
                } label: {
                    Image(nsImage:PolaroidGraphic.card(scene:image,record:entry)).interpolation(.none).resizable().scaledToFit().frame(width:160,height:176)
                }.buttonStyle(.plain).disabled(turning || openingRenderer != nil)
                    .help(t("사진 확대", "Enlarge photo")).accessibilityLabel(t("사진 확대", "Enlarge photo"))
                HStack(spacing:18) {
                    Button {
                        if photos.copy(entry) { showCopiedToast() }
                    } label: { Image(systemName:"square.and.arrow.up").font(.system(size:14)).frame(width:26,height:26) }
                        .foregroundStyle(Color.gray).buttonStyle(.plain).help(t("사진 복사", "Copy photo")).accessibilityLabel(t("사진 복사", "Copy photo"))
                    Button { deleting = entry } label: { Image(systemName:"trash").font(.system(size:14)).frame(width:26,height:26) }
                        .foregroundStyle(Color(red:0.86,green:0.47,blue:0.46)).buttonStyle(.plain).help(t("사진 삭제", "Delete photo")).accessibilityLabel(t("사진 삭제", "Delete photo"))
                }.disabled(turning || openingRenderer != nil)
            } else {
                VStack(spacing:12) {
                    Image(systemName:"photo").font(.system(size:28)).foregroundStyle(Color.gray.opacity(0.3))
                    Text(photos.entries.isEmpty ? t("아래 메뉴에서 카메라 버튼을 눌러 식물을 기록해보세요", "Press the camera button in the menu below to record your plant.") : t("다음 기록을 기다려요.", "Room for another memory.")).font(.custom(RetroFonts.clock,size:11)).multilineTextAlignment(.center).lineSpacing(5).foregroundStyle(.secondary)
                }.frame(width:150,height:210)
            }
            Spacer(minLength:0)
            HStack {
                if number%2 == 0 { pageButton(back:true) }
                Spacer(minLength:0)
                Text(String(format:"%02d",number+1)).font(.custom(RetroFonts.temperature,size:14)).foregroundStyle(.secondary)
                Spacer(minLength:0)
                if number%2 == 1 { pageButton(back:false).opacity(spread == lastSpread ? 0 : 1) }
            }.padding(.horizontal,16).padding(.bottom,14)
        }.frame(width:pageWidth,height:330).background(Color(white:0.96))
    }
    private func dismissPhoto() {
        withAnimation(.easeInOut(duration:0.25)) { enlargedPhoto = nil }
    }
    private func showCopiedToast() {
        let token = UUID(); toastID = token
        withAnimation(.easeOut(duration:0.15)) { toast = t("사진이 클립보드에 복사되었습니다", "Photo copied to clipboard") }
        Task { @MainActor in
            do { try await Task.sleep(nanoseconds:1_700_000_000) } catch { return }
            if toastID == token { withAnimation(.easeOut(duration:0.7)) { toast = nil } }
        }
    }
    private func pageButton(back: Bool) -> some View {
        Button {
            if back && spread == 0 {
                closeCover()
            } else { turnPage(back:back) }
        } label: {
            Image(systemName:back ? "chevron.left" : "chevron.right")
                .font(.system(size:11)).frame(width:24,height:24)
                .background(ink.opacity(0.055),in:Circle())
        }.buttonStyle(.plain)
        .disabled(turning || openingRenderer != nil || (!back && spread >= lastSpread))
        .accessibilityLabel(back ? (spread == 0 ? t("표지로", "Back to cover") : t("이전 장", "Previous spread")) : t("다음 장", "Next spread"))
    }
    private func openCover() { animateCover(open:true) }
    private func closeCover() { animateCover(open:false) }
    private func animateCover(open:Bool) {
        guard openingRenderer == nil, !turning, showCover == open else { return }
        spread = 0
        let left = ImageRenderer(content:pageView(0)), right = ImageRenderer(content:pageView(1))
        left.scale = 2; right.scale = 2
        openingProgress = open ? 0 : 1
        openingRenderer = BookOpeningRenderer(english:english,left:left.nsImage,right:right.nsImage,isPhotoAlbum:isPhotoAlbum)
        if open { BookPageSound.play() } else { BookPageSound.stop() }
        openingTask = Task { @MainActor in
            // Start from the matching endpoint, then run the same 3D hinge in either direction.
            do { try await Task.sleep(nanoseconds:30_000_000) } catch { return }
            withAnimation(.easeInOut(duration:0.85)) { openingProgress = open ? 1 : 0 }
            do { try await Task.sleep(nanoseconds:880_000_000) } catch { return }
            if !open { BookPageSound.playClose() }
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) {
                showCover = !open
                openingRenderer = nil
            }
        }
    }
    private func turnPage(back: Bool) {
        guard !turning, openingRenderer == nil, back ? spread > 0 : spread < lastSpread else { return }
        let destination = spread+(back ? -1 : 1)
        let front = ImageRenderer(content:pageView(back ? spread*2 : spread*2+1))
        let rear = ImageRenderer(content:pageView(back ? destination*2+1 : destination*2))
        front.scale = 2; rear.scale = 2
        frontImage = front.nsImage; backImage = rear.nsImage
        guard frontImage != nil, backImage != nil else { return }
        targetSpread = destination; forward = !back; angle = 0; turning = true
        BookPageSound.play()
        turnTask = Task { @MainActor in
            withAnimation(.easeInOut(duration:0.8)) { angle = 1 }
            do { try await Task.sleep(nanoseconds:820_000_000) } catch { return }
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) {
                spread = min(destination,lastSpread)
                turning = false; angle = 0; targetSpread = nil
                frontImage = nil; backImage = nil
            }
        }
    }
}

/// Sparse botanical ink in the margin, leaving the reading area clear.
private struct BotanicalSprig: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func point(_ x: CGFloat,_ y: CGFloat) -> CGPoint { CGPoint(x:rect.minX+x*rect.width,y:rect.minY+y*rect.height) }
        p.move(to:point(0,0.02)); p.addQuadCurve(to:point(0.87,0.86),control:point(0.21,0.52))
        p.addQuadCurve(to:point(0,0.04),control:point(0.19,0.49))
        for i in 0..<4 {
            let x = CGFloat(i)*0.17+0.10, y = CGFloat(i)*0.16+0.12
            p.move(to:point(x,y))
            p.addQuadCurve(to:point(x+0.35,y-0.09),control:point(x+0.15,y-0.24))
            p.addQuadCurve(to:point(x,y),control:point(x+0.26,y+0.06))
            p.move(to:point(x,y))
            p.addQuadCurve(to:point(x-0.03,y+0.36),control:point(x-0.14,y+0.12))
            p.addQuadCurve(to:point(x,y),control:point(x+0.10,y+0.24))
        }
        return p
    }
}

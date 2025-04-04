// SPDX-FileCopyrightText: 2023-2024 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import org.deepin.dtk 1.0
import org.deepin.image.viewer 1.0 as IV
import org.deepin.album 1.0 as Album
import "./ImageDelegate"
//import "./LiveText"
import "./InformationDialog"
import "./Utils"

Item {
    id: imageViewer

    // 记录图像缩放，用于在窗口缩放时，根据前后窗口变化保持图片缩放比例
    property bool enableChangeDisplay: true
    property real lastDisplayScaleWidth: 0
    // Image 类型的对象，空图片、错误图片、消失图片等异常为 null
    property alias targetImage: view.currentImage

    // Note: 对于SVG、动图等特殊类型图片，使用 targeImage 获取的图片 sourceSize 存在差异，
    // 可能为零或导致缩放模糊，调整为使用从文件中读取的原始大小计算。
    // 图片旋转后同样会交换宽度和高度，更新缓存的图片源宽高信息
    property alias targetImageInfo: currentImageInfo
    property bool targetImageReady: (null !== view.currentImage) && (Image.Ready === view.currentImage.status)

    //判断图片是否可收藏
    property bool canFavorite: {
        GStatus.bRefreshFavoriteIconFlag
        albumControl.canFavorite(GControl.currentSource.toString())
    }
    property bool bMoveCenterAnimationPlayed: false
    // 退出全屏展示图片
    function escBack() {
        GStatus.showImageInfo = false;
        showNormal();

        // 在相册主界面进入全屏，按Esc应直接返回到相册主界面
        if (GStatus.stackControlLastCurrent === 0) {
            GStatus.stackControlCurrent = GStatus.stackControlLastCurrent
            GStatus.stackControlLastCurrent = -1
            imageViewer.visible = false
            window.title = ""
            return
        }

        showfullAnimation.start();
    }

    function fitImage() {
        if (targetImageReady) {
            // 按图片原始大小执行缩放
            imageAnimation.scaleAnime(targetImageInfo.width / targetImage.paintedWidth);
        }
    }

    function fitWindow() {
        // 默认状态的图片即适应窗口大小(使用 Image.PreserveAspectFit)
        if (targetImageReady) {
            imageAnimation.scaleAnime(1.0);
        }
    }

    // 窗口拖拽大小变更时保持图片的显示缩放比例
    function keepImageDisplayScale() {
        if (!targetImageReady) {
            return;
        }

        // 当前缩放比例与匹配窗口的图片缩放比例比较，不一致则保持缩放比例
        if (Math.abs(targetImage.scale - 1.0) > Number.EPSILON) {
            if (0 !== lastDisplayScaleWidth) {
                // Note: 拖拽窗口时将保持 scale ，但 paintedWidth / paintedHeight 将变更
                // 因此在此处设置缩放比例时屏蔽重复设置，以保留缩放比例
                enableChangeDisplay = false;
                targetImage.scale = lastDisplayScaleWidth / targetImage.paintedWidth;
                enableChangeDisplay = true;
            } else {
                lastDisplayScaleWidth = targetImage.paintedWidth * targetImage.scale;
            }
        } else {
            // 一致则保持匹配窗口
            fitWindow();
        }
    }

    function rotateImage(angle) {
        if (targetImageReady && !rotateDelay.running) {
            rotateDelay.start();
            GControl.currentRotation += angle;
        }
    }

    // 触发全屏展示图片
    function showPanelFullScreen() {
        GStatus.showImageInfo = false;
        showFullScreen();
        view.contentItem.forceActiveFocus();
        showfullAnimation.start();
    }

    function showScaleFloatLabel() {
        // 不存在的图片不弹出缩放提示框
        if (!targetImageReady) {
            return;
        }

        // 图片实际缩放比值 绘制像素宽度 / 图片原始像素宽度
        var readableScale = targetImage.paintedWidth * targetImage.scale / targetImageInfo.width * 100;
        if (readableScale.toFixed(0) > 2000 && readableScale.toFixed(0) <= 3000) {
            floatLabel.displayStr = "2000%";
        } else if (readableScale.toFixed(0) < 2 && readableScale.toFixed(0) >= 0) {
            floatLabel.displayStr = "2%";
        } else if (readableScale.toFixed(0) >= 2 && readableScale.toFixed(0) <= 2000) {
            floatLabel.displayStr = readableScale.toFixed(0) + "%";
        }
        floatLabel.visible = true;
    }

    onHeightChanged: keepImageDisplayScale()

    // 图片状态变更时触发
    onTargetImageReadyChanged: {
        showScaleFloatLabel();

        // 重置保留的缩放状态
        lastDisplayScaleWidth = 0;
    }
    onWidthChanged: keepImageDisplayScale()

    Timer {
        id: rotateDelay

        interval: GStatus.animationDefaultDuration + 50
    }

    // 图像动画：缩放
    ImageAnimation {
        id: imageAnimation

        targetImage: imageViewer.targetImage
    }

    Connections {
        function onScaleChanged() {
            // 图片实际缩放比值 绘制像素宽度 / 图片原始像素宽度
            var readableScale = targetImage.paintedWidth * targetImage.scale / targetImageInfo.width * 100;
            // 缩放限制在 2% ~ 2000% ，变更后再次进入此函数处理
            if (readableScale < 2) {
                targetImage.scale = targetImageInfo.width * 0.02 / targetImage.paintedWidth;
                return;
            } else if (readableScale > 2000) {
                targetImage.scale = targetImageInfo.width * 20 / targetImage.paintedWidth;
                return;
            }

            // 处于保持效果缩放状态时，保留之前的缩放比例
            if (enableChangeDisplay) {
                lastDisplayScaleWidth = targetImage.paintedWidth * targetImage.scale;
                // 显示缩放框
                showScaleFloatLabel();
            }
        }

        enabled: targetImageReady
        ignoreUnknownSignals: true
        target: targetImage
    }

    // 触发切换全屏状态
    Connections {
        function onShowFullScreenChanged() {
            if (window.isFullScreen !== GStatus.showFullScreen) {
                // 关闭详细信息窗口
                GStatus.showImageInfo = false;
                GStatus.showFullScreen ? showPanelFullScreen() : escBack();
            }
        }

        target: GStatus
    }

    Connections {
        function onCurrentSourceChanged() {
            if (imageViewer.visible && GControl.currentSource !== "") {
                window.title = FileControl.slotGetFileName(GControl.currentSource) + FileControl.slotFileSuffix(GControl.currentSource);
            }
        }

        target: GControl
    }

    PropertyAnimation {
        id: showfullAnimation

        duration: 200
        easing.type: Easing.InExpo
        from: 0
        property: "opacity"
        target: parent.Window.window
        to: 1

        onRunningChanged: {
            GStatus.fullScreenAnimating = running;
            // 动画结束时，重置缩放状态
            if (!running && targetImageReady) {
                // 匹配缩放处理
                if (targetImageInfo.height < targetImage.height) {
                    targetImage.scale = targetImageInfo.width / targetImage.paintedWidth;
                } else {
                    targetImage.scale = 1.0;
                }
            }
        }
    }

    // 执行收藏操作
    function executeFavorite() {
        albumControl.insertIntoAlbum(0, GControl.currentSource.toString())
        GStatus.bRefreshFavoriteIconFlag = !GStatus.bRefreshFavoriteIconFlag
    }

    // 执行取消收藏操作
    function executeUnFavorite() {
        albumControl.removeFromAlbum(0, GControl.currentSource.toString())
        GStatus.bRefreshFavoriteIconFlag = !GStatus.bRefreshFavoriteIconFlag
    }

    //收藏/取消收藏
    Shortcut {
        enabled: visible
        sequence: "."
        onActivated: {
            if (!menuItemStates.isInTrash && FileControl.isAlbum()) {
                if (canFavorite)
                    executeFavorite()
                else
                    executeUnFavorite()
            }
        }
    }

    //缩放快捷键
    Shortcut {
        enabled: visible
        sequence: "Ctrl+="

        onActivated: {
            targetImage.scale = targetImage.scale / 0.9;
        }
    }

    Shortcut {
        enabled: visible
        sequence: "Ctrl+-"

        onActivated: {
            targetImage.scale = targetImage.scale * 0.9;
        }
    }

    Shortcut {
        sequence: "Up"

        onActivated: {
            targetImage.scale = targetImage.scale / 0.9;
        }
    }

    Shortcut {
        sequence: "Down"

        onActivated: {
            targetImage.scale = targetImage.scale * 0.9;
        }
    }

    ParallelAnimation {
        id: moveCenterAnimation
        property int fromX: 0
        property int fromY: 0
        property int fromW: 0
        property int fromH: 0
        property int nDuration: GStatus.animationDuration
        NumberAnimation {
            target: view
            properties: "x"
            from: moveCenterAnimation.fromX
            to: 0
            duration: moveCenterAnimation.nDuration
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: imageViewer
            property: "opacity"
            from: 0
            to: 1
            duration: moveCenterAnimation.nDuration
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: view
            property: "opacity"
            from: 0
            to: 1
            duration: moveCenterAnimation.nDuration
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: view
            properties: "y"
            from: moveCenterAnimation.fromY
            to: 0 + GStatus.titleHeight
            duration: moveCenterAnimation.nDuration
            easing.type: Easing.OutExpo
        }

        NumberAnimation {
            target: view
            properties: "width"
            from: moveCenterAnimation.fromW
            to: imageViewer.width
            duration: moveCenterAnimation.nDuration
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: view
            properties: "height"
            from: moveCenterAnimation.fromH
            to: window.isFullScreen ? parent.height : (parent.height - (GStatus.titleHeight * 2))
            duration: moveCenterAnimation.nDuration
            easing.type: Easing.OutExpo
        }

        onStopped: {
            GStatus.enteringImageViewer = false
            bMoveCenterAnimationPlayed = true
        }
    }

    Connections {
        target: GStatus
        function onSigMoveCenter(x,y,w,h) {
            moveCenterAnimation.fromX = x
            moveCenterAnimation.fromY = y
            moveCenterAnimation.fromW = w
            moveCenterAnimation.fromH = h
            moveCenterAnimation.start()
        }
    }

    ParallelAnimation {
        id: moveToAlbumAnimation
        NumberAnimation {
            target: view
            properties: "x"
            from: 0
            to: moveCenterAnimation.fromX
            duration: GStatus.largeImagePreviewAnimationDuration
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: imageViewer
            property: "opacity"
            from: 1
            to: 0
            duration: GStatus.largeImagePreviewAnimationDuration
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: view
            property: "opacity"
            from: 1
            to: 0
            duration: GStatus.largeImagePreviewAnimationDuration
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: view
            properties: "y"
            from: 0 + GStatus.titleHeight
            to: moveCenterAnimation.fromY
            duration: GStatus.largeImagePreviewAnimationDuration
            easing.type: Easing.OutExpo
        }

        NumberAnimation {
            target: view
            properties: "width"
            from: view.width
            to: moveCenterAnimation.fromW
            duration: GStatus.largeImagePreviewAnimationDuration
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: view
            properties: "height"
            from: view.height
            to: moveCenterAnimation.fromH
            duration: GStatus.largeImagePreviewAnimationDuration
            easing.type: Easing.OutExpo
        }
    }

    Connections {
        target: GStatus
        function onSigMoveToAlbumAnimation() {
            // 以动画方式进入大图，返回相册时才逆向播放退出动画
            if (bMoveCenterAnimationPlayed) {
                moveToAlbumAnimation.start()
                bMoveCenterAnimationPlayed = false
            }
        }
    }

    // 图片滑动视图的上层组件
    Item {
        id: viewBackground

        anchors.fill: parent
    }

    // 图片滑动视图
    PathView {
        id: view

        // 当前展示的 Image 图片对象，空图片、错误图片、消失图片等异常为 undefined
        // 此图片信息用于外部交互缩放、导航窗口等，已标识类型，使用 null !== currentImage 判断
        property Image currentImage: {
            if (view.currentItem) {
                if (view.currentItem.item) {
                    return view.currentItem.item.targetImage;
                }
            }
            return null;
        }
        // 用于限制拖拽方向(处于头尾时)
        property real previousOffset: 0

        // WARNING: 目前 ListView 组件屏蔽输入处理，窗口拖拽依赖底层的 ApplicationWindow
        // 因此不允许 ListView 的区域超过标题栏，图片缩放超过显示区域无妨。
        // 显示图片上下边界距边框 50px (标题栏宽度)，若上下间隔不一致时，进行拖拽、导航定位或需减去(间隔差/2)
        // 在全屏时无上下边框
        //anchors.horizontalCenter: parent.horizontalCenter
        dragMargin: width / 2
        flickDeceleration: 500
        focus: true
        height: window.isFullScreen ? parent.height : (parent.height - (GStatus.titleHeight * 2))
        // 动画过程中不允许拖拽
        interactive: !GStatus.fullScreenAnimating && GStatus.viewInteractive && !offsetAnimation.running
        model: GControl.viewModel
        // 设置滑动视图的父组件以获取完整的OCR图片信息
        parent: viewBackground
        // PathView 的动画效果通过 Path 路径和 Item 个数及 Item 宽度共同计算
        pathItemCount: GStatus.pathViewItemCount
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        snapMode: ListView.SnapOneItem
        width: parent.width
        y: Window.window.isFullScreen ? 0 : GStatus.titleHeight

        // 代理组件加载器
        delegate: ViewDelegateLoader {
        }
        Behavior on offset {
            id: offsetBehavior

            enabled: !GStatus.viewFlicking

            NumberAnimation {
                id: offsetAnimation

                duration: GStatus.animationDefaultDuration
                easing.type: Easing.OutExpo

                onRunningChanged: {
                    // 动画结束，触发更新同步状态
                    GControl.viewModel.syncState();
                }
            }
        }

        // 注意图片路径是按照 总长 / pathItemCount 来平均计算位置的，各项间距等分
        path: Path {
            startX: 0
            startY: view.height / 2

            // 前一图片位置
            PathLine {
                x: view.width / 6
                y: view.height / 2
            }

            PathAttribute {
                name: "delegateOpacity"
                value: 0
            }

            PathAttribute {
                name: "delegateOffset"
                value: -1
            }

            // 当前图片位置
            PathLine {
                x: view.width / 2
                y: view.height / 2
            }

            PathAttribute {
                name: "delegateOpacity"
                value: 1
            }

            PathAttribute {
                name: "delegateOffset"
                value: 0
            }

            // 后一图片位置
            PathLine {
                x: view.width * 5 / 6
                y: view.height / 2
            }

            PathAttribute {
                name: "delegateOpacity"
                value: 0
            }

            PathAttribute {
                name: "delegateOffset"
                value: 1
            }

            PathLine {
                x: view.width
                y: view.height / 2
            }
        }

        Component.onCompleted: {
            // 首次进入(退出缩略图后创建)重置当前显示的索引
            GStatus.viewFlicking = true;
            currentIndex = GControl.viewModel.currentIndex;
            GStatus.viewFlicking = false;
        }
        onCurrentIndexChanged: {
            var curIndex = view.currentIndex;
            var previousIndex = GControl.viewModel.currentIndex;
            var lastIndex = view.count - 1;

            // 若索引变更通过model触发，则没有必要更新
            if (curIndex == previousIndex) {
                return;
            }

            // 特殊场景处理，到达边界后循环显示图片
            if (0 === curIndex && previousIndex === lastIndex) {
                GControl.nextImage();
                return;
            }
            if (curIndex === lastIndex && 0 === previousIndex) {
                GControl.previousImage();
                return;
            }

            // 当通过界面拖拽导致索引变更，需要调整多页图索引范围
            if (view.currentIndex < previousIndex) {
                GControl.previousImage();
            } else if (view.currentIndex > previousIndex) {
                GControl.nextImage();
            }
        }
        onMovementEnded: {
            GStatus.viewFlicking = false;
        }
        onMovementStarted: {
            GStatus.viewFlicking = true;
            previousOffset = offset;
        }

        Connections {
            // 模型的索引变更时(缩略图栏点击)触发图片切换的动画效果
            function onCurrentIndexChanged(index) {
                if (view.currentIndex === index) {
                    return;
                }

                /*  NOTE: 由于 PathView 循环显示的特殊性，index 递增，而 offset 递减(index + offset = count)
                    以 count = 5 为例， 在边界 (index 0->4 4->0 0->1) 场景会出现跳变现象
                    index 0 -> 1 对应的 offset 是 0 -> 4 ，实际动画会经过 index 0 4 3 2 1

                    此问题可以通过对场景特殊判断处理，但是动画过程中的 offset 不定，需要结束之前动画后再调整
                */
                if (offsetAnimation.running) {
                    var targetValue = offsetBehavior.targetValue;
                    offsetAnimation.complete();
                    GStatus.viewFlicking = true;
                    view.offset = targetValue;
                    GStatus.viewFlicking = false;
                }

                // 计算相对距离，调整 offset 以触发动画效果
                var distance = Math.abs(view.currentIndex - index);
                if (distance !== 1 && distance !== view.count - 1) {
                    // 动画处理
                    view.currentIndex = index;
                    return;
                }
                var lastIndex = view.count - 1;

                // 调整 offset 进行坐标偏移
                var oldOffset = view.offset;
                var newOffset = (view.count - index);
                if (view.currentIndex === 0 && 1 === index) {
                    GStatus.viewFlicking = true;
                    view.offset = view.count - 0.00001;
                    GStatus.viewFlicking = false;
                } else if (view.currentIndex === lastIndex && 0 === index) {
                    newOffset = 0;
                }
                view.offset = newOffset;
            }

            target: GControl.viewModel
        }

        IV.PathViewRangeHandler {
            enableBackward: GControl.hasNextImage
            enableForward: GControl.hasPreviousImage
            target: view
        }
    }

    IV.ImageInfo {
        id: currentImageInfo

        frameIndex: GControl.currentFrameIndex
        source: GControl.currentSource
    }

    //rename窗口
    ReName {
        id: renamedialog

    }

    // 右键菜单
    ViewRightMenu {
        id: rightMenu

        // 拷贝快捷键冲突：选中实况文本时，屏蔽拷贝图片的快捷键
        copyableConfig: /*!ltw.currentHasSelect*/true

        // 菜单销毁后也需要发送信号，否则可能未正常送达
        Component.onDestruction: {
            GStatus.showRightMenu = false;
        }
        onClosed: {
            GStatus.showRightMenu = false;
            imageViewer.forceActiveFocus();
        }

        Connections {
            function onShowRightMenuChanged() {
                if (GStatus.showRightMenu) {
                    rightMenu.popup(CursorTool.currentCursorPos());
                    rightMenu.focus = true;

                    GStatus.selectedPaths = [GControl.currentSource.toString()]
                    // 关闭详细信息弹窗
                    GStatus.showImageInfo = false;
                }
            }

            target: GStatus
        }
    }

    //导航窗口
    Loader {
        id: naviLoader

        // 导航窗口是否显示
        property bool expectShow: GStatus.enableNavigation && (null !== targetImage) && (targetImage.scale > 1)

        height: 112
        width: 150

        sourceComponent: NavigationWidget {
            // 根据当前缩放动画预期的缩放比例调整导航窗口是否提前触发隐藏
            prefferHide: {
                if (imageAnimation.running) {
                    return imageAnimation.prefferImageScale <= 1;
                }
                return false;
            }
            targetImage: view.currentImage
            // 默认位置，窗体底部
            y: naviLoader.height + 70

            // 长时间隐藏，请求释放导航窗口
            onRequestRelease: {
                naviLoader.active = false;
            }
        }

        // 仅控制弹出显示导航窗口
        onExpectShowChanged: {
            if (expectShow) {
                active = true;
            }
        }

        anchors {
            bottom: parent.bottom
            bottomMargin: 109
            left: parent.left
            leftMargin: 15
        }
    }
}

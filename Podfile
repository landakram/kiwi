use_frameworks!

def app_pods
    pod 'SwiftyDropbox'
    pod 'hoedown'
    pod 'YapDatabase'
    pod 'GRMustache', :git => 'https://github.com/landakram/GRMustache.git'
    pod 'RFKeyboardToolbar'
    pod 'IDMPhotoBrowser'
    pod 'STKWebKitViewController'
    pod 'TUSafariActivity'
    pod 'Notepad', :git => 'https://github.com/kimar/Notepad.git', :branch => 'swift-4'
    pod 'Marklight', :git => 'https://github.com/macteo/Marklight.git', :branch => 'feature/swift4'
    pod 'MRProgress'
    pod 'ViewUtils'
    pod 'AMScrollingNavbar'
    pod 'Fabric'
    pod 'Crashlytics'
    pod 'FileKit', :git => 'https://github.com/landakram/FileKit.git', :branch => 'set-modification-date'
    pod 'RxSwift', '~> 4.1'
    pod 'RxSwiftExt', '~> 3.1'
    pod 'RxCocoa', '~> 4.1'
    pod 'SwiftMessages'
    pod 'RxReachability', :git => 'https://github.com/ivanbruel/RxReachability.git', :branch => 'master'
end

target 'Kiwi' do
    app_pods
end

target 'Kiwi Development' do
    app_pods
end

target 'KiwiTests' do
    pod 'Quick'
    pod 'Nimble'
    pod 'RxBlocking', '~> 4.1'
    pod 'RxTest',     '~> 4.1'
end

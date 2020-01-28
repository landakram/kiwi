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
    pod 'Marklight'
    pod 'MRProgress'
    pod 'ViewUtils'
    pod 'AMScrollingNavbar'
    pod 'Fabric'
    pod 'Crashlytics'
    pod 'FileKit', :git => 'https://github.com/landakram/FileKit.git', :branch => 'set-modification-date'
    pod 'RxSwift', '~> 5.0'
    pod 'RxSwiftExt', '~> 5.1'
    pod 'RxCocoa', '~> 5.0'
    pod 'SwiftMessages', '~> 5.0'
    pod 'RxReachability'
end

target 'Kiwi' do
    app_pods
end

target 'Kiwi Development' do
    app_pods
end

target 'KiwiTests' do
    inherit! :search_paths
    pod 'Quick'
    pod 'Nimble'
    pod 'RxBlocking', '~> 5.0'
    pod 'RxTest',     '~> 5.0'
end

target 'KiwiUITests' do
    inherit! :search_paths
    app_pods
end

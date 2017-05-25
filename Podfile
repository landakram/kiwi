use_frameworks!

def app_pods
    pod 'SwiftyDropbox'
    pod 'hoedown'
    pod 'YapDatabase'
    pod 'GRMustache', :git => 'https://github.com/landakram/GRMustache.git'
    pod "RFKeyboardToolbar"
    pod 'IDMPhotoBrowser'
    pod "STKWebKitViewController"
    pod 'TUSafariActivity'
    pod 'Notepad', :git => 'https://github.com/ruddfawcett/Notepad.git'
    pod 'MRProgress'
    pod 'ViewUtils'
    pod 'Fabric'
    pod 'Crashlytics'
    pod 'FileKit', :git => 'https://github.com/landakram/FileKit.git', :branch => 'set-modification-date'
    pod 'RxSwift',    '~> 3.0'
    pod "RxSwiftExt"
    pod 'RxCocoa',    '~> 3.0'
    pod 'Whisper'
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
    pod 'RxBlocking', '~> 3.0'
    pod 'RxTest',     '~> 3.0'
end

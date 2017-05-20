use_frameworks!

def app_pods
    pod 'SwiftyDropbox', :git => 'https://github.com/dropbox/SwiftyDropbox.git', :branch => 'master'
    pod 'BrightFutures'
    pod 'hoedown'
    pod 'YapDatabase'
    pod 'GRMustache', :git => 'https://github.com/landakram/GRMustache.git'
    pod "RFMarkdownTextView", :path => '~/Documents/code/Memex/RFMarkdownTextView'
    pod 'IDMPhotoBrowser'
    pod "STKWebKitViewController"
    pod 'TUSafariActivity'
    pod 'AsyncSwift'
    pod 'MRProgress'
    pod 'ViewUtils'
    pod 'Fabric'
    pod 'Crashlytics'
    pod 'FileKit', :git => 'https://github.com/landakram/FileKit.git', :branch => 'set-modification-date'
    pod 'EmitterKit', '~> 5.0.0'
    pod 'RxSwift',    '~> 3.0'
    pod "RxSwiftExt"
    pod 'RxCocoa',    '~> 3.0'
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

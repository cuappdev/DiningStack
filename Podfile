use_frameworks!
source 'https://github.com/CocoaPods/Specs.git'

def shared_pods
    pod 'Alamofire'
    pod 'SwiftyJSON', :git => 'https://github.com/appsailor/SwiftyJSON.git', :branch => 'swift3'
end

target :'DiningStack' do
    platform:ios, '9.0'
    shared_pods
end

target :'DiningStack WatchKit' do
    platform :watchos, '2.0'
    shared_pods
end

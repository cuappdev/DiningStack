use_frameworks!
source 'https://github.com/CocoaPods/Specs.git'

def shared_pods
    pod 'Alamofire', :git=> 'https://github.com/Alamofire/Alamofire.git', :branch => 'swift3'
    pod 'SwiftyJSON', :git=> 'https://github.com/SwiftyJSON/SwiftyJSON.git', :branch => 'swift3'
end

target :'DiningStack' do
    platform:ios, '8.0'
    shared_pods
end

target :'DiningStack WatchKit' do
    platform :watchos, '2.0'
    shared_pods
end

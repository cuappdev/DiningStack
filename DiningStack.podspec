Pod::Spec.new do |s|
  s.name             = "DiningStack"
  s.version          = "1.2"
  s.summary          = "Open Source Implementation of Cornell Dining's API"
  s.homepage         = "https://github.com/cuappdev/DiningStack"
  s.license          = 'MIT'
  s.author           = { "CUAppDev" => "info@cuappdev.org" }
  s.source           = { :git => "https://github.com/cuappdev/DiningStack.git", :tag => s.version }

  s.ios.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'
  s.requires_arc = true

  s.source_files = 'DiningStack/*.swift'
  s.resources = 'DiningStack/*.json'

  s.frameworks = 'UIKit'
  s.module_name = 'DiningStack'

  s.dependency 'Alamofire'
  s.dependency 'SwiftyJSON'

end

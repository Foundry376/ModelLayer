Pod::Spec.new do |s|
  s.name     = 'ModelLayer'
  s.version  = '0.0.1'
  s.license  = 'MIT'
  s.summary  = 'A delightful iOS and OS X RESTful model framework.'
  s.homepage = 'https://github.com/Foundry376/ModelLayer'
  s.authors  = { 'Ben Gotow' => 'bengotow@gmail.com' }
  s.source   = { :git => 'https://github.com/Foundry376/ModelLayer.git' }
  s.source_files = '*.{h,m}'
  s.requires_arc = true

  s.ios.deployment_target = '5.0'
  s.dependency       'AFNetworking'

end
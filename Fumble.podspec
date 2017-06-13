#
# Be sure to run `pod lib lint Fumble.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Fumble'
  s.version          = '0.4.0'
  s.summary          = 'FRP Wrapper for CoreBluetooth'

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/fmcode/fumble'
  s.screenshots      = 'http://images.fiftyfootshadows.net/2016/09/DSCF2668.jpg'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Daniel Wang' => 'ddwang@gmail.com' }
  s.source           = { :git => 'https://github.com/fmcode/fumble.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/fminit'

  s.ios.deployment_target = '8.0'

  s.source_files = 'src/Classes/**/*'
  s.public_header_files = 'src/Classes/**/*.h'

  s.frameworks = 'UIKit', 'CoreBluetooth', 'CoreLocation'
  s.dependency 'ReactiveObjC'
end

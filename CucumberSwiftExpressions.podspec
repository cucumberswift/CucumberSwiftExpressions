Pod::Spec.new do |s|
    s.name             = 'CucumberSwiftExpressions'
    s.version          = '0.0.9'
    s.summary          = 'A cucumber expressions implementation in Swift.'

    s.description      = <<-DESC
    Cucumber supports expressions, a custom alternative to regular expressions. This is a supplemental library for CucumberSwift that can parse these expressions.

    It is possible to use this as a standalone library for parsing Cucumber expressions with Swift. Check out our docs for more info.
    DESC
  
    s.homepage         = 'https://github.com/Tyler-Keith-Thompson/CucumberSwiftExpressions'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Tyler Thompson' => 'Tyler.Keith.Thompson@gmail.com' }
    s.source           = { :git => 'https://github.com/Tyler-Keith-Thompson/CucumberSwiftExpressions.git', :tag => s.version.to_s }
    
    s.ios.deployment_target = '10.0'
    s.osx.deployment_target = '10.12'
    s.tvos.deployment_target = '10.0'
    s.swift_version = '5.4'
  
    s.source_files = 'Sources/**/*.{swift,h,m}'
    s.exclude_files = 'Sources/CucumberSwiftExpressions/CucumberSwiftExpressions.docc/'
end
  

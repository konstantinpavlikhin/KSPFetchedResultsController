Pod::Spec.new do |spec|

  spec.name = 'KSPFetchedResultsController'

  spec.version = '1.1.0'

  spec.authors = {'Konstantin Pavlikhin' => 'k.pavlikhin@gmail.com'}

  spec.social_media_url = 'https://twitter.com/kpavlikhin'

  spec.license = {:type => 'MIT', :file => 'LICENSE.md'}

  spec.homepage = 'https://github.com/konstantinpavlikhin/KSPFetchedResultsController'

  spec.source = {:git => 'https://github.com/konstantinpavlikhin/KSPFetchedResultsController.git', :tag => "#{spec.version}"}

  spec.summary = 'The most advanced NSFetchedResultsController reimplementation for a desktop Cocoa.'

  spec.platform = :osx, "10.11"

  spec.osx.deployment_target = "10.8"

  spec.requires_arc = true

  spec.frameworks = 'CoreData'

  spec.source_files = "*.{h,m}"

  spec.exclude_files = "*Test*"

end

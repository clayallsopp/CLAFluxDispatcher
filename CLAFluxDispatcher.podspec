Pod::Spec.new do |s|

  s.name         = "CLAFluxDispatcher"
  s.version      = "0.0.1"
  s.summary      = "A port of Facebook's Flux Dispatcher to Objective-C"

  s.description  = <<-DESC
                   A port of Facebook's Flux Dispatcher to Objective-C; see [https://github.com/facebook/flux](https://github.com/facebook/flux)
                   DESC

  s.homepage     = "https://github.com/clayallsopp/CLAFluxDispatcher"

  s.license      = "MIT"

  s.author             = { "Clay Allsopp" => "clay.allsopp@gmail.com" }
  s.social_media_url   = "http://twitter.com/clayallsopp"

  s.source       = { :git => "https://github.com/clayallsopp/CLAFluxDispatcher.git", :tag => "0.0.1" }

  s.source_files  = "CLAFluxDispatcher/CLAFluxDispatcher/Classes/**/*.{h,m}"
  s.requires_arc = true
end

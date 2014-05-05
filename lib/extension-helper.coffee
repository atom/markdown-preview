extensionsByFenceName =
  'bash': 'sh'
  'coffee': 'coffee'
  'coffeescript': 'coffee'
  'coffee-script': 'coffee'
  'css': 'css'
  'go': 'go'
  'html': 'html'
  'java': 'java'
  'javascript': 'js'
  'js': 'js'
  'json': 'json'
  'less': 'less'
  'mustache': 'mustache'
  'objc': 'm'
  'objective-c': 'm'
  'php': 'php'
  'python': 'py'
  'rb': 'rb'
  'ruby': 'rb'
  'sh': 'sh'
  'toml': 'toml'
  'xml': 'xml'
  'yaml': 'yaml'
  'yml': 'yaml'

module.exports =
  extensionForFenceName: (fenceName) ->
    extensionsByFenceName[fenceName]

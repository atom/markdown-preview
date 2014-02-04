extensionsByFenceName =
  'bash': 'sh'
  'coffee': 'coffee'
  'coffeescript': 'coffee'
  'coffee-script': 'coffee'
  'css': 'css'
  'go': 'go'
  'java': 'java'
  'javascript': 'js'
  'js': 'js'
  'json': 'json'
  'less': 'less'
  'mustache': 'mustache'
  'python': 'py'
  'rb': 'rb'
  'ruby': 'rb'
  'sh': 'sh'
  'toml': 'toml'
  'xml': 'xml'

module.exports =
  extensionForFenceName: (fenceName) ->
    extensionsByFenceName[fenceName]

path = require 'path'
_ = require 'underscore-plus'
cheerio = require 'cheerio'
fs = require 'fs-plus'
Highlights = require 'highlights'
{$} = require 'atom-space-pen-views'
roaster = null # Defer until used
{scopeForFenceName} = require './extension-helper'

highlighter = null
{resourcePath} = atom.getLoadSettings()
packagePath = path.dirname(__dirname)

process = require 'child_process'

exports.toDOMFragment = (text='', filePath, grammar, callback) ->
  render text, filePath, (error, html) ->
    return callback(error) if error?

    template = document.createElement('template')
    template.innerHTML = html
    domFragment = template.content.cloneNode(true)

    # Default code blocks to be coffee in Literate CoffeeScript files
    # defaultCodeLanguage = 'coffee' if grammar?.scopeName is 'source.litcoffee'
    # convertCodeBlocksToAtomEditors(domFragment, defaultCodeLanguage)
    callback(null, domFragment)

exports.toHTML = (text='', filePath, grammar, callback) ->
  render text, filePath, (error, html) ->
    return callback(error) if error?
    # Default code blocks to be coffee in Literate CoffeeScript files
    # defaultCodeLanguage = 'coffee' if grammar?.scopeName is 'source.litcoffee'
    # html = tokenizeCodeBlocks(html, defaultCodeLanguage)
    callback(null, html)

render = (text, filePath, callback) ->
  # Remove the <!doctype> since otherwise marked will escape it
  # https://github.com/chjj/marked/issues/354
  text = text.replace(/^\s*<!doctype(\s+.*)?>\s*/i, '')

  path_ = atom.config.get 'markdown-preview-pandoc.pandocPath'
  opts_ = atom.config.get 'markdown-preview-pandoc.pandocOpts'
  cwd_  = atom.project.getDirectories()
            .filter (d) ->
              d.contains(filePath)
            .map (d) ->
              d.realPath

  return unless path_? and opts_?
  pandoc=process.spawn path_,
    opts_.split(' '),
    cwd: cwd_[0]

  html = ""
  error = ""
  pandoc.stdout.on 'data', (data) -> html+=data
  pandoc.stderr.on 'data', (data) -> error+=data
  pandoc.stdin.write(text)
  pandoc.stdin.end()
  pandoc.on 'close', (code) ->
    if code!=0
      console.log(error)
      console.log(html)
      return callback(error+html)
    html = sanitize(html)
    html = resolveImagePaths(html, filePath)
    callback(null, html.trim())

sanitize = (html) ->
  o = cheerio.load(html)
  o('script').remove()
  attributesToRemove = [
    'onabort'
    'onblur'
    'onchange'
    'onclick'
    'ondbclick'
    'onerror'
    'onfocus'
    'onkeydown'
    'onkeypress'
    'onkeyup'
    'onload'
    'onmousedown'
    'onmousemove'
    'onmouseover'
    'onmouseout'
    'onmouseup'
    'onreset'
    'onresize'
    'onscroll'
    'onselect'
    'onsubmit'
    'onunload'
  ]
  o('*').removeAttr(attribute) for attribute in attributesToRemove
  o.html()

resolveImagePaths = (html, filePath) ->
  o = cheerio.load(html)
  for imgElement in o('img')
    img = o(imgElement)
    if src = img.attr('src')
      continue if src.match(/^(https?|atom):\/\//)
      continue if src.startsWith(process.resourcesPath)
      continue if src.startsWith(resourcePath)
      continue if src.startsWith(packagePath)

      if src[0] is '/'
        unless fs.isFileSync(src)
          img.attr('src', atom.project.getDirectories()[0]?.resolve(src.substring(1)))
      else
        img.attr('src', path.resolve(path.dirname(filePath), src))

  o.html()

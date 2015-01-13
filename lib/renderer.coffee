path = require 'path'
_ = require 'underscore-plus'
cheerio = require 'cheerio'
fs = require 'fs-plus'
Highlights = require 'highlights'
{$} = require 'atom-space-pen-views'
roaster = null # Defer until used
{scopeForFenceName} = require './extension-helper'
{allowUnsafeEval} = require 'loophole'

highlighter = null
{resourcePath} = atom.getLoadSettings()
packagePath = path.dirname(__dirname)

exports.toHtml = (text='', filePath, grammar, callback) ->
  roaster ?= require 'roaster'
  mermaidPath = resolvePath(atom.config.get('markdown-preview.mermaidPath'), filePath)
  options =
    sanitize: false
    breaks: atom.config.get('markdown-preview.breakOnSingleNewline')
    mermaidPath: mermaidPath

  # Remove the <!doctype> since otherwise marked will escape it
  # https://github.com/chjj/marked/issues/354
  text = text.replace(/^\s*<!doctype(\s+.*)?>\s*/i, '')

  roaster text, options, (error, html) =>
    return callback(error) if error

    grammar ?= atom.grammars.selectGrammar(filePath, text)
    # Default code blocks to be coffee in Literate CoffeeScript files
    defaultCodeLanguage = 'coffee' if grammar.scopeName is 'source.litcoffee'

    html = sanitize(html)
    html = resolveImagePaths(html, filePath)
    html = tokenizeCodeBlocks(html, defaultCodeLanguage)
    allowUnsafeEval ->
      callback(null, html.html().trim())

exports.toText = (text, filePath, grammar, callback) ->
  exports.toHtml text, filePath, grammar, (error, html) ->
    if error
      callback(error)
    else
      string = $(document.createElement('div')).append(html)[0].innerHTML
      callback(error, string)

sanitize = (html) ->
  o = cheerio.load("<div>#{html}</div>")
  removeNonMermaidScripts(o)
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

removeNonMermaidScripts = (o) ->
  scripts = o('script')
  scripts = scripts.filter ->
    !cheerio(this).attr('src').match(/mermaid/)
  scripts.remove()

resolveImagePaths = (html, filePath) ->
  html = $(html)
  for imgElement in html.find('img')
    img = $(imgElement)
    if src = img.attr('src')
      img.attr('src', resolvePath(src, filePath))

  html

resolvePath = (src, filePath) ->
  return src unless src
  return src if src.match(/^(https?|atom):\/\//)
  return src if src.startsWith(process.resourcesPath)
  return src if src.startsWith(resourcePath)
  return src if src.startsWith(packagePath)

  if src[0] is '/'
    unless fs.isFileSync(src)
      src = atom.project.resolve(src.substring(1))
  else
    src = path.resolve(path.dirname(filePath), src)

  src

tokenizeCodeBlocks = (html, defaultLanguage='text') ->
  html = $(html)

  if fontFamily = atom.config.get('editor.fontFamily')
    $(html).find('code').css('font-family', fontFamily)

  for preElement in $.merge(html.filter("pre"), html.find("pre"))
    codeBlock = $(preElement.firstChild)
    fenceName = codeBlock.attr('class')?.replace(/^lang-/, '') ? defaultLanguage

    highlighter ?= new Highlights(registry: atom.grammars)
    highlightedHtml = highlighter.highlightSync
      fileContents: codeBlock.text()
      scopeName: scopeForFenceName(fenceName)

    highlightedBlock = $(highlightedHtml)
    # The `editor` class messes things up as `.editor` has absolutely positioned lines
    highlightedBlock.removeClass('editor').addClass("lang-#{fenceName}")
    highlightedBlock.insertAfter(preElement)
    preElement.remove()

  html

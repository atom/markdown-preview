path = require 'path'
_ = require 'underscore-plus'
{$, EditorView} = require 'atom'
roaster = null # Defer until used
{extensionForFenceName} = require './extension-helper'

exports.toHtml = (text, filePath, callback) ->
  roaster ?= require 'roaster'
  options =
    sanitize: true
    breaks: atom.config.get('markdown-preview.breakOnSingleNewline')

  roaster text, options, (error, html) =>
    if error
      callback(error)
    else
      callback(null, tokenizeCodeBlocks(resolveImagePaths(html, filePath)))

exports.toString = (text, filePath, callback) ->
  exports.toHtml text, filePath, (error, html) ->
    if error
      callback(error)
    else
      string = $(document.createElement('div')).append(html)[0].innerHTML
      callback(error, string)

resolveImagePaths = (html, filePath) ->
  html = $(html)
  for imgElement in html.find("img")
    img = $(imgElement)
    src = img.attr('src')
    continue if src.match /^(https?:\/\/)/
    img.attr('src', path.resolve(path.dirname(filePath), src))

  html

tokenizeCodeBlocks = (html) ->
  html = $(html)

  if fontFamily = atom.config.get('editor.fontFamily')
    $(html).find('code').css('font-family', fontFamily)

  for preElement in html.filter("pre")
    $(preElement).addClass("editor-colors")
    codeBlock = $(preElement.firstChild)

    # go to next block unless this one has a class
    continue unless className = codeBlock.attr('class')

    fenceName = className.replace(/^lang-/, '')
    # go to next block unless the class name matches `lang`
    continue unless extension = extensionForFenceName(fenceName)
    text = codeBlock.text()

    grammar = atom.syntax.selectGrammar("foo.#{extension}", text)

    codeBlock.empty()

    for tokens in grammar.tokenizeLines(text).slice(0, -1)
      lineText = _.pluck(tokens, 'value').join('')
      htmlEolInvisibles = ''
      codeBlock.append(EditorView.buildLineHtml({tokens, text: lineText, htmlEolInvisibles}))

  html

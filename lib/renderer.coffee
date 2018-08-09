{TextEditor} = require 'atom'
path = require 'path'
cheerio = require 'cheerio'
createDOMPurify = require 'dompurify'
fs = require 'fs-plus'
roaster = null # Defer until used
{scopeForFenceName} = require './extension-helper'

highlighter = null
{resourcePath} = atom.getLoadSettings()
packagePath = path.dirname(__dirname)

exports.toDOMFragment = (text='', filePath, grammar, callback) ->
  render text, filePath, (error, domFragment) ->
    return callback(error) if error?
    highlightCodeBlocks(domFragment, grammar, makeAtomEditorNonInteractive).then ->
      callback(null, domFragment)

exports.toHTML = (text='', filePath, grammar, callback) ->
  render text, filePath, (error, domFragment) ->
    return callback(error) if error?

    div = document.createElement('div')
    div.appendChild(domFragment)
    document.body.appendChild(div)

    highlightCodeBlocks(div, grammar, convertAtomEditorToStandardElement).then ->
      callback(null, div.innerHTML)
      div.remove()

render = (text, filePath, callback) ->
  roaster ?= require 'roaster'
  options =
    sanitize: false
    breaks: atom.config.get('markdown-preview.breakOnSingleNewline')

  # Remove the <!doctype> since otherwise marked will escape it
  # https://github.com/chjj/marked/issues/354
  text = text.replace(/^\s*<!doctype(\s+.*)?>\s*/i, '')

  roaster text, options, (error, html) ->
    return callback(error) if error?

    html = createDOMPurify().sanitize(html, {ALLOW_UNKNOWN_PROTOCOLS: atom.config.get('markdown-preview.allowUnsafeProtocols')})

    template = document.createElement('template')
    template.innerHTML = html.trim()
    fragment = template.content.cloneNode(true)

    resolveImagePaths(fragment, filePath)
    callback(null, fragment)

resolveImagePaths = (element, filePath) ->
  [rootDirectory] = atom.project.relativizePath(filePath)
  for img in element.querySelectorAll('img')
    # We use the raw attribute instead of the .src property because the value
    # of the property seems to be transformed in some cases.
    if src = img.getAttribute('src')
      continue if src.match(/^(https?|atom):\/\//)
      continue if src.startsWith(process.resourcesPath)
      continue if src.startsWith(resourcePath)
      continue if src.startsWith(packagePath)

      if src[0] is '/'
        unless fs.isFileSync(src)
          if rootDirectory
            img.src = path.join(rootDirectory, src.substring(1))
      else
        img.src = path.resolve(path.dirname(filePath), src)

highlightCodeBlocks = (domFragment, grammar, editorCallback) ->
  if grammar?.scopeName is 'source.litcoffee'
    defaultLanguage = 'coffee'
  else
    defaultLanguage = 'text'

  if fontFamily = atom.config.get('editor.fontFamily')
    for codeElement in domFragment.querySelectorAll('code')
      codeElement.style.fontFamily = fontFamily

  promises = []
  for preElement in domFragment.querySelectorAll('pre')
    do (preElement) ->
      codeBlock = preElement.firstElementChild ? preElement
      fenceName = codeBlock.getAttribute('class')?.replace(/^lang-/, '') ? defaultLanguage
      preElement.classList.add('editor-colors', "lang-#{fenceName}")
      editor = new TextEditor({readonly: true, keyboardInputEnabled: false})
      editorElement = editor.getElement()
      editorElement.setUpdatedSynchronously(true)
      preElement.innerHTML = ''
      preElement.parentNode.insertBefore(editorElement, preElement)
      editor.setText(codeBlock.textContent.replace(/\r?\n$/, ''))
      atom.grammars.assignLanguageMode(editor, scopeForFenceName(fenceName))
      editor.setVisible(true)
      promises.push(editorCallback(editorElement, preElement))
  Promise.all(promises)

makeAtomEditorNonInteractive = (editorElement, preElement) ->
  preElement.remove()
  editorElement.setAttributeNode(document.createAttribute('gutter-hidden')) # Hide gutter
  editorElement.removeAttribute('tabindex') # Make read-only

  # Remove line decorations from code blocks.
  for cursorLineDecoration in editorElement.getModel().cursorLineDecorations
    cursorLineDecoration.destroy()
  return

convertAtomEditorToStandardElement = (editorElement, preElement) ->
  new Promise (resolve) ->
    done = ->
      for line in editorElement.querySelectorAll('.line:not(.dummy)')
        line2 = document.createElement('div')
        line2.className = 'line'
        line2.innerHTML = line.firstChild.innerHTML
        preElement.appendChild(line2)
      editorElement.remove()
      resolve()
    editor = editorElement.getModel()
    if editor.getBuffer().getLanguageMode().fullyTokenized
      done()
    else
      editor.onDidTokenize(done)

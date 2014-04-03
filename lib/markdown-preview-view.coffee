path = require 'path'
{$, $$$, EditorView, ScrollView} = require 'atom'
_ = require 'underscore-plus'
{File} = require 'pathwatcher'
{extensionForFenceName} = require './extension-helper'

module.exports =
class MarkdownPreviewView extends ScrollView
  atom.deserializers.add(this)

  @deserialize: (state) ->
    new MarkdownPreviewView(state)

  @content: ->
    @div class: 'markdown-preview native-key-bindings', tabindex: -1

  constructor: ({@editorId, filePath}) ->
    super

    if @editorId?
      @resolveEditor(@editorId)
    else
      @file = new File(filePath)
      @handleEvents()
      @renderMarkdown()

  serialize: ->
    deserializer: 'MarkdownPreviewView'
    filePath: @getPath()
    editorId: @editorId

  destroy: ->
    @unsubscribe()

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @trigger 'title-changed' if @editor?
        @handleEvents()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        @parents('.pane').view()?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      atom.packages.once 'activated', =>
        resolve()
        @renderMarkdown()

  editorForId: (editorId) ->
    for editor in atom.workspace.getEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: ->
    @subscribe atom.syntax, 'grammar-added grammar-updated', _.debounce((=> @renderMarkdown()), 250)
    @subscribe this, 'core:move-up', => @scrollUp()
    @subscribe this, 'core:move-down', => @scrollDown()

    @subscribeToCommand atom.workspaceView, 'markdown-preview:zoom-in', =>
      zoomLevel = parseFloat(@css('zoom')) or 1
      @css('zoom', zoomLevel + .1)

    @subscribeToCommand atom.workspaceView, 'markdown-preview:zoom-out', =>
      zoomLevel = parseFloat(@css('zoom')) or 1
      @css('zoom', zoomLevel - .1)

    @subscribeToCommand atom.workspaceView, 'markdown-preview:reset-zoom', =>
      @css('zoom', 1)

    changeHandler = =>
      @renderMarkdown()
      pane = atom.workspace.paneForUri(@getUri())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    if @file?
      @subscribe(@file, 'contents-changed', changeHandler)
    else if @editor?
      @subscribe(@editor.getBuffer(), 'contents-modified', changeHandler)
      @subscribe @editor, 'path-changed', => @trigger 'title-changed'

    @subscribe atom.config.observe 'markdown-preview.breakOnSingleNewline', callNow: false, changeHandler

  renderMarkdown: ->
    @showLoading()
    if @file?
      @file.read().then (contents) => @renderMarkdownText(contents)
    else if @editor?
      @renderMarkdownText(@editor.getText())

  renderMarkdownText: (text) ->
    roaster = require 'roaster'
    sanitize = true
    breaks = atom.config.get('markdown-preview.breakOnSingleNewline')
    roaster text, {sanitize, breaks}, (error, html) =>
      if error
        @showError(error)
      else
        @html(@tokenizeCodeBlocks(@resolveImagePaths(html)))
        @trigger('markdown-preview:markdown-changed')

  getTitle: ->
    if @file?
      "#{path.basename(@getPath())} Preview"
    else if @editor?
      "#{@editor.getTitle()} Preview"
    else
      "Markdown Preview"

  getUri: ->
    if @file?
      "markdown-preview://#{@getPath()}"
    else
      "markdown-preview://editor/#{@editorId}"

  getPath: ->
    if @file?
      @file.getPath()
    else if @editor?
      @editor.getPath()

  showError: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Previewing Markdown Failed'
      @h3 failureMessage if failureMessage?

  showLoading: ->
    @html $$$ ->
      @div class: 'markdown-spinner', 'Loading Markdown\u2026'

  resolveImagePaths: (html) =>
    html = $(html)
    imgList = html.find("img")

    for imgElement in imgList
      img = $(imgElement)
      src = img.attr('src')
      continue if src.match /^(https?:\/\/)/
      img.attr('src', path.resolve(path.dirname(@getPath()), src))

    html

  tokenizeCodeBlocks: (html) =>
    html = $(html)
    preList = $(html.filter("pre"))

    for preElement in preList.toArray()
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

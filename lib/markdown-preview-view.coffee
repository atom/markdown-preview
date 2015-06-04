path = require 'path'

{Emitter, Disposable, CompositeDisposable} = require 'atom'
{$, $$$, ScrollView} = require 'atom-space-pen-views'
Grim = require 'grim'
_ = require 'underscore-plus'
fs = require 'fs-plus'
{File} = require 'pathwatcher'

renderer = require './renderer'

module.exports =
class MarkdownPreviewView extends ScrollView
  @content: ->
    @div class: 'markdown-preview-pandoc native-key-bindings', tabindex: -1

  constructor: ({@editorId, @filePath}) ->
    super
    @emitter = new Emitter
    @disposables = new CompositeDisposable

  attached: ->
    return if @isAttached
    @isAttached = true

    if @editorId?
      @resolveEditor(@editorId)
    else
      if atom.workspace?
        @subscribeToFilePath(@filePath)
      else
        @disposables.add atom.packages.onDidActivateInitialPackages =>
          @subscribeToFilePath(@filePath)

  serialize: ->
    deserializer: 'MarkdownPreviewView'
    filePath: @getPath()
    editorId: @editorId

  destroy: ->
    @disposables.dispose()

  onDidChangeTitle: (callback) ->
    @emitter.on 'did-change-title', callback

  onDidChangeModified: (callback) ->
    # No op to suppress deprecation warning
    new Disposable

  onDidChangeMarkdown: (callback) ->
    @emitter.on 'did-change-markdown', callback

  on: (eventName) ->
    if eventName is 'markdown-preview-pandoc:markdown-changed'
      Grim.deprecate("Use MarkdownPreviewView::onDidChangeMarkdown instead of the 'markdown-preview-pandoc:markdown-changed' jQuery event")
    super

  subscribeToFilePath: (filePath) ->
    @file = new File(filePath)
    @emitter.emit 'did-change-title'
    @handleEvents()
    @renderMarkdown()

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @emitter.emit 'did-change-title' if @editor?
        @handleEvents()
        @renderMarkdown()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        @parents('.pane').view()?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      @disposables.add atom.packages.onDidActivateInitialPackages(resolve)

  editorForId: (editorId) ->
    for editor in atom.workspace.getTextEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: ->
    @disposables.add atom.grammars.onDidAddGrammar => _.debounce((=> @renderMarkdown()), 250)
    @disposables.add atom.grammars.onDidUpdateGrammar _.debounce((=> @renderMarkdown()), 250)
    @disposables.add @editor.onDidChangeScrollTop =>
      @scrollToEditorPos() if atom.config.get(
        'markdown-preview-pandoc.scrollWithEditor')

    atom.commands.add @element,
      'core:move-up': =>
        @scrollUp()
      'core:move-down': =>
        @scrollDown()
      'core:save-as': (event) =>
        event.stopPropagation()
        @saveAs()
      'core:copy': (event) =>
        event.stopPropagation() if @copyToClipboard()
      'markdown-preview-pandoc:zoom-in': =>
        zoomLevel = parseFloat(@css('zoom')) or 1
        @css('zoom', zoomLevel + .1)
      'markdown-preview-pandoc:zoom-out': =>
        zoomLevel = parseFloat(@css('zoom')) or 1
        @css('zoom', zoomLevel - .1)
      'markdown-preview-pandoc:reset-zoom': =>
        @css('zoom', 1)

    changeHandler = =>
      @renderMarkdown()

      # TODO: Remove paneForURI call when ::paneForItem is released
      pane = atom.workspace.paneForItem?(this) ? atom.workspace.paneForURI(@getURI())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    if @file?
      @disposables.add @file.onDidChange(changeHandler)
    else if @editor?
      @disposables.add @editor.getBuffer().onDidStopChanging =>
        changeHandler() if atom.config.get 'markdown-preview-pandoc.liveUpdate'
      @disposables.add @editor.onDidChangePath => @emitter.emit 'did-change-title'
      @disposables.add @editor.getBuffer().onDidSave =>
        changeHandler() unless atom.config.get 'markdown-preview-pandoc.liveUpdate'
      @disposables.add @editor.getBuffer().onDidReload =>
        changeHandler() unless atom.config.get 'markdown-preview-pandoc.liveUpdate'

  renderMarkdown: ->
    @showLoading()
    @getMarkdownSource().then (source) => @renderMarkdownText(source) if source?

  getMarkdownSource: ->
    if @file?
      @file.read()
    else if @editor?
      Promise.resolve(@editor.getText())
    else
      Promise.resolve(null)

  renderMarkdownText: (text) ->
    renderer.toDOMFragment text, @getPath(), @getGrammar(), (error, domFragment) =>
      if error
        @showError(error)
      else
        @loading = false
        @empty()
        @append(domFragment)
        @scrollToEditorPos(@editor.getCursorScreenPosition().row)
        @emitter.emit 'did-change-markdown'
        @originalTrigger('markdown-preview-pandoc:markdown-changed')

  scrollToEditorPos: (line) ->
    element = atom.views.getView(@editor)
    line=(element.getFirstVisibleScreenRow()+
        element.getLastVisibleScreenRow())/2 unless line
    p=line/@editor.getLastScreenRow()
    @scrollTop(p*this[0].scrollHeight-@height()/2)

  getTitle: ->
    if @file?
      "#{path.basename(@getPath())} Preview"
    else if @editor?
      "#{@editor.getTitle()} Preview"
    else
      "Markdown Preview"

  getIconName: ->
    "markdown"

  getURI: ->
    if @file?
      "markdown-preview-pandoc://#{@getPath()}"
    else
      "markdown-preview-pandoc://editor/#{@editorId}"

  getPath: ->
    if @file?
      @file.getPath()
    else if @editor?
      @editor.getPath()

  getGrammar: ->
    @editor?.getGrammar()

  showError: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Previewing Markdown Failed'
      @h3 failureMessage if failureMessage?

  showLoading: ->
    @loading = true
    @html $$$ ->
      @div class: 'markdown-spinner', 'Loading Markdown\u2026'

  copyToClipboard: ->
    return false if @loading

    selection = window.getSelection()
    selectedText = selection.toString()
    selectedNode = selection.baseNode

    # Use default copy event handler if there is selected text inside this view
    return false if selectedText and selectedNode? and (@[0] is selectedNode or $.contains(@[0], selectedNode))

    @getMarkdownSource().then (source) =>
      return unless source?

      renderer.toHTML source, @getPath(), @getGrammar(), (error, html) =>
        if error?
          console.warn('Copying Markdown as HTML failed', error)
        else
          atom.clipboard.write(html)

    true

  saveAs: ->
    return if @loading

    filePath = @getPath()
    if filePath
      filePath += '.html'
    else
      filePath = 'untitled.md.html'
      if projectPath = atom.project.getPath()
        filePath = path.join(projectPath, filePath)

    if htmlFilePath = atom.showSaveDialogSync(filePath)
      # Hack to prevent encoding issues
      # https://github.com/atom/markdown-preview-pandoc/issues/96
      html = @[0].innerHTML.split('').join('')

      fs.writeFileSync(htmlFilePath, html)
      atom.workspace.open(htmlFilePath)

  isEqual: (other) ->
    @[0] is other?[0] # Compare DOM elements

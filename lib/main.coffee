url = require 'url'
fs = require 'fs-plus'
{$} = require 'atom'

MarkdownPreviewView = null # Defer until used
renderer = null # Defer until used

createMarkdownPreviewView = (state) ->
  MarkdownPreviewView ?= require './markdown-preview-view'
  new MarkdownPreviewView(state)

isMarkdownPreviewView = (object) ->
  MarkdownPreviewView ?= require './markdown-preview-view'
  object instanceof MarkdownPreviewView

deserializer =
  name: 'MarkdownPreviewView'
  deserialize: (state) ->
    createMarkdownPreviewView(state) if state.constructor is Object
atom.deserializers.add(deserializer)

module.exports =
  configDefaults:
    breakOnSingleNewline: false
    liveUpdate: true
    grammars: [
      'source.gfm'
      'source.litcoffee'
      'text.html.basic'
      'text.plain'
      'text.plain.null-grammar'
    ]

  activate: ->
    atom.workspaceView.command 'markdown-preview:toggle', =>
      @toggle()

    atom.workspaceView.command 'markdown-preview:copy-html', =>
      @copyHtml()

    atom.workspaceView.on 'markdown-preview:preview-file', (event) =>
      @previewFile(event)

    atom.workspaceView.command 'markdown-preview:toggle-break-on-single-newline', ->
      atom.config.toggle('markdown-preview.breakOnSingleNewline')

    atom.workspace.registerOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return

      return unless protocol is 'markdown-preview:'

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'editor'
        createMarkdownPreviewView(editorId: pathname.substring(1))
      else
        createMarkdownPreviewView(filePath: pathname)

  toggle: ->
    if isMarkdownPreviewView(atom.workspace.activePaneItem)
      atom.workspace.destroyActivePaneItem()
      return

    editor = atom.workspace.getActiveEditor()
    return unless editor?

    grammars = atom.config.get('markdown-preview.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars

    @addPreviewForEditor(editor) unless @removePreviewForEditor(editor)

  uriForEditor: (editor) ->
    "markdown-preview://editor/#{editor.id}"

  removePreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForUri(uri)
    if previewPane?
      previewPane.destroyItem(previewPane.itemForUri(uri))
      true
    else
      false

  addPreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previousActivePane = atom.workspace.getActivePane()
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (markdownPreviewView) ->
      if isMarkdownPreviewView(markdownPreviewView)
        markdownPreviewView.renderMarkdown()
        previousActivePane.activate()

  previewFile: ({target}) ->
    filePath = target.dataset.path
    return unless filePath

    for editor in atom.workspace.getEditors() when editor.getPath() is filePath
      @addPreviewForEditor(editor)
      return

    atom.workspace.open "markdown-preview://#{encodeURI(filePath)}", searchAllPanes: true

  copyHtml: ->
    editor = atom.workspace.getActiveEditor()
    return unless editor?

    renderer ?= require './renderer'
    text = editor.getSelectedText() or editor.getText()
    renderer.toText text, editor.getPath(), editor.getGrammar(), (error, html) =>
      if error
        console.warn('Copying Markdown as HTML failed', error)
      else
        atom.clipboard.write(html)

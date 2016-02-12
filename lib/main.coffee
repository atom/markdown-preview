url = require 'url'
fs = require 'fs-plus'

MarkdownPreviewView = null
renderer = null

isMarkdownPreviewView = (object) ->
  MarkdownPreviewView ?= require './markdown-preview-view'
  object instanceof MarkdownPreviewView

module.exports =
  activate: ->
    if parseFloat(atom.getVersion()) < 1.7
      atom.deserializers.add
        name: 'MarkdownPreviewView'
        deserialize: module.exports.createMarkdownPreviewView.bind(module.exports)

    atom.commands.add 'atom-workspace',
      'markdown-preview:toggle': =>
        @toggle()
      'markdown-preview:copy-html': =>
        @copyHtml()
      'markdown-preview:toggle-break-on-single-newline': ->
        keyPath = 'markdown-preview.breakOnSingleNewline'
        atom.config.set(keyPath, not atom.config.get(keyPath))

    previewFile = @previewFile.bind(this)
    atom.commands.add '.tree-view .file .name[data-name$=\\.markdown]', 'markdown-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.md]', 'markdown-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.mdown]', 'markdown-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.mkd]', 'markdown-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.mkdown]', 'markdown-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.ron]', 'markdown-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.txt]', 'markdown-preview:preview-file', previewFile

    atom.workspace.addOpener (uriToOpen) =>
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
        @createMarkdownPreviewView(editorId: pathname.substring(1))
      else
        @createMarkdownPreviewView(filePath: pathname)

  createMarkdownPreviewView: (state) ->
    if state.editorId or fs.isFileSync(state.filePath)
      MarkdownPreviewView ?= require './markdown-preview-view'
      new MarkdownPreviewView(state)

  toggle: ->
    if isMarkdownPreviewView(atom.workspace.getActivePaneItem())
      atom.workspace.destroyActivePaneItem()
      return

    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    grammars = atom.config.get('markdown-preview.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars

    @addPreviewForEditor(editor) unless @removePreviewForEditor(editor)

  uriForEditor: (editor) ->
    "markdown-preview://editor/#{editor.id}"

  removePreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForURI(uri)
    if previewPane?
      previewPane.destroyItem(previewPane.itemForURI(uri))
      true
    else
      false

  addPreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previousActivePane = atom.workspace.getActivePane()
    options =
      searchAllPanes: true
    if atom.config.get('markdown-preview.openPreviewInSplitPane')
      options.split = 'right'
    atom.workspace.open(uri, options).then (markdownPreviewView) ->
      if isMarkdownPreviewView(markdownPreviewView)
        previousActivePane.activate()

  previewFile: ({target}) ->
    filePath = target.dataset.path
    return unless filePath

    for editor in atom.workspace.getTextEditors() when editor.getPath() is filePath
      @addPreviewForEditor(editor)
      return

    atom.workspace.open "markdown-preview://#{encodeURI(filePath)}", searchAllPanes: true

  copyHtml: ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    renderer ?= require './renderer'
    text = editor.getSelectedText() or editor.getText()
    renderer.toHTML text, editor.getPath(), editor.getGrammar(), (error, html) ->
      if error
        console.warn('Copying Markdown as HTML failed', error)
      else
        atom.clipboard.write(html)

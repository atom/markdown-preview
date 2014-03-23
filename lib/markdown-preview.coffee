url = require 'url'
fs = require 'fs-plus'

MarkdownPreviewView = require './markdown-preview-view'

module.exports =
  configDefaults:
    gfmNewlines: false,
    grammars: [
      'source.gfm'
      'source.litcoffee'
      'text.plain'
      'text.plain.null-grammar'
    ]

  activate: ->
    atom.workspaceView.command 'markdown-preview:toggle', =>
      @toggle()

    atom.workspaceView.command 'markdown-preview:toggle-gfm-newlines', =>
      atom.config.toggle('markdown-preview.gfmNewlines')

    atom.workspace.registerOpener (uriToOpen) ->
      {protocol, host, pathname} = url.parse(uriToOpen)
      pathname = decodeURI(pathname) if pathname
      return unless protocol is 'markdown-preview:'

      if host is 'editor'
        new MarkdownPreviewView(editorId: pathname.substring(1))
      else
        new MarkdownPreviewView(filePath: pathname)

  toggle: ->
    editor = atom.workspace.getActiveEditor()
    return unless editor?

    grammars = atom.config.get('markdown-preview.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars

    uri = "markdown-preview://editor/#{editor.id}"

    previewPane = atom.workspace.paneForUri(uri)
    if previewPane
      previewPane.destroyItem(previewPane.itemForUri(uri))
      return

    previousActivePane = atom.workspace.getActivePane()
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (markdownPreviewView) ->
      if markdownPreviewView instanceof MarkdownPreviewView
        markdownPreviewView.renderMarkdown()
        previousActivePane.activate()

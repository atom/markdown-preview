url = require 'url'
fs = require 'fs-plus'

MarkdownPreviewView = require './markdown-preview-view'
renderer = null # Defer until used

module.exports =
  configDefaults:
    breakOnSingleNewline: false
    grammars: [
      'source.gfm'
      'source.litcoffee'
      'text.plain'
      'text.plain.null-grammar'
    ]

  activate: ->
    atom.workspaceView.command 'markdown-preview:toggle', =>
      @toggle()

    atom.workspaceView.command 'markdown-preview:copy-html', =>
      @copyHtml()

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

  copyHtml: ->
    editor = atom.workspace.getActiveEditor()
    return unless editor?

    renderer ?= require './renderer'
    renderer.toString editor.getText(), editor.getPath(), (error, html) =>
      if error
        console.warn('Copying Markdown as HTML failed', error)
      else
        atom.clipboard.write(html)

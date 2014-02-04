url = require 'url'
{fs} = require 'atom'
MarkdownPreviewView = require './markdown-preview-view'

module.exports =
  activate: ->
    atom.workspaceView.command 'markdown-preview:show', =>
      @show()

    atom.project.registerOpener (urlToOpen) ->
      {protocol, pathname} = url.parse(urlToOpen)
      return unless protocol is 'markdown-preview:' and fs.isFileSync(pathname)
      atom.project.bufferForPath(pathname).done (buffer) =>
        new MarkdownPreviewView(buffer)

  show: ->
    activePane = atom.workspaceView.getActivePane()
    editor = activePane.activeItem

    unless editor.getGrammar?().scopeName is "source.gfm"
      console.warn("Can not render markdown for '#{editor.getUri() ? 'untitled'}'")
      return

    markdownUrl = "markdown-preview://#{editor.getPath()}"
    atom.workspace.open(markdownUrl, split: 'right').done (markdownPreviewView) ->
      markdownPreviewView.renderMarkdown()
      activePane.focus()

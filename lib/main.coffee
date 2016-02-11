url = require 'url'
fs = require 'fs-plus'

MarkdownPreviewView = null # Defer until used
renderer = null # Defer until used

# Migrate any old openPreviewInSplitPane setting from a boolean to the new
# string value.  The migration is 'false' --> 'none', and 'true' --> 'right'.
# It would be nice to wait and do this on-demand, but config schema validation
# runs even before the pacakge is activated, so we *have* to do this at module
# load time if we want to accurately migrate the setting.
atom.config.transact ->
  splitKey = 'markdown-preview.openPreviewInSplitPane'
  origSplit = atom.config.getRawValue(splitKey)
  if origSplit? and typeof(origSplit) is 'boolean'
    newSplit = if origSplit then 'right' else 'none'
    console.log 'migrating', splitKey, 'from', origSplit, 'to', newSplit
    atom.config.set(splitKey, newSplit)

createMarkdownPreviewView = (state) ->
  MarkdownPreviewView ?= require './markdown-preview-view'
  new MarkdownPreviewView(state)

isMarkdownPreviewView = (object) ->
  MarkdownPreviewView ?= require './markdown-preview-view'
  object instanceof MarkdownPreviewView

module.exports =
  config:
    breakOnSingleNewline:
      type: 'boolean'
      default: false
      description: 'In Markdown, a single newline character doesn\'t cause a line break in the generated HTML. In GitHub Flavored Markdown, that is not true. Enable this config option to insert line breaks in rendered HTML for single newlines in Markdown source.'
    liveUpdate:
      type: 'boolean'
      default: true
      description: 'Re-render the preview as the contents of the source changes, without requiring the source buffer to be saved. If disabled, the preview is re-rendered only when the buffer is saved to disk.'
    openPreviewInSplitPane:
      type: 'string'
      default: 'right'
      enum: ['none', 'right', 'down', 'left', 'up']
      description: 'Where to open the preview, whether in a new tab in the same pane (`none`), or in a new pane in the specified direction.'
    grammars:
      type: 'array'
      default: [
        'source.gfm'
        'source.litcoffee'
        'text.html.basic'
        'text.md'
        'text.plain'
        'text.plain.null-grammar'
      ]
      description: 'List of scopes for languages for which previewing is enabled. See [this README](https://github.com/atom/spell-check#spell-check-package-) for more information on finding the correct scope for a specific language.'
    useGitHubStyle:
      title: 'Use GitHub.com style'
      type: 'boolean'
      default: false
      description: 'Use the same CSS styles for preview as the ones used on GitHub.com.'

  activate: ->
    atom.deserializers.add
      name: 'MarkdownPreviewView'
      deserialize: (state) ->
        if state.editorId or fs.isFileSync(state.filePath)
          createMarkdownPreviewView(state)

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

    atom.workspace.addOpener (uriToOpen) ->
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
    splitPane = atom.config.get('markdown-preview.openPreviewInSplitPane')
    if splitPane isnt 'none'
      options.split = splitPane
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

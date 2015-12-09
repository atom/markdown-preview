fs = require 'fs-plus'
MarkdownPreviewView = null

module.exports = (state) ->
  if state.editorId or fs.isFileSync(state.filePath)
    MarkdownPreviewView ?= require './markdown-preview-view'
    new MarkdownPreviewView(state)

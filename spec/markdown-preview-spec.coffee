{$$, WorkspaceView} = require 'atom'
MarkdownPreviewView = require '../lib/markdown-preview-view'

describe "Markdown preview package", ->
  beforeEach ->
    atom.packages.activatePackage('language-gfm', sync: true)
    atom.workspaceView = new WorkspaceView
    atom.workspace = atom.workspaceView.model
    atom.packages.activatePackage("markdown-preview", immediate: true)
    spyOn(MarkdownPreviewView.prototype, 'renderMarkdown')

  describe "when the active item can't be rendered as markdown", ->
    describe "when the editor does not use the GFM grammar", ->
      it "does not show a markdown preview", ->
        spyOn(console, 'warn')

        waitsForPromise ->
          atom.workspaceView.open()

        runs ->
          expect(atom.workspaceView.getPanes()).toHaveLength(1)
          atom.workspaceView.getActiveView().trigger 'markdown-preview:show'
          expect(atom.workspaceView.getPanes()).toHaveLength(1)
          expect(console.warn).toHaveBeenCalled()

  describe "when a preview has not been created for the buffer", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

      waitsForPromise ->
        atom.workspaceView.open("file.markdown")

    it "splits the current pane to the right with a markdown preview for the current buffer", ->
      preview = null
      [editorPane, previewPane] = []

      atom.workspaceView.getActiveView().trigger 'markdown-preview:show'

      waitsFor ->
        MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

      runs ->
        expect(atom.workspaceView.getPanes()).toHaveLength 2
        [editorPane, previewPane] = atom.workspaceView.getPanes()

        expect(editorPane.items).toHaveLength 1
        preview = previewPane.activeItem
        expect(preview).toBeInstanceOf(MarkdownPreviewView)
        expect(preview.buffer).toBe atom.workspaceView.getActivePaneItem().buffer
        expect(editorPane).toHaveFocus()

  describe "when a preview has been created for the buffer", ->
    [editorPane, previewPane, preview] = []

    beforeEach ->
      atom.workspaceView.attachToDom()

      waitsForPromise ->
        atom.workspaceView.open("file.markdown")

      runs ->
        atom.workspaceView.getActiveView().trigger 'markdown-preview:show'

      waitsFor ->
        MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspaceView.getPanes()
        preview = previewPane.activeItem
        MarkdownPreviewView.prototype.renderMarkdown.reset()

    it "re-renders and shows the existing preview", ->
      waitsForPromise ->
        previewPane.focus()
        atom.workspaceView.open()

      runs ->
        editorPane.focus()
        atom.workspaceView.getActiveView().trigger 'markdown-preview:show'

      waitsFor ->
        MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

      runs ->
        expect(previewPane.activeItem).toBe preview
        expect(editorPane).toHaveFocus()

    describe "when the buffer is saved", ->
      describe "when the preview is in the active pane", ->
        it "re-renders the preview but does not make it active", ->
          waitsForPromise ->
            previewPane.focus()
            atom.workspaceView.open(preview.getPath())

          runs ->
            previewPane.activeItem.buffer.emit 'saved'

          waitsFor ->
            MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

          runs ->
            expect(previewPane).toHaveFocus()
            expect(previewPane.activeItem).not.toBe preview

      describe "when the preview is not in the active pane", ->
        it "re-renders the preview and makes it active", ->
          waitsForPromise ->
            previewPane.focus()
            atom.workspaceView.open(preview.getPath())

          runs ->
            editorPane.focus()
            editorPane.activeItem.buffer.emit 'saved'

          waitsFor ->
            MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

          runs ->
            expect(editorPane).toHaveFocus()
            expect(previewPane.activeItem).toBe preview

    describe "when a new grammar is loaded", ->
      it "re-renders the preview", ->
        jasmine.unspy(window, 'setTimeout')
        atom.packages.activatePackage('language-javascript', sync: true)

        waitsFor ->
          MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

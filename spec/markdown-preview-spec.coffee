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
      [pane1, pane2] = []

      atom.workspaceView.getActiveView().trigger 'markdown-preview:show'

      waitsFor ->
        MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

      runs ->
        expect(atom.workspaceView.getPanes()).toHaveLength 2
        [pane1, pane2] = atom.workspaceView.getPanes()

        expect(pane1.items).toHaveLength 1
        preview = pane2.activeItem
        expect(preview).toBeInstanceOf(MarkdownPreviewView)
        expect(preview.buffer).toBe atom.workspaceView.getActivePaneItem().buffer
        expect(pane1).toHaveFocus()

  describe "when a preview has been created for the buffer", ->
    [pane1, pane2, preview] = []

    beforeEach ->
      atom.workspaceView.attachToDom()

      waitsForPromise ->
        atom.workspaceView.open("file.markdown")

      runs ->
        atom.workspaceView.getActiveView().trigger 'markdown-preview:show'

      waitsFor ->
        MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

      runs ->
        [pane1, pane2] = atom.workspaceView.getPanes()
        preview = pane2.activeItem
        MarkdownPreviewView.prototype.renderMarkdown.reset()

    it "re-renders and shows the existing preview", ->
      waitsForPromise ->
        pane2.focus()
        atom.workspaceView.open()

      runs ->
        pane1.focus()
        atom.workspaceView.getActiveView().trigger 'markdown-preview:show'

      waitsFor ->
        MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

      runs ->
        expect(pane2.activeItem).toBe preview
        expect(pane1).toHaveFocus()

    describe "when the buffer is saved", ->
      describe "when the preview is in the active pane", ->
        it "re-renders the preview but does not make it active", ->
          waitsForPromise ->
            pane2.focus()
            atom.workspaceView.open(preview.getPath())

          runs ->
            pane2.activeItem.buffer.emit 'saved'

          waitsFor ->
            MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

          runs ->
            expect(pane2).toHaveFocus()
            expect(pane2.activeItem).not.toBe preview

      describe "when the preview is not in the active pane", ->
        it "re-renders the preview and makes it active", ->
          waitsForPromise ->
            pane2.focus()
            atom.workspaceView.open(preview.getPath())

          runs ->
            pane1.focus()
            pane1.activeItem.buffer.emit 'saved'

          waitsFor ->
            MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

          runs ->
            expect(pane1).toHaveFocus()
            expect(pane2.activeItem).toBe preview

    describe "when a new grammar is loaded", ->
      it "re-renders the preview", ->
        jasmine.unspy(window, 'setTimeout')
        atom.packages.activatePackage('language-javascript', sync: true)

        waitsFor ->
          MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

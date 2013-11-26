{$$, WorkspaceView} = require 'atom'
MarkdownPreviewView = require '../lib/markdown-preview-view'

describe "Markdown preview package", ->
  beforeEach ->
    atom.packages.activatePackage('language-gfm', sync: true)
    atom.workspaceView = new WorkspaceView
    atom.packages.activatePackage("markdown-preview", immediate: true)
    spyOn(MarkdownPreviewView.prototype, 'renderMarkdown')

  describe "markdown-preview:show", ->
    beforeEach ->
      atom.workspaceView.openSync("file.markdown")

    describe "when the active item is an edit session", ->
      beforeEach ->
        atom.workspaceView.attachToDom()

      describe "when the edit session does not use the GFM grammar", ->
        it "does not show a markdown preview", ->
          spyOn(console, 'warn')
          atom.workspaceView.openSync()
          expect(atom.workspaceView.getPanes()).toHaveLength(1)
          atom.workspaceView.getActiveView().trigger 'markdown-preview:show'
          expect(atom.workspaceView.getPanes()).toHaveLength(1)
          expect(console.warn).toHaveBeenCalled()

      describe "when a preview item has not been created for the edit session's uri", ->
        describe "when there is more than one pane", ->
          it "shows a markdown preview for the current buffer on the next pane", ->
            atom.workspaceView.getActivePane().splitRight()
            [pane1, pane2] = atom.workspaceView.getPanes()
            pane1.focus()

            atom.workspaceView.getActiveView().trigger 'markdown-preview:show'

            preview = pane2.activeItem
            expect(preview).toBeInstanceOf(MarkdownPreviewView)

            waitsFor ->
              preview.buffer

            runs ->
              expect(preview.buffer).toBe atom.workspaceView.getActivePaneItem().buffer
              expect(pane1).toMatchSelector(':has(:focus)')

        describe "when there is only one pane", ->
          it "splits the current pane to the right with a markdown preview for the current buffer", ->
            expect(atom.workspaceView.getPanes()).toHaveLength 1

            atom.workspaceView.getActiveView().trigger 'markdown-preview:show'

            expect(atom.workspaceView.getPanes()).toHaveLength 2
            [pane1, pane2] = atom.workspaceView.getPanes()

            expect(pane2.items).toHaveLength 1
            preview = pane2.activeItem
            expect(preview).toBeInstanceOf(MarkdownPreviewView)

            waitsFor ->
              preview.buffer

            runs ->
              expect(preview.buffer).toBe atom.workspaceView.getActivePaneItem().buffer
              expect(pane1).toMatchSelector(':has(:focus)')

        describe "when a buffer is saved", ->
          it "does not show the markdown preview", ->
            [pane] = atom.workspaceView.getPanes()
            pane.focus()

            MarkdownPreviewView.prototype.renderMarkdown.reset()
            pane.activeItem.buffer.emit 'saved'
            expect(MarkdownPreviewView.prototype.renderMarkdown).not.toHaveBeenCalled()

        describe "when a buffer is reloaded", ->
          it "does not show the markdown preview", ->
            [pane] = atom.workspaceView.getPanes()
            pane.focus()

            MarkdownPreviewView.prototype.renderMarkdown.reset()
            pane.activeItem.buffer.emit 'reloaded'
            expect(MarkdownPreviewView.prototype.renderMarkdown).not.toHaveBeenCalled()

      describe "when a preview item has already been created for the edit session's uri", ->
        it "updates and shows the existing preview item if it isn't displayed", ->
          atom.workspaceView.getActiveView().trigger 'markdown-preview:show'
          [pane1, pane2] = atom.workspaceView.getPanes()
          pane2.focus()
          expect(atom.workspaceView.getActivePane()).toBe pane2
          preview = pane2.activeItem
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          atom.workspaceView.openSync()
          expect(pane2.activeItem).not.toBe preview
          pane1.focus()

          preview.renderMarkdown.reset()
          atom.workspaceView.getActiveView().trigger 'markdown-preview:show'
          expect(preview.renderMarkdown).toHaveBeenCalled()
          expect(atom.workspaceView.getPanes()).toHaveLength 2
          expect(pane2.getItems()).toHaveLength 2
          expect(pane2.activeItem).toBe preview
          expect(pane1).toMatchSelector(':has(:focus)')

        describe "when a buffer is saved", ->
          describe "when the preview is in the same pane", ->
            it "updates the preview but does not make it active", ->
              atom.workspaceView.getActiveView().trigger 'markdown-preview:show'
              [pane1, pane2] = atom.workspaceView.getPanes()
              pane2.moveItemToPane(pane2.activeItem, pane1, 1)
              pane1.showItemAtIndex(1)
              pane1.showItemAtIndex(0)
              preview = pane1.itemAtIndex(1)

              waitsFor ->
                pane2.activeItem.buffer

              runs ->
                preview.renderMarkdown.reset()
                pane1.activeItem.buffer.emit 'saved'
                expect(preview.renderMarkdown).toHaveBeenCalled()
                expect(pane1.activeItem).not.toBe preview

          describe "when the preview is not in the same pane", ->
            it "updates the preview and makes it active", ->
              atom.workspaceView.getActiveView().trigger 'markdown-preview:show'
              [pane1, pane2] = atom.workspaceView.getPanes()
              preview = pane2.activeItem
              pane2.showItem($$ -> @div id: 'view', tabindex: -1, 'View')
              expect(pane2.activeItem).not.toBe preview
              pane1.focus()

              waitsFor ->
                preview.buffer

              runs ->
                preview.renderMarkdown.reset()
                pane1.activeItem.buffer.emit 'saved'
                expect(preview.renderMarkdown).toHaveBeenCalled()
                expect(pane2.activeItem).toBe preview

      describe "when a new grammar is loaded", ->
        it "reloads the view to colorize any fenced code blocks matching the newly loaded grammar", ->
          atom.workspaceView.getActiveView().trigger 'markdown-preview:show'
          [pane1, pane2] = atom.workspaceView.getPanes()
          preview = pane2.activeItem
          preview.renderMarkdown.reset()
          jasmine.unspy(window, 'setTimeout')

          atom.packages.activatePackage('language-javascript', sync: true)
          waitsFor -> preview.renderMarkdown.callCount > 0

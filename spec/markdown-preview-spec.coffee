path = require 'path'
{WorkspaceView} = require 'atom'
fs = require 'fs-plus'
temp = require 'temp'
wrench = require 'wrench'
MarkdownPreviewView = require '../lib/markdown-preview-view'

describe "Markdown preview package", ->
  beforeEach ->
    fixturesPath = path.join(__dirname, 'fixtures')
    tempPath = temp.mkdirSync('atom')
    wrench.copyDirSyncRecursive(fixturesPath, tempPath, forceDelete: true)
    atom.project.setPath(tempPath)

    atom.workspaceView = new WorkspaceView
    atom.workspace = atom.workspaceView.model
    spyOn(MarkdownPreviewView.prototype, 'renderMarkdown')

    waitsForPromise ->
      atom.packages.activatePackage("markdown-preview")

    waitsForPromise ->
      atom.packages.activatePackage('language-gfm')

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

    describe "when the editor's path does not exit", ->
      it "does not show a markdown preview", ->
        spyOn(console, 'warn')

        waitsForPromise ->
          atom.workspaceView.open("subdir/file.markdown")

        runs ->
          fs.removeSync(atom.workspace.getActiveEditor().getPath())
          expect(atom.workspaceView.getPanes()).toHaveLength(1)
          atom.workspaceView.getActiveView().trigger 'markdown-preview:show'
          expect(atom.workspaceView.getPanes()).toHaveLength(1)
          expect(console.warn).toHaveBeenCalled()

  describe "when a preview has not been created for the file", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

      waitsForPromise ->
        atom.workspaceView.open("subdir/file.markdown")

    it "splits the current pane to the right with a markdown preview for the file", ->
      [editorPane, previewPane] = []

      atom.workspaceView.getActiveView().trigger 'markdown-preview:show'

      waitsFor ->
        MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

      runs ->
        expect(atom.workspaceView.getPanes()).toHaveLength 2
        [editorPane, previewPane] = atom.workspaceView.getPanes()

        expect(editorPane.items).toHaveLength 1
        preview = previewPane.getActiveItem()
        expect(preview).toBeInstanceOf(MarkdownPreviewView)
        expect(preview.getPath()).toBe atom.workspaceView.getActivePaneItem().getPath()
        expect(editorPane).toHaveFocus()

  describe "when a preview has been created for the file", ->
    [editorPane, previewPane, preview] = []

    beforeEach ->
      atom.workspaceView.attachToDom()

      waitsForPromise ->
        atom.workspaceView.open("subdir/file.markdown")

      runs ->
        atom.workspaceView.getActiveView().trigger 'markdown-preview:show'

      waitsFor ->
        MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspaceView.getPanes()
        preview = previewPane.getActiveItem()
        MarkdownPreviewView.prototype.renderMarkdown.reset()

    it "re-renders and shows the existing preview", ->
      rightPane = previewPane.splitRight()

      waitsForPromise ->
        previewPane.focus()
        atom.workspace.open()

      runs ->
        editorPane.focus()
        atom.workspaceView.getActiveView().trigger 'markdown-preview:show'

      waitsFor ->
        MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

      runs ->
        expect(previewPane.getActiveItem()).toBe preview
        expect(rightPane.getActiveItem()).toBeUndefined()
        expect(editorPane).toHaveFocus()

    describe "when the file modified", ->
      describe "when the preview is in the active pane but is not the active item", ->
        it "re-renders the preview but does not make it active", ->
          previewPane.focus()

          waitsForPromise ->
            atom.workspaceView.open()

          runs ->
            fs.writeFileSync(preview.getPath(), "Hey!")

          waitsFor ->
            MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

          runs ->
            expect(previewPane).toHaveFocus()
            expect(previewPane.getActiveItem()).not.toBe preview

      describe "when the preview is not the active item and not in the active pane", ->
        it "re-renders the preview and makes it active", ->
          previewPane.focus()

          waitsForPromise ->
            atom.workspaceView.open()

          runs ->
            editorPane.focus()
            fs.writeFileSync(preview.getPath(), "Hey!")

          waitsFor ->
            MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

          runs ->
            expect(editorPane).toHaveFocus()
            expect(previewPane.getActiveItem()).toBe preview

    describe "when a new grammar is loaded", ->
      it "re-renders the preview", ->
        jasmine.unspy(window, 'setTimeout')
        atom.packages.activatePackage('language-javascript', sync: true)

        waitsFor ->
          MarkdownPreviewView.prototype.renderMarkdown.callCount > 0

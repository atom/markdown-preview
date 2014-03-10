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
    jasmine.unspy(window, 'setTimeout')

    atom.workspaceView = new WorkspaceView
    atom.workspace = atom.workspaceView.model
    spyOn(MarkdownPreviewView.prototype, 'renderMarkdown')

    waitsForPromise ->
      atom.packages.activatePackage("markdown-preview")

    waitsForPromise ->
      atom.packages.activatePackage('language-gfm')

  describe "when a preview has not been created for the file", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    it "splits the current pane to the right with a markdown preview for the file", ->
      waitsForPromise ->
        atom.workspace.open("subdir/file.markdown")

      runs ->
        atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        expect(atom.workspaceView.getPanes()).toHaveLength 2
        [editorPane, previewPane] = atom.workspaceView.getPanes()

        expect(editorPane.items).toHaveLength 1
        preview = previewPane.getActiveItem()
        expect(preview).toBeInstanceOf(MarkdownPreviewView)
        expect(preview.getPath()).toBe atom.workspaceView.getActivePaneItem().getPath()
        expect(editorPane).toHaveFocus()

    describe "when the editor's path does not exist", ->
      it "splits the current pane to the right with a markdown preview for the file", ->
        waitsForPromise ->
          atom.workspace.open("new.markdown")

        runs ->
          atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

        runs ->
          expect(atom.workspaceView.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspaceView.getPanes()

          expect(editorPane.items).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          expect(preview.getPath()).toBe atom.workspaceView.getActivePaneItem().getPath()
          expect(editorPane).toHaveFocus()

    describe "when the editor does not have a path", ->
      it "splits the current pane to the right with a markdown preview for the file", ->
        waitsForPromise ->
          atom.workspace.open("")

        runs ->
          atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

        runs ->
          expect(atom.workspaceView.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspaceView.getPanes()

          expect(editorPane.items).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          expect(preview.getPath()).toBe atom.workspaceView.getActivePaneItem().getPath()
          expect(editorPane).toHaveFocus()

    describe "when the path contains a space", ->
      it "renders the preview", ->
        waitsForPromise ->
          atom.workspace.open("subdir/file with space.md")

        runs ->
          atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

        runs ->
          expect(atom.workspaceView.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspaceView.getPanes()

          expect(editorPane.items).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          expect(preview.getPath()).toBe atom.workspaceView.getActivePaneItem().getPath()
          expect(editorPane).toHaveFocus()

    describe "when the path contains accented characters", ->
      it "renders the preview", ->
        waitsForPromise ->
          atom.workspace.open("subdir/áccéntéd.md")

        runs ->
          atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

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
        atom.workspace.open("subdir/file.markdown")

      runs ->
        atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspaceView.getPanes()
        preview = previewPane.getActiveItem()
        MarkdownPreviewView::renderMarkdown.reset()

    it "closes the existing preview when toggle is triggered a second time", ->
      atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

      [editorPane, previewPane] = atom.workspaceView.getPanes()
      expect(editorPane).toHaveFocus()
      expect(previewPane?.activeItem).toBeUndefined()

    describe "when the editor is modified", ->
      describe "when the preview is in the active pane but is not the active item", ->
        it "re-renders the preview but does not make it active", ->
          previewPane.focus()

          waitsForPromise ->
            atom.workspace.open()

          runs ->
            atom.workspace.getActiveEditor().setText("Hey!")

          waitsFor ->
            MarkdownPreviewView::renderMarkdown.callCount > 0

          runs ->
            expect(previewPane).toHaveFocus()
            expect(previewPane.getActiveItem()).not.toBe preview

      describe "when the preview is not the active item and not in the active pane", ->
        it "re-renders the preview and makes it active", ->
          previewPane.focus()

          waitsForPromise ->
            atom.workspace.open()

          runs ->
            editorPane.focus()
            atom.workspace.getActiveEditor().setText("Hey!")

          waitsFor ->
            MarkdownPreviewView::renderMarkdown.callCount > 0

          runs ->
            expect(editorPane).toHaveFocus()
            expect(previewPane.getActiveItem()).toBe preview

    describe "when a new grammar is loaded", ->
      it "re-renders the preview", ->
        waitsForPromise ->
          atom.packages.activatePackage('language-javascript')

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

  describe "when the markdown preview view is requested by file URI", ->
    it "opens a preview editor and watches the file for changes", ->
      waitsForPromise ->
        atom.workspace.open("markdown-preview://#{atom.project.resolve('subdir/file.markdown')}")

      runs ->
        preview = atom.workspaceView.getActivePaneItem()
        expect(preview).toBeInstanceOf(MarkdownPreviewView)

        MarkdownPreviewView::renderMarkdown.reset()

        fs.writeFileSync(atom.project.resolve('subdir/file.markdown'), 'changed')

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

  describe "when the editor's grammar it not enabled for preview", ->
    it "does not open the markdown preview", ->
      atom.config.set('markdown-preview.grammars', [])

      atom.workspaceView.attachToDom()

      waitsForPromise ->
        atom.workspace.open("subdir/file.markdown")

      runs ->
        spyOn(atom.workspace, 'open').andCallThrough()
        atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'
        expect(atom.workspace.open).not.toHaveBeenCalled()

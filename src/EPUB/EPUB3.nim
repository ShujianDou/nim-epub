import std/[xmlparser, parsexml, xmltree, os, strutils, strtabs, enumutils, sequtils]
import ./types, ./genericHelpers
import zippy/ziparchives

# Based off of https://www.w3.org/publishing/epub3/epub-overview.html#sec-nav
const xmlHeader: string = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
type
  # Raised when there's a problem with the file or file path.
  FileError = object of Exception
  attr = tuple[key, val: string]
  metaDataList* = tuple[metaType: MetaType, name: string, attrs: seq[attr], text: string]
  Epub3* = ref object
    len: int
    locationOnDisk: string
    # https://www.w3.org/publishing/epub3/epub-packages.html#sec-package-nav-def
    metaData: XmlNode
    manifest*: XmlNode
    spine: XmlNode
    tableOfContents: XmlNode
    tableOfContentsNavigator: XmlNode
    fileList: seq[string]

proc raiseFileError(extraMessage: string = "") =
  raise newException(FileError, "There was a problem with the file " & extraMessage)

##https://www.w3.org/publishing/epub3/epub-packages.html#sec-spine-elem

# Opens a valid Epub3 and loads the epub data.
proc OpenEpub3*(path: string): Epub3 =
  var epub: Epub3 = Epub3()
  var diskPath: string = path
  if not (fileExists(path) or dirExists(path)):
    raiseFileError("(Does Not Exist)")
  if getFileInfo(path).kind == pcFile:
    # Zippy does not work with reading/uncompressing files to memory one at a time with minimal memory impact.
    let tmD = join(diskPath.split(".")[0..^1], ".")
    extractAll(path, tmD)
    diskPath = tmD
  elif getFileInfo(path).kind != pcDir:
    raiseFileError("(Invalid File Type)")
  let metaInf: XmlNode = parseXml(readFile(diskPath / "META-INF" / "container.xml"))
  # Possible problems without parsing it on different systems.
  # TODO: Test on windows/linux machines, respectively.
  let pkgPath = join((diskPath / metaInf.child("rootfiles").child("rootfile").attr("full-path")).split("/")[0..^2], "/")
  let opf = parseXml(readFile(diskPath / metaInf.child("rootfiles").child("rootfile").attr("full-path")))
  epub.metaData = opf.child("metadata")
  epub.manifest = opf.child("manifest")
  epub.spine = opf.child("spine")
  for item in epub.manifest.items:
    if item.attr("id") != "toc": continue
    # Will most likely not work under the conditions that the href is "../"
    epub.tableOfContents = parsexml(readFile(pkgPath / item.attr("href")))
    break
  return epub
  
# Create's a blank Epub3.
proc CreateEpub3*(metaData: seq[metaDataList], path: string, excp: bool = true): Epub3 =
  var epub: Epub3 = Epub3()
  epub.locationOnDisk = path
  if epub.locationOnDisk[0..1] == "./" or epub.locationOnDisk[0..1] == ".\\":
    epub.locationOnDisk = getCurrentDir() / epub.locationOnDisk[2..^1]
  # Generate MetaData
  epub.metaData = GenXMLElementWithAttrs("metadata", {"xmlns:dc": "http://purl.org/dc/elements/1.1/"})
  # Add Elements To MetaData
  for i in metaData:
    var mdataElem: XmlNode
    if i.metaType == MetaType.dc:
      mdataElem = newElement($i.metaType & ":" & i.name)
    else:
      mdataElem = newElement($i.metaType & " " & i.name)
    mdataElem.attrs = i.attrs.toXmlAttributes
    mdataElem.add newText(i.text)
    epub.metaData.add mdataElem
  epub.metaData.add addMultipleNodes(GenXMLElementWithAttrs("dc:identifier", {"id": "pub-id"}), @[newText("pub-id")])
  # Generate Manifest, And Add TOC.
  epub.manifest = newElement("manifest")
  epub.manifest.add(GenXMLElementWithAttrs("item", {"id": "toc", "properties": "nav", "href": "TOC.xhtml", "media-type": "application/xhtml+xml"}))
  # Generate Spine w/ prog dir"
  epub.spine = GenXMLElementWithAttrs("spine", {"page-progression-direction": "ltr"})
  # Generate TOC, WITHOUT HTML body.
  epub.tableOfContentsNavigator = GenXMLElementWithAttrs("ol", {"epub:type": "list"})
  # Create default dirs (if not rebuilding)
  if excp:
    createDir(path)
    createDir(path / "META-INF")
    writeFile(path / "META-INF" / "container.xml", xmlHeader & "\n" & $addMultipleNodes(GenXMLElementWithAttrs("container", {"version": "1.0", "xmlns": "urn:oasis:names:tc:opendocument:xmlns:container"}), @[addMultipleNodes(newElement("rootfiles"), @[GenXMLElementWithAttrs("rootfile", {"full-path": "OPF/package.opf", "media-type": "application/oebps-package+xml"})])]))
    createDir(path / "OPF")
    createDir(path / "OPF" / "Pages")
    createDir(path / "OPF" / "Images")
  return epub

# Adds a page to the Epub3 manifest, spine.
proc AddPage*(this: Epub3, page: Page, relativePath = "Pages/", write: bool = true) =
  this.manifest.add(GenXMLElementWithAttrs("item", {"id": "s" & $this.len, "href": relativePath / page.name, "media-type": "application/xhtml+xml"}))
  this.spine.add(GenXMLElementWithAttrs("itemref", {"idref": "s" & $this.len}))
  var liElA = newElement("li")
  var a = GenXMLElementWithAttrs("a", {"href": relativePath / page.name})
  a.add newText(page.name[0..^7])
  liElA.add a
  this.tableOfContentsNavigator.add liElA
  if write:
    writeFile(this.locationOnDisk / "OPF" / relativePath & page.name, xmlHeader & "\n" & page.xhtml)
  inc this.len
# Opens an incomplete Epub3 from animeDL, and reforms it. It must be a folder, not a .epub archive.
proc OpenEpub3AndRebuild*(metaData: seq[metaDataList], path: string): Epub3 =
  var epub: Epub3 = CreateEpub3(metaData, path, false)
  # Rebuild TOC, Manifest.
  var images: seq[string] = @[]
  var pages: seq[string] = @[]
  var osType: bool = defined(windows)
  for i in walkDir(path / "OPF", true):
    if i.path == "Pages":
      for page in walkDir(path / "OPF" / "Pages"):
        pages.add page.path
  if pages.len <= 0 and images.len <= 0:
    raiseFileError("No content")
  #pages = sort(pages)
  #images = sort(images)
  for i in pages:
    epub.AddPage(Page(name: i.split('/')[^1], xhtml: readFile(i)), write = false)
  return epub
# Checks if the page exists within the Epub3 directory.
proc CheckPageExistance*(this: Epub3, nm: string): bool =
  for n in this.manifest.items:
    let name = n.attr("href").split('/')[^1].split('.')[0]
    if name != nm: continue
    return true
# To prevent hogging memory with image files, recommend calling this and unreferencing image bytes after write.
proc AddImage*(this: Epub3, image: Image, relativePath = "Images/") =
  assert image.name.split('.').len > 1
  this.manifest.add GenXMLElementWithAttrs("item", {"id": "s" & $this.len, "src": relativePath / image.name, "media-type": $(image.imageType)})
  # Compat issue in spine with non-xhtml components
  #this.spine.add GenXMLElementWithAttrs("itemref", {"idref": "s" & $this.len})
  inc this.len
  if relativePath == "":
    writeFile(this.locationOnDisk / image.name, image.bytes)
    return
  writeFile(this.locationOnDisk / "OPF" / relativePath & image.name, image.bytes)
# Generate a page from tiNodes.
proc GeneratePage*(name: string, tiNodes: seq[TiNode], relativeImagePath = "Images/"): Page =
  assert name != ""
  var xhtml: string = xhtmlifyTiNode(tiNodes, name, relativeImagePath)
  return Page(name: name & ".xhtml", xhtml: xhtml)
# Assign a cover to the Epub.
proc AssignCover*(this: Epub3, image: Image, relativePath = "") =
  this.manifest.add GenXMLElementWithAttrs("item", {"id": "cover", "href": "../" & image.name, "media-type": $(image.imageType)})
  # Compat issue in spine with non-xhtml components
  #this.spine.add GenXMLElementWithAttrs("itemref", {"idref": "cover"})
  this.metaData.add GenXMLElementWithAttrs("meta", {"content": "cover", "name": "cover"})
  writeFile(this.locationOnDisk / image.name, image.bytes)
proc AddGenPage*(this: Epub3, name: string, tiNodes: seq[TiNode]) =
  AddPage(this, GeneratePage(name, tiNodes))
  for node in tiNodes:
    if node.images.len == 0:
      break
    for image in node.images:
      AddImage(this, image)
# Export the epub to the location, which the epub was created.
proc FinalizeEpub*(this: Epub3) =
  var package = addMultipleNodes(GenXMLElementWithAttrs("package", {"xmlns": "http://www.idpf.org/2007/opf",
    "version": "3.0", "xml:lang": "en", "unique-identifier": "pub-id", "prefix": "rendition: http://www.idpf.org/vocab/rendition/#"}),
    @[this.metaData, this.manifest, this.spine])
  writeFile(this.locationOnDisk / "OPF" / "package.opf", xmlHeader & "\n" & $package)
  package = nil
  this.tableOfContents = addMultipleNodes(GenXMLElementWithAttrs("html", {"xmlns": "http://www.w3.org/1999/xhtml", "xmlns:epub": "http://www.idpf.org/2007/ops"}), @[addMultipleNodes(newElement("head"), @[GenXMLElementWithAttrs("meta", {"http-equiv": "default-style", "content": "text/html; charset=utf-8"}), addMultipleNodes(newElement("title"), @[newText("Contents")])]), addMultipleNodes(newElement("body"), @[addMultipleNodes(GenXMLElementWithAttrs("nav", {"epub:type": "toc"}), @[addMultipleNodes(newElement("h2"), @[newText("text")]), this.tableOfContentsNavigator])])])
  writeFile(this.locationOnDisk / "OPF" / "TOC.xhtml", xmlHeader & "\n" & $this.tableOfContents)
  this.tableOfContents = nil
  createZipArchive(this.locationOnDisk & "/", this.locationOnDisk[0..^2] & ".epub")
  removeDir(this.locationOnDisk)


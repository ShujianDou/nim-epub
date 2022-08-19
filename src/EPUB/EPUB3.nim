import std/[xmlparser, parsexml, xmltree, os, strutils, strtabs, enumutils]
import ./types, ./genericHelpers
import zippy/ziparchives

# Based off of https://www.w3.org/publishing/epub3/epub-overview.html#sec-nav
const xmlHeader: string = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
type
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

proc OpenEpub3*(path: string): Epub3 =
  var epub: Epub3 = Epub3()
  # Zippy does not work with reading/uncompressing files to memory one at a time with minimal memory impact.
  var diskPath: string = ""
  when defined windows:
    diskPath = ".\\" & path.split('\\')[^1]
  else:
    diskPath = "./" & path.split('/')[^1]
  extractAll(path, diskPath)
  #https://www.w3.org/publishing/epub3/epub-packages.html#sec-spine-elem
  let metaInf: XmlNode = parseXml(readFile(diskPath / "META-INF" / "container.xml"))
  # TODO: load opf from container, instead of trying to get an arbitrary directory.
  let navigator = parseXml(readFile(diskPath / "OPF" / "package.opf"))
  epub.metaData = navigator.child("metadata")
  epub.manifest = navigator.child("manifest")
  epub.spine = navigator.child("spine")
  for i in epub.spine.items:
    if i.attr("id") != "toc": continue
    epub.tableOfContents = parseXml(readFile(diskPath / "OPF" / i.attr("href")))
    break
  # TODO: READ

proc CreateEpub3*(metaData: seq[metaDataList], path: string): Epub3 =
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
  # Generate Manifest, And Add TOC.
  epub.manifest = newElement("manifest")
  epub.manifest.add(GenXMLElementWithAttrs("item", {"id": "toc", "properties": "nav", "href": "TOC.xhtml", "media-type": "application/xhtml+xml"}))
  # Generate Spine w/ prog dir"
  epub.spine = GenXMLElementWithAttrs("spine", {"page-progression-direction": "ltr"})
  # Generate TOC, WITHOUT HTML body.
  epub.tableOfContentsNavigator = GenXMLElementWithAttrs("ol", {"epub:type": "list"})
  # Create default dirs.
  createDir(path)
  createDir(path / "META-INF")
  writeFile(path / "META-INF" / "container.xml", xmlHeader & "\n" & $addMultipleNodes(GenXMLElementWithAttrs("container", {"version": "1.0", "xmlns": "urn:oasis:names:tc:opendocument:xmlns:container"}), @[addMultipleNodes(newElement("rootfiles"), @[GenXMLElementWithAttrs("rootfile", {"full-path": "OPF/package.opf", "media-type": "application/oebps-package+xml"})])]))
  createDir(path / "OPF")
  createDir(path / "OPF" / "Pages")
  createDir(path / "OPF" / "Images")
  return epub

proc AddPage*(this: Epub3, page: Page, relativePath = "Pages/") =
  this.manifest.add(GenXMLElementWithAttrs("item", {"id": "s" & $this.len, "href": relativePath / page.name, "media-type": "application/xhtml+xml"}))
  this.spine.add(GenXMLElementWithAttrs("itemref", {"idref": "s" & $this.len}))
  var liElA = newElement("li")
  var a = GenXMLElementWithAttrs("a", {"href": relativePath / page.name})
  a.add newText(page.name[0..^7])
  liElA.add a
  this.tableOfContentsNavigator.add liElA
  echo this.locationOnDisk
  writeFile(this.locationOnDisk / "OPF" / relativePath & page.name, xmlHeader & "\n" & page.xhtml)
  inc this.len

# To prevent hogging memory with image files, recommend calling this and unreferencing image bytes after write.
proc AddImage*(this: Epub3, image: Image, relativePath = "Image/") =
  assert image.name.split('.').len > 1
  this.manifest.add GenXMLElementWithAttrs("item", {"id": "s" & $this.len, "href": relativePath / image.name, "media-type": $(image.imageType)})
  this.spine.add GenXMLElementWithAttrs("itemref", {"idref": "s" & $this.len})
  writeFile(this.locationOnDisk / "OPF" / relativePath & image.name, image.bytes)
  inc this.len

proc GeneratePage*(name: string, tiNodes: seq[TiNode], relativeImagePath = "Images/"): Page =
  assert name != ""
  var xhtml: string = xhtmlifyTiNode(tiNodes, name, relativeImagePath)
  return Page(name: name & ".xhtml", xhtml: xhtml)

proc AssignCover*(this: Epub3, image: Image, relativePath = "") =
  this.manifest.add GenXMLElementWithAttrs("item", {"id": "cover", "href": "../" & image.name, "media-type": $(image.imageType)})
  this.spine.add GenXMLElementWithAttrs("itemref", {"idref": "cover"})
  this.metaData.add GenXMLElementWithAttrs("meta", {"name": "cover", "content": "cover"})
  AddImage(this, image, relativePath)

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


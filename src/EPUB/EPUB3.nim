import std/[xmlparser, parsexml, xmltree, os, strutils, strtabs]
import ./types, ./genericHelpers
import zippy/ziparchives

# Based off of https://www.w3.org/publishing/epub3/epub-overview.html#sec-nav
type
  attr = tuple[key, val: string]
  metaDataList = tuple[metaType: MetaType, name: string, attrs: seq[attr], text: string]
  Epub3* = ref object
    len: int
    locationOnDisk: string
    # https://www.w3.org/publishing/epub3/epub-packages.html#sec-package-nav-def
    metaData: XmlNode
    manifest: XmlNode
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
  # Generate Manifest, And Add TOC.
  epub.manifest = newElement("manifest")
  epub.manifest.add(GenXMLElementWithAttrs("item", {"properties": "nav", "href": "TOC.xhtml", "media-type": "application/xhtml+xml"}))
  # Generate Spine w/ prog dir"
  epub.spine = GenXMLElementWithAttrs("spine", {"page-progression-direction": "ltr"})
  # Generate TOC, WITHOUT HTML body.
  epub.tableOfContentsNavigator = GenXMLElementWithAttrs("ol", {"epub:type": "list"})
  # Create default dirs.
  createDir path / "META-INF"
  createDir path / "OPF"
  createDir path / "OPF" / "Pages"
  createDir path / "OPF" / "Images"


proc AddPage*(this: Epub3, name: string, xhtmlText: string, relativePath = "Pages/") =
  this.manifest.add(GenXMLElementWithAttrs("item", {"id": $this.len, "href": relativePath / name, "media-type": "application/xhtml+xml"}))
  this.spine.add(GenXMLElementWithAttrs("itemref", {"idref": $this.len}))
  var liElA = newElement("li")
  var a = GenXMLElementWithAttrs("a", {"href": relativePath / name})
  a.add newText(name)
  liElA.add a
  this.tableOfContentsNavigator.add liElA
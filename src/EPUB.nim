# Only supports EPUB 3.x;
#   would be more than happy to accept a PR for fixes/additions

import std/[strutils, strtabs, sequtils, htmlparser, xmlparser, xmltree, os]
# For archiving and decompressing the EPUB files.
import zippy/ziparchives

var PathSeparatorChar: char = '/'
when defined(windows):
  PathSeparatorChar = '\\'

type
  MetaType* = enum
      dc, meta
  ImageKind* = enum
    gif, jpeg, png, svg
  NodeKind* = enum
    paragraph = "p",
    header = "h1",
    ximage = "img",
    css = "css",
    ncx = "application/x-dtbncx+xml",
    oebps = "application/oebps-package+xml",
    xhtmlXml = "application/xhtml+xml",
    opfImageJ = "image/jpeg",
    opfImageP = "image/png",
    vol = "ol",
    pageSect = "li",
    package = "package"
  Image* = ref object
    fileName*: string
    kind*: ImageKind
    path*: string
  TiNode* = ref object
    kind*: NodeKind
    attrs*: XmlAttributes
    text*: string
    image*: Image
    children*: seq[TiNode]
  EpubItem* = ref object
    id*: string
    href*: string
    mediaType*: NodeKind
    properties*: string
  EpubRefItem* = ref object
    id*: string
    # Can only be no or yes
    linear*: string
  EpubMetaData* = ref object
    metaType*: MetaType
    name*: string
    attrs*: XmlAttributes
    text*: string
  Page* = ref object
    name*: string
    nodes*: seq[TiNode]
  Volume* = ref object
    name*: string
    pages*: seq[Page]
  Nav* = ref object
    title*: string
    nodes*: seq[TiNode]
  Epub3* = ref object
    len*: int
    path*: string
    packageDir*: string
    rootFile*: tuple[fullPath: string, mediaType: NodeKind]
    packageHeader*: TiNode
    metaData*: seq[EpubMetaData]
    manifest*: seq[EpubItem]
    spine*: tuple[propertyAttr: XmlAttributes, refItems: seq[EpubRefItem]]
    navigation*: Nav


proc mediaTypeLookUp(str: string): NodeKind =
  for e in NodeKind.items:
    if $e == str:
      return e
proc loadPackage(n: XmlNode): TiNode =
  let version: float = parseFloat(n.attr("version"))
  # Epub version check; no reason to load one higher or lower than 3
  assert (version >= 3.0f and version < 4.0f) 
  result = TiNode(kind: NodeKind.package, attrs: n.attrs)
proc loadMetaData(n: XmlNode): seq[EpubMetaData] =
  var mList: seq[EpubMetaData] = @[]
  for item in n.items:
    var data: EpubMetaData = EpubMetaData(attrs: item.attrs, text: item.innerText)
    let tag = item.tag.split(':')
    if tag[0] == "dc":
      data.metaType = MetaType.dc
      data.name = tag[1]
    else: data.metaType = MetaType.meta
    mList.add data
  result = mList
proc loadManifest(n: XmlNode): seq[EpubItem] =
  # It may be better to simply use XmlAttributes instead of an EpubItem object--
  var items: seq[EpubItem]
  for item in n.items:
    var eItem: EpubItem = EpubItem()
    for attr in item.attrs.pairs:
      case attr.key:
        of "id": eItem.id = attr.value
        of "media-type": eItem.mediaType = mediaTypeLookUp(attr.value)
        of "href": eItem.href = attr.value
        of "properties": eItem.properties = attr.value
        else:
          continue
    items.add eItem
  result = items
proc loadSpine(n: XmlNode): tuple[propertyAttr: XmlAttributes, refItems: seq[EpubRefItem]] =
  var items: seq[EpubRefItem] = @[]
  for refItem in n.items:
    var epbRefItem: EpubRefItem = EpubRefItem()
    for attr in refItem.attrs.pairs:
      case attr.key:
        of "idref": epbRefItem.id = attr.value
        of "linear": epbRefItem.linear = attr.value
        else: continue
    items.add epbRefItem
  result = (n.attrs, items)

# Load our EPUB and return Epub3 obj
proc LoadEpubFromDir*(path: string): Epub3 =
  # Check important dirs exist.
  assert dirExists(path / "META-INF")
  assert dirExists(path / "OPF")
  # If the root container file does not exist, we can not continue.
  assert fileExists(path / "META-INF" / "container.xml")
  var epub: Epub3 = Epub3(path: path)
  let rootNode = parseXml(readFile(path / "META-INF" / "container.xml")).child("rootfiles").child("rootfile")
  epub.rootFile = (rootNode.attr("full-path"), NodeKind.oebps)
  epub.packageDir = join(epub.rootFile.fullPath.split(PathSeparatorChar)[0..^2], $PathSeparatorChar)
  
  # Ensure package OPF exists before continuing...
  assert fileExists(path / epub.rootFile.fullPath)
  let packageXmlNode = parseXml(readFile(path / epub.rootFile.fullPath))
  
  # Load all OPF dependent items.
  epub.packageHeader = loadPackage(packageXmlNode)
  epub.metaData = loadMetaData(packageXmlNode.child("metadata"))
  epub.manifest = loadManifest(packageXmlNode.child("manifest"))
  epub.spine = loadSpine(packageXmlNode.child("spine"))
  
  result = epub

# Decompresses the files to a temporary directory 
#    before calling LoadEpubFromDir()
proc LoadEpubFile*(path: string): Epub3 =
  assert fileExists(path)
  let tempPath = getTempDir() / join(path.split(PathSeparatorChar)[^1].split('.')[0..^1])
  createDir(tempPath)
  extractAll(path, tempPath)
  # Return the result from the actual loading function.
  result = LoadEpubFromDir(tempPath)

# https://www.w3.org/publishing/epub3/epub-packages.html#sec-package-nav-def-types-other
proc parseTOCElements*(node: XmlNode, gName: string = ""): TiNode =
  var mNode = TiNode(kind: vol, text: gName, children: @[])
  let itemSeq = node.items.toSeq()
  var idx: int = 0
  while idx < itemSeq.len:
    let cNode = itemSeq[idx]
    if cNode.kind != xnElement:
      inc idxs
      continue
    # Use recursion in the case of a span tag, since it denotes objects underneath it.
    if cNode.tag == "span":
      inc idx
      mNode.children.add parseTOCElements(itemSeq[idx], cNode.innerText)
      inc idx
      continue
    # In the case of malformed TOC obj; we should never reach this.
    if cNode.tag == "a":
      mNode.kind = NodeKind.pageSect
      mNode.text = cNode.innerText
      mNode.attrs = cNode.attrs
      return mNode
    # Processes the normal <li></li> elements, which have the page information.
    if cNode.tag == "li":
      if cNode.items.toSeq().len > 1:
        mNode.children.add parseTOCElements(cNode)
        inc idx
        continue
      mNode.kind = NodeKind.pageSect
      let a: XmlNode = cNode.child("a")
      mNode.attrs = a.attrs
      mNode.text = a.innerText
      return mNode
    inc idx
  return mNode
    
    
# Loads the NAV object in to the Epub, returns nothing.
#   The NAV object has a list of TiNodes, which is in the order/format--
#     that pages should be displayed.
proc loadTOC*(epub: var Epub3) =
  var tocLink: string
  for manifestItem in epub.manifest:
    if manifestItem.properties != "nav":
      continue
    tocLink = manifestItem.href
    break
  assert fileExists(epub.path / epub.packageDir / tocLink)
  var navObj = Nav()
  let tocPage = parseHtml(readFile(epub.path / epub.packageDir / tocLink)).child("html")
  # Start loading objects in to our navigation object.
  navObj.title = tocPage.child("head").child("title").innerText
  let navElement = tocPage.child("body").child("nav")
  var lis: seq[TiNode] = @[]
  for olElement in navElement.child("ol").items:
    if olElement.kind != xnElement:
      continue
    lis.add parseTOCElements(olElement)
  navObj.nodes = lis
  result = navObj
#    var b = parseTOCElements(olElement)
#    echo b.text
#    for child in b.children:
#      echo "---[" & child.text & "]" 


#var l = LoadEpubFromDir("./ID")
#loadTOC(l)
import ./EPUB/Types/genericTypes
import ./EPUB/genericHelpers
import zip/zipfiles
import std/[streams, times, os, strutils, base64]

type Epub* = ref object
    title*, author*: string
    tableOfContents*: NCX
    opf*: OPFPackage
    opfMetaData*: OPFMetaData
    filePath: string
    #TODO: I will add support for volumes at a later date.

    archive: ZipArchive
    cover: ref Image
    pages: seq[Page]
    images: seq[Image]

method StartEpubExport*(this: Epub, filePath: string): bool =
    this.tableOfContents = NCX()
    this.tableOfContents.header.metaContent.add(Meta(content: "VrienCo", name: "dtb:uid", metaType: MetaType.meta))
    this.tableOfContents.header.metaContent.add(Meta(content: "1", name: "dtb:depth", metaType: MetaType.meta))
    this.tableOfContents.header.metaContent.add(Meta(content: "0", name: "dtb:totalPageCount", metaType: MetaType.meta))
    this.tableOfContents.header.metaContent.add(Meta(content: "0", name: "dtb:maxPageNumber", metaType: MetaType.meta))

    this.tableOfContents.title = DocTitle(name: this.title)
    this.tableOfContents.map = NavMap()
    this.filePath = filePath

    if not this.archive.open(filePath, fmWrite):
        echo "Failed To Open ZIP"
        quit(1)

    this.archive.addFile("META-INF/container.xml", newStringstream("<?xml version=\"1.0\" encoding=\"UTF-8\"?><container version = \"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"><rootfiles><rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\"/></rootfiles></container>"))
    this.archive.addFile("mimetype", newStringstream("application/epub+zip"))

    if this.cover != nil:
        this.archive.addFile("OEBPS/cover.jpeg", newFileStream(this.cover.location, fmRead))

    this.archive.close()
    return true

# COVER IN BYTES
method EndEpubExport*(this: Epub, bookID: string, publisher: string, cover: string): bool =
    discard this.archive.open(this.filePath, fmAppend)
    this.opfMetaData = OPFMetaData()
    #Generate OPF MetaData
    this.opfMetaData.metaDataObjects.add(Meta(content: (">$1" % [EscapeValues(this.title)]), name: "title", metaType: MetaType.dc))
    this.opfMetaData.metaDataObjects.add(Meta(content: ">en_US", name: "language", metaType: MetaType.dc))
    this.opfMetaData.metaDataObjects.add(Meta(content: "opf:role=\"auth\" opf:file-as=\"$1\">$1" % [EscapeValues(this.author)], name: "creator", metaType: MetaType.dc))
    this.opfMetaData.metaDataObjects.add(Meta(content: "id=\"BookID\" opf:scheme=\"URI\">$1" % [bookID], name: "identifier", metaType: MetaType.dc))
    this.opfMetaData.metaDataObjects.add(Meta(content: ">$1" % [EscapeValues(publisher)], name: "publisher", metaType: MetaType.dc))
    this.opfMetaData.metaDataObjects.add(Meta(content: "cover", name: "cover", metaType: MetaType.meta))
    this.opfMetaData.metaDataObjects.add(Meta(content: "1.0f", name: EscapeValues(this.author), metaType: MetaType.meta))
    #this.opfMetaData.metaDataObjects.add(Meta(content: "xmlns:opf=\"http://www.idpf.org/2007/opf\" opf:event=\"modification\">$1" % [$now()], name: "date", metaType: MetaType.dc))

    var manifest: Manifest = Manifest()
    this.tableOfContents.map = NavMap(points: @[])
    for page in this.pages:
        let pg = PageToItem(page)
        manifest.items.add(pg)
        this.tableOfContents.map.points.add(NavPoint(text: page.fileName, source: pg.href))
    for image in this.images:
        manifest.items.add(ImageToItem(image))

    if cover != "":
      manifest.items.add(Item(id: "cover", href: "../cover.jpeg", mediaType: MediaType.pImage))
      this.archive.addFile("cover.jpeg", newStringStream(cover))
    manifest.items.add(Item(id: "ncx", href: "toc.ncx", mediaType: MediaType.pImage))

    var spine: Spine = Spine(items: manifest.items)

    this.opf = OPFPackage(metaData: this.opfMetaData, manifest: manifest, spine: spine)

    #Export Finalize
    this.archive.addFile("OEBPS/content.opf", newStringstream(this.opf.ToString()))
    this.archive.addFile("OEBPS/toc.ncx", newStringStream(this.tableOfContents.ToString()))
    this.archive.addFile("OEBPS/cover.xhtml", newstringStream("<?xml version='1.0' encoding='utf-8'?><html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\"><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\"/><meta name=\"calibre:cover\" content=\"true\"/><title>Cover</title><style type=\"text/css\" title=\"override_css\">@page {padding: 0pt; margin:0pt}\nbody { text-align: center; padding:0pt; margin: 0pt; }</style></head><body><div><svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" version=\"1.1\" width=\"100%\" height=\"100%\" viewBox=\"0 0 741 1186\" preserveAspectRatio=\"none\"><image width=\"741\" height=\"1186\" xlink:href=\"../cover.jpeg\"/></svg></div></body></html>"))

    this.archive.close()
    return true

method AddPage*(this: Epub, page: Page): bool =
    discard this.archive.open(this.filePath, fmAppend)
    this.archive.addFile("OEBPS/Text/$1.xhtml" % [page.fileName], newStringStream(page.text))
    for p in page.images:
        this.archive.addFile("OEBPS/Pictures/$1.jpeg" % [p.name], newStringStream(p.bytes))
        p.bytes = newStringOfCap(0)
    # No need to keep bytes or text in memory.
    page.text = newStringOfCap(0)
    this.pages.add(page)
    this.archive.close()
    return true

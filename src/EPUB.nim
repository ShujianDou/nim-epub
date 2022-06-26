import ./EPUB/Types/genericTypes
import ./EPUB/genericHelpers
import zip/zipfiles
import std/streams

type Epub = ref object
    title, author: string
    tableOfContents: NCX
    opf: OPFPackage
    opfMetaData: OPFMetaData

    #TODO: I will add support for volumes at a later date.

    archive: ZipArchive
    cover: ref Image
    pages: seq[Page]

method StartEpubExport(this: Epub, filePath: string): bool =
    this.tableOfContents = NCX()
    this.tableOfContents.header.metaContent.add(Meta(content: "VrienCo", name: "dtb:uid", metaType: MetaType.meta))
    this.tableOfContents.header.metaContent.add(Meta(content: "1", name: "dtb:depth", metaType: MetaType.meta))
    this.tableOfContents.header.metaContent.add(Meta(content: "0", name: "dtb:totalPageCount", metaType: MetaType.meta))
    this.tableOfContents.header.metaContent.add(Meta(content: "0", name: "dtb:maxPageNumber", metaType: MetaType.meta))

    this.tableOfContents.title = DocTitle(name: this.title)
    this.tableOfContents.map = NavMap()

    if not this.archive.open(filePath, fmReadWrite):
        echo "Failed To Open ZIP"
        quit(1)

    this.archive.addFile("META-INF/container.xml", newStringstream("<?xml version=\"1.0\" encoding=\"UTF-8\"?><container version = \"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"><rootfiles><rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\"/></rootfiles></container>"))
    this.archive.addFile("mimetype", newStringstream("application/epub+zip"))

    if this.cover != nil:
        this.archive.addFile("OEBPS/cover.jpeg", newFileStream(this.cover.location, fmRead))
    return true

method EndEpubExport(this: Epub): bool =
    return false
method AddPage(this: Epub, page: Page): bool =
    return false




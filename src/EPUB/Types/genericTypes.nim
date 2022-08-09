import std/[sequtils, strutils, enumutils]

#This file is for the main types that are used within this EPUB library.
type
    #Enums
    MediaType* = enum
        pXhtml = "application/xhtml+xml", pImage = "image/jpeg", pNcx = "application/x-dtbncx+xml", pCss = "css"
    MetaType* = enum
        dc, meta
    #Objects
    Spine* = object
        items*: seq[Item]
    TOCHeader* = object
        metaContent*: seq[Meta]
    Image* = ref object
        name*: string
        location*: string
        #String, since we're using getContent, which returns string.
        bytes*: string
    Item* = object
        id*: string
        href*: string
        mediaType*: MediaType
    DocTitle* = object
        name*: string
    Meta* = object
        header*: string
        content*: string
        name*: string
        metaType*: MetaType
    Manifest* = object
        items*: seq[Item]
    NavPoint* = object
        id*, playOrder*, text*, source*: string
        isGrp*: bool
        titles*: seq[string]
        sources*: seq[string]
    NavMap* = object
        points*: seq[NavPoint]
    OPFMetaData* = object
        metaDataObjects*: seq[Meta]
    OPFPackage* = object
        metaData*: OPFMetaData
        manifest*: Manifest
        spine*: Spine

    #Important Objects
    TiNode* = ref object
        text*: string
        ignoreParsing*: bool
        images*: seq[Image]
        children*: seq[TiNode]
    NCX* = object
        str*: string
        header*: TOCHeader
        title*: DocTitle
        map*: NavMap
    Page* = ref object
        id*, text*, fileName*, location*: string
        images*: seq[Image]

method ToString*(this: Image): string = "<div class=\"svg_outer svg_inner\"><svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" height=\"99%\" width=\"100%\" version=\"1.1\" preserveAspectRatio=\"xMidYMid meet\" viewBox=\"0 0 1135 1600\"><image xlink:href=\"../Pictures/$1\" width=\"1135\" height=\"1600\"/></svg></div>" % [this.name]

method ToString*(this: DocTitle): string = "<docTitle><text>$1</text></docTitle>" % [this.name]

method ToString*(this: Item): string = "<item id=\"$1\" href=\"$2\" media-type=\"$3\"/>" % [this.id, this.href, $this.mediaType]

method ToString*(this: Meta): string =
    if this.metaType == MetaType.meta:
        return "<meta content=\"$1\" name=\"$2\"/>" % [this.content, this.name]
    else:
        return "<dc:$1 $2</dc:$1>" % [this.name, this.content]

method ToString*(this: NavMap): string =
    #https://www.w3.org/publishing/epub3/epub-packages.html#sec-manifest-elem
    var text: string = ""
    text.add("<navMap>\n")
    var i: int = 0
    while i < this.points.len:
        var point: NavPoint = this.points[i]
        if point.isGrp:
            text.add("<navPoint id=\"navPoint-$1\" playOrder=\"$2\"><navLabel><text>$3</text></navLabel>\n" % [$i, point.playOrder, point.text])
            var idx: int = 0
            while idx < point.sources.len:
                text.add("<navPoint id=\"navPoint-$1-$2\" playOrder=\"$3\"><navLabel><text>$3</text></navLabel><content src=\"$4\"/></navPoint>\n" % [$i, $idx, point.titles[idx], point.sources[idx]])
                inc idx
            text.add("</navPoint>\n")
        else:
            text.add("<navPoint id=\"navPoint-$1\" playOrder=\"$2\"><navLabel><text>$3</text></navLabel><content src=\"$4\"/></navPoint>\n" % [$i, $i, point.text, point.source])
        inc i
    text.add("</navMap>")
    return text

method ToString*(this: TOCHeader): string =
    var str: string = ""
    str.add("<head>\n")
    for meta in this.metaContent:
        str.add(meta.ToString() & "\n")
    str.add("</head>")
    return str

method ToString(this: OPFMetaData): string =
    var str: string = "<metadata xmlns:opf=\"http://www.idpf.org/2007/opf\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">\n"
    for data in this.metaDataObjects:
        str.add(data.ToString() & "\n")
    str.add("</metadata>")
    return str
method ToString(this: Manifest): string =
    var str: string = "<manifest>\n"
    for i in this.items:
        str.add(i.ToString() & "\n")
    str.add("</manifest>")
    return str

method ToString(this: Spine): string =
    var str: string = "<spine toc=\"ncx\">\n"
    for i in this.items:
        str.add("<itemref idref=\"$1\"/>" % [i.id] & "\n")
    str.add("</spine>")
    return str

method ToString*(this: OPFPackage): string =
    var str: string = "<package xmlns=\"http://www.idpf.org/2007/opf\" version=\"2.0\">\n"
    str.add(this.metaData.ToString() & "\n")
    str.add(this.manifest.ToString() & "\n")
    str.add(this.spine.ToString() & "\n")
    str.add("<guide><reference type=\"cover\" title=\"cover\" href=\"cover.xhtml\"/></guide>\n" & "</package>")
    return str

method ToString*(this: NCX): string =
    var str = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" & "<!DOCTYPE ncx PUBLIC \" -//NISO//DTD ncx 2005-1//EN\"\n\"http://www.daisy.org/z3986/2005/ncx-2005-1.dtd\"><ncx version = \"2005-1\" xmlns = \"http://www.daisy.org/z3986/2005/ncx/\" >\n"

    str.add(this.header.ToString() & "\n")
    str.add(this.title.ToString() & "\n")
    str.add(this.map.ToString() & "\n")
    str.add("</ncx>")
    return str

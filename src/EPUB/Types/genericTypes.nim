import std/[sequtils, strutils, enumutils]

#This file is for the main types that are used within this EPUB library.
type
    #Enums
    MediaType* = enum
        pXhtml = "xhtml", pImage = "image", pNcx = "ncx", pCss = "css"
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
        bytes*: seq[ref byte]
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
        images*: seq[ref Image]
        children*: seq[TiNode]
    NCX* = object
        str*: string
        header*: TOCHeader
        title*: DocTitle
        map*: NavMap
    Page* = ref object
        id*, text*, fileName*, location*: string
        images*: seq[ref Image]



converter toMediaType(n: string): MediaType = parseEnum[MediaType](n)
method ToString*(this: ref Image): string = "<div class=\"svg_outer svg_inner\"><svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" height=\"99%\" width=\"100%\" version=\"1.1\" preserveAspectRatio=\"xMidYMid meet\" viewBox=\"0 0 1135 1600\"><image xlink:href=\"$1.jpeg\" width=\"1135\" height=\"1600\"/></svg></div>" % [this.location]

method ToString(this: DocTitle): string = "<docTitle><text>$1</text></docTitle>" % [this.name]

method ToString(this: Item): string = "<item id=\"{id}\" href=\"{href}\" media-type=\"$1\"/>" % [symbolName(this.mediaType)]

method ToString(this: Meta): string =
    if this.metaType == MetaType.meta:
        return "<meta content=\"$1\" name=\"$2\"/>" % [this.content, this.name]
    else:
        return "<dc:$1 $2</dc:$1>" % [this.name, this.content]

method ToString(this: NavMap): string =
    #https://www.w3.org/publishing/epub3/epub-packages.html#sec-manifest-elem
    var text: string = ""
    text.add("<navMap>\n")
    var i: int = 0
    while i < this.points.len:
        var point: NavPoint = this.points[i]
        if point.isGrp:
            text.add("<navPoint id=\"navPoint-{point.id}\" playOrder=\"$1\"><navLabel><text>{point.text}</text></navLabel>\n" % [point.playOrder])
            var idx: int = 0
            while idx < point.sources.len:
                text.add("<navPoint id=\"navPoint-$1-$2\" playOrder=\"$2\"><navLabel><text>$3</text></navLabel><content src=\"$4\"/></navPoint>\n" % [point.id, $idx, point.titles[idx], point.sources[idx]])
                inc idx
            text.add("</navPoint>\n")
        else:
            text.add("<navPoint id=\"navPoint-$1\" playOrder=\"$2\"><navLabel><text>$3</text></navLabel><content src=\"$4\"/></navPoint>\n" % [point.id, point.playOrder, point.text, point.source])
        inc i
    text.add("</navMap>")
    return text


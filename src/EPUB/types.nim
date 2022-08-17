type
  #Enums
  MediaType* = enum
      pXhtml = "application/xhtml+xml", pImage = "image/jpeg", pNcx = "application/x-dtbncx+xml", pCss = "css",
  ImageType* = enum
    gif = "image/gif", jpeg = "image/jpeg", png = "image/png", svg = "image/svg+xml"
  AudioType* = enum
    mp3 = "audio/mpeg", mp4 = "audio/mp4"
  TextKind* = enum
    h = "h1", p = "p"
  MetaType* = enum
      dc, meta
  Image* = ref object
    name*: string
    imageType*: ImageType
    bytes*: string
  TiNode* = ref object
    kind*: TextKind
    text*: string
    images*: seq[Image]
    #children*: seq[TiNode]
  Page* = ref object
    name*: string
    xhtml*: string
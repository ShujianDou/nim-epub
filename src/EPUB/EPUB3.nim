import std[xmltree]
import zippy

# Based off of https://www.w3.org/publishing/epub3/epub-overview.html#sec-nav
type
  Epub3* = ref object
    locationOnDisk: string
    EpubNavigationDocument: XmlNode # https://www.w3.org/publishing/epub3/epub-packages.html#sec-package-nav-def
    fileList: seq[string]

proc OpenEpub3*(path: string): Epub3 =
  var epub: Epub3 = Epub3()
  # Zippy does not work with reading/uncompressing files to memory one at a time with minimal memory impact.
  when defined windows:
    extractAll(path, ".\\" & path.split('\\')[^1])
  else:
    extractAll(path, "./" & path.split('/')[^1])

  #https://www.w3.org/publishing/epub3/epub-packages.html#sec-spine-elem
  # TODO: READ
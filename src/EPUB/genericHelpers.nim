import std/[xmlparser, parsexml, xmltree, os, strutils, tables, enumutils]
import types

proc GenXMLElementWithAttrs*(title: string, t: varargs[tuple[key, val: string]]): XmlNode =
  var item: XmlNode = newElement(title)
  item.attrs = t.toXmlAttributes
  return item
type nestedElement* = ref object
  self: XmlNode
  children: seq[nestedElement]
proc InlineElementBuilder*(host: XmlNode, elems: seq[nestedElement]): XmlNode =
  for elem in elems:
    if elem.children.len > 0:
      discard InlineElementBuilder(elem.self, elem.children)
    host.add(elem.self)
  return host
proc addMultipleNodes*(host: XmlNode, nodes: seq[XmlNode]): XmlNode =
  for n in nodes:
    host.add n
  return host
proc xhtmlifyTiNode*(nodes: seq[TiNode], title: string, imgPath: string): string =
  var xhtmlNode: XmlNode = newElement("body")
  for n in nodes:
    if n.text != "":
      xhtmlNode.add(InlineElementBuilder(newElement(symbolName(n.kind)), @[nestedElement(self: newText(n.text), children: @[])]))
    for image in n.images:
      xhtmlNode.add GenXMLElementWithAttrs("img", {"href": "../" & imgPath / image.name})
    continue
  return $InlineElementBuilder(GenXMLElementWithAttrs("html", {"xmlns": "http://www.w3.org/1999/xhtml", "xmlns:epub": "http://www.idpf.org/2007/ops"}), @[nestedElement(self: addMultipleNodes(newElement("head"), @[GenXMLElementWithAttrs("meta", {"http-equiv": "default-style", "content": "text/html; charset=utf-8"}), addMultipleNodes(newElement("title"), @[newText(title)])]), children: @[]), nestedElement(self: xhtmlNode, children: @[])])
proc SanitizePageProp*(filename: string): string =
  var newStr: string = ""
  var oS = filename.toLowerAscii()
  for chr in oS:
    # what is regex
    if (ord(chr) >= ord('a') and ord(chr) <= ord('z')) or (ord(chr) >= ord('0') and ord(chr) <= ord('9')) or (ord(chr) == ord('_')) or (ord(chr) == ord('.')):
      newStr.add(chr)
  return newStr
proc GetNumInstances*(str: string): seq[int] =
  var numSeq: seq[int] = @[]
  var idx: int = 0
  while idx < str.len:
    let chr = str[idx]
    var cSeq: string = ""
    while chr >= '0' or chr <= '9' and idx < str.len:
      cSeq = cSeq & chr
      inc idx
      chr = str[idx]
    numSeq add parseInt(cSeq)
  return numSeq

proc `>`*(a,b: seq[int]): bool =
  var idx: int = 0
  while idx < a.len and idx < b.len:
    if a[idx] < b[idx]: return false
    if a[idx] > b[idx]: return true
    inc idx
  return a.len > b.len
proc `<`*(a,b: seq[int]): bool =
  var idx: int = 0
  while idx < b.len and idx < a.len:
    if b[idx] < a[idx]: return false
    if b[idx] > a[idx]: return true
    inc idx
  return b.len > a.len

proc sort(a: seq[string]): seq[string] =
  var idx: int = 0
  var idy: int = 0
  var swap: string = ""
  while idx < a.len:
    swap = a[idx]
    let maverick = GetNumInstances(swap)
    if maverick < 1: continue
    while idy < a.len:
      if maverick < GetNumInstances(a[idy]):
        a[idx] = a[idy]
        a[idy] = swap
        break
      inc idy
    idy = 0
    inc idx
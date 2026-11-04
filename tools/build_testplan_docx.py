"""Generate an editable Word TestPlan using standard-library OOXML."""
from pathlib import Path
from xml.sax.saxutils import escape
from zipfile import ZipFile, ZIP_DEFLATED
from xml.etree import ElementTree
import re

root=Path(__file__).resolve().parents[1]
def p(text,style='Normal'):
    return '<w:p><w:pPr><w:pStyle w:val="'+style+'"/></w:pPr><w:r><w:t xml:space="preserve">'+escape(text)+'</w:t></w:r></w:p>'
body=[]
rows=[]
def flush():
    if not rows: return
    content='<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/></w:tblPr>'
    for index,row in enumerate(rows):
        content+='<w:tr>'+('<w:trPr><w:tblHeader/></w:trPr>' if index==0 else '')
        content+=''.join('<w:tc><w:tcPr><w:tcW w:w="2400" w:type="dxa"/></w:tcPr>'+p(c)+'</w:tc>' for c in row)+'</w:tr>'
    body.append(content+'</w:tbl>'+p('')); rows.clear()
for line in (root/'docs/TestPlan.md').read_text(encoding='utf-8-sig').splitlines():
    if line.startswith('|'):
        cells=[c.strip() for c in line.strip('|').split('|')]
        if not all(re.fullmatch(':?-+:?',c) for c in cells): rows.append(cells)
    else:
        flush()
        if line.startswith('# '): body.append(p(line[2:],'Title'))
        elif line.startswith('## '): body.append(p(line[3:],'Heading1'))
        elif line: body.append(p(line))
flush()
document='<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>'+''.join(body)+'<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="900" w:right="720" w:bottom="900" w:left="720"/></w:sectPr></w:body></w:document>'
styles='''<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="21"/></w:rPr></w:rPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:pPr><w:spacing w:after="120"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:rPr><w:b/><w:sz w:val="36"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:pPr><w:keepNext/></w:pPr><w:rPr><w:b/><w:sz w:val="27"/></w:rPr></w:style>
<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:tblPr><w:tblBorders><w:top w:val="single" w:sz="4"/><w:left w:val="single" w:sz="4"/><w:bottom w:val="single" w:sz="4"/><w:right w:val="single" w:sz="4"/><w:insideH w:val="single" w:sz="4"/><w:insideV w:val="single" w:sz="4"/></w:tblBorders></w:tblPr></w:style>
</w:styles>'''
parts={
'[Content_Types].xml':'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>',
'_rels/.rels':'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
'word/_rels/document.xml.rels':'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
'word/document.xml':document,'word/styles.xml':styles}
target=root/'docs/TestPlan.docx'
with ZipFile(target,'w',ZIP_DEFLATED) as z:
    for name,content in parts.items():
        ElementTree.fromstring(content)
        z.writestr(name,'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+content)
with ZipFile(target) as z:
    assert z.testzip() is None
print('Created and XML-validated:',target)

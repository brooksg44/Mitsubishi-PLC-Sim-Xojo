#!/usr/bin/env python3
"""
Mitsubishi PLC Simulator - Xojo Binary Project Generator
Generates MitsubishiPLCSim.xojo_binary_project
"""
import struct, random, os

# ── helpers ──────────────────────────────────────────────────────────────────
def s(key, val):
    """String record: key(4) + Strn(4) + len(4) + data(pad4)"""
    b = val.encode('utf-8')
    pad = (4 - len(b) % 4) % 4
    return key.encode()[:4] + b'Strn' + struct.pack('>I', len(b)) + b + bytes(pad)

def i(key, val):
    """Integer record: key(4) + Int_(4) + val(4)"""
    return key.encode()[:4] + b'Int ' + struct.pack('>I', val & 0xFFFFFFFF)

_CTR = [0]

def grp(key, content):
    """Group record: key(4) + Grup(4) + size(4) + ctr(4) + content + EndGInt(12)"""
    _CTR[0] += 1
    ctr = _CTR[0]
    size = len(content) + 4          # content_len + 4 (counter field itself)
    end  = b'EndG' + b'Int ' + struct.pack('>I', ctr)
    return (key.encode()[:4] + b'Grup' +
            struct.pack('>I', size) + struct.pack('>I', ctr) +
            content + end)

def srcl(line):
    return s('srcl', line)

def method(name, params, ret, lines, is_event=False, shared=False, vis=1):
    gkey = 'HIns' if is_event else 'Meth'
    if ret:
        decl = 'Function %s(%s) As %s' % (name, params, ret)
        end_line = 'End Function'
    else:
        decl = 'Sub %s(%s)' % (name, params)
        end_line = 'End Sub'
    sorc_inner = i('Enco', 0x08000100)
    sorc_inner += srcl(decl)
    for line in lines:
        sorc_inner += srcl(line)
    sorc_inner += srcl(end_line)
    sorc = grp('sorc', sorc_inner)
    inner = (s('name', name) + s('Comp', '') + i('Vsbl', vis) +
             struct.pack('>4s', b'PtID') + b'Int ' + xojo_id() +
             sorc)
    if not is_event:
        # MethGrup needs outer parm/rslt fields — Xojo reads these for method signature
        # (HInsGrup event handlers don't need them; signature comes from event definition)
        # flag=0x00000000 = Public; flag=0x00000021 = Protected/Private
        inner += (i('Enco', 0x08000100) +
                  s('Alas', '') +
                  i('flag', 0x00000000) +
                  i('shrd', 1 if shared else 0) +
                  s('parm', params) +
                  s('rslt', ret))
    return grp(gkey, inner)

def prop_def(name, typ, vis=1, shared=False):
    """User-defined property declaration using Prop group format.
    Verified from AddressBook reference binary: uses Prop group with sorc+decl+flag.
    Array types: typ='Boolean()' → declaration 'Name() As Boolean' (parens on name)."""
    if typ.endswith('()'):
        base = typ[:-2]
        decl_str = '%s() As %s' % (name, base)
    else:
        decl_str = '%s As %s' % (name, typ)
    sorc_inner = i('Enco', 0x08000100)
    sorc_inner += srcl(decl_str)
    sorc_inner += srcl('')
    sorc = grp('sorc', sorc_inner)
    inner = (s('name', name) + s('Comp', '') + i('Vsbl', vis) +
             struct.pack('>4s', b'PtID') + b'Int ' + xojo_id() +
             sorc +
             i('Enco', 0x08000100) +
             s('decl', decl_str) +
             i('flag', 0x00000000) +
             i('shrd', 1 if shared else 0))
    return grp('Prop', inner)

def builtin_prop_val(name, typ, group='', vis=1, default=None, is_int=False, int_val=0):
    """PDef for built-in inherited property values (e.g. App.MenuBar)."""
    inner = s('name', name) + s('type', typ) + s('PrGp', group) + i('visi', vis)
    if is_int or typ in ('Integer', 'Single', 'Double', 'Int64', 'UInt64'):
        inner += i('PVal', int_val)
    elif typ == 'Boolean':
        inner += s('PVal', 'False')
    elif typ == 'String':
        val = '' if default is None else str(default)
        inner += i('Enco', 0x08000100 if val else 0x00000600) + s('PVal', val)
    else:
        inner += s('PVal', '0')
    return grp('PDef', inner)

def vw_pr(name, typ, group='', vis=1, default='', is_int=False, int_val=0, extra=b''):
    inner  = s('Name', name) + i('Vsbl', vis) + s('PrGp', group) + s('type', typ) + extra
    if default:
        inner += s('PVal', default)
    elif is_int:
        inner += i('PVal', int_val)
    return grp('VwPr', inner)

def vw_bh_empty():
    # Minimal VwBhGrup — matches the working reference format (size=4, empty content)
    return grp('VwBh', b'')

def code_obj(name, superclass, events=(), methods=(), pdefs=(), is_app=False):
    """BlokpObj content (App, DesktopCanvas subclass, etc.)"""
    body  = s('Name', name)
    body += i('Cont', 0)
    body += s('pasw', '')
    body += i('bCls', 1)
    body += s('Supr', superclass)
    body += i('flag', 1)
    body += i('bNtr', 0)
    if is_app:
        body += i('bApO', 1)
    body += s('Comp', '')
    for pd in pdefs:
        body += pd
    for ev in events:
        body += ev
    for me in methods:
        body += me
    body += vw_bh_empty()
    return body

def xojo_id():
    """Generate a Xojo-style block/object ID: 3 random bytes + 0xFF (always positive signed 32-bit)"""
    return struct.pack('>I', (random.randint(1, 0x7FFFFF) << 8) | 0xFF)

_IS_PROJ = [True]

def make_block(btype, content, force_id=None):
    """Complete Blok record padded to 1024-byte boundary"""
    if force_id is not None:
        bid = struct.pack('>I', force_id)
    elif _IS_PROJ[0]:
        bid = b'\x00\x00\x00\x00'   # BlokProj always has ID=0
        _IS_PROJ[0] = False
    else:
        bid = xojo_id()
    total = 32 + len(content)
    padded = ((total + 1023) // 1024) * 1024
    pad_needed = padded - total
    if pad_needed >= 8:
        padn = b'PadnPadn' + b'*' * (pad_needed - 8)
    else:
        padn = b'\x00' * pad_needed
    header = (b'Blok' + btype.encode()[:4] +
              bid + b'\x00\x00\x00\x00' +
              struct.pack('>I', padded) +
              b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')
    return header + content + padn

def make_bsts_block(parent_id):
    """Build Automation block (copied from existing binary pattern)"""
    body = s('Name','Build Automation') + i('Cont', parent_id) + s('pasw','')
    return make_block('BSts', body)

def make_bsls_block(plat, parent_id):
    body = s('Name', plat) + i('Cont', parent_id) + s('pasw','')
    return make_block('Bsls', body)

def make_bsbu_block(parent_id):
    body = s('Name','Build') + i('Cont', parent_id) + s('pasw','')
    return make_block('BSbu', body)

def make_bssn_block(parent_id):
    body = s('Name','Sign') + i('Cont', parent_id) + s('pasw','') + s('DeID','')
    return make_block('BSsn', body)

def irect(key, v1, v2, v3, v4):
    """4-integer Rect record (used in pUIs rEdtRect)"""
    return key.encode()[:4] + b'Rect' + struct.pack('>IIII', v1, v2, v3, v4)

def make_puis_block():
    # WrnPGrup: warning panel config — 7 name/data pairs matching the reference
    wrnp_body = b''
    for nm in (5, 6, 7, 14, 2, 0xFFFFFFFE, 16):
        wrnp_body += i('name', nm) + i('data', 0)
    # SwStGrup: editor state — minimal (no open file)
    seds_body = i('SEdC', 0)  # 0 editors open
    swst_body = (irect('rEdt', 0, 33, 1000, 949) +
                 i('MaxW', 0) +
                 grp('SEds', seds_body))
    body = grp('WrnP', wrnp_body) + grp('SwSt', swst_body)
    return make_block('pUIs', body, force_id=0)  # pUIs block ID always 0

# ═══════════════════════════════════════════════════════════════════════════════
# PLC SOURCE CODE
# ═══════════════════════════════════════════════════════════════════════════════

# ── PLCInstruction class ──────────────────────────────────────────────────────
PLC_INSTR_PROPS = [
    prop_def('OpCode',   'String'),
    prop_def('Operand1', 'String'),
    prop_def('Operand2', 'String'),
    prop_def('Operand3', 'String'),
    prop_def('LineNumber','Integer'),
    prop_def('IsLabel',  'Boolean'),
    prop_def('LabelName','String'),
]

PLC_INSTR_METHODS = [
    method('Constructor', 'line As String', '', [
        'Dim parts() As String',
        'parts = line.Trim.Split(" ")',
        'Dim n As Integer = UBound(parts)',
        'OpCode = parts(0).Uppercase',
        'If n >= 1 Then Operand1 = parts(1).Uppercase',
        'If n >= 2 Then Operand2 = parts(2).Uppercase',
        'If n >= 3 Then Operand3 = parts(3).Uppercase',
        '// Label detection',
        'If OpCode.Right(1) = ":" Then',
        '  IsLabel = True',
        '  LabelName = OpCode.Left(OpCode.Length - 1)',
        '  OpCode = "LABEL"',
        'End If',
        '// Handle comparison load opcodes: LD=, LD<>, LD<, LD>, LD<=, LD>=',
        'If OpCode.Left(2) = "LD" And OpCode.Length > 2 Then',
        '  // already fine - OpCode stores full token',
        'End If',
    ]),
    method('GetRegType', '', 'String', [
        'If Operand1 = "" Then Return ""',
        'Return Operand1.Left(1)',
    ]),
    method('RegIndex', '', 'Integer', [
        'If Operand1 = "" Then Return 0',
        '// Mitsubishi uses octal for X/Y bits, decimal for others',
        'Dim suffix As String = Operand1.Mid(2)',
        'Dim rt As String = Operand1.Left(1)',
        'If rt = "X" Or rt = "Y" Then',
        '  // X/Y addresses are octal in Mitsubishi notation',
        '  Return Val("&O" + suffix)',
        'Else',
        '  Return suffix.ToInteger',
        'End If',
    ]),
    method('KValue', 'operand As String', 'Integer', [
        'If operand = "" Then Return 0',
        'If operand.Left(1) = "K" Then Return operand.Mid(2).ToInteger',
        'If operand.Left(1) = "H" Then',
        '  Return Val("&H" + operand.Mid(2))',
        'End If',
        'Return operand.ToInteger',
    ]),
]

# ── PLCEngine class ───────────────────────────────────────────────────────────
MAX_X = 2048; MAX_Y = 2048; MAX_M = 8192
MAX_T = 512;  MAX_C = 256;  MAX_D = 8192

PLC_ENGINE_PROPS = [
    prop_def('XBits',    'Boolean()'),
    prop_def('YBits',    'Boolean()'),
    prop_def('YShadow',  'Boolean()'),
    prop_def('MBits',    'Boolean()'),
    prop_def('TCoil',    'Boolean()'),
    prop_def('TContact', 'Boolean()'),
    prop_def('TPreset',  'Integer()'),
    prop_def('TCurrent', 'Integer()'),
    prop_def('CCoil',    'Boolean()'),
    prop_def('CContact', 'Boolean()'),
    prop_def('CPreset',  'Integer()'),
    prop_def('CCurrent', 'Integer()'),
    prop_def('CPrevCoil','Boolean()'),
    prop_def('DRegs',    'Integer()'),
    prop_def('ZReg',     'Integer()'),
    prop_def('XPrev',    'Boolean()'),
    prop_def('YPrev',    'Boolean()'),
    prop_def('MPrev',    'Boolean()'),
    prop_def('MStack',   'Boolean()'),
    prop_def('MRStack',  'Boolean()'),
    prop_def('StkPtr',   'Integer'),
    prop_def('MCStack',  'Boolean()'),
    prop_def('MCPtr',    'Integer'),
    prop_def('Instructions', 'PLCInstruction()'),
    prop_def('ScanCount','Integer'),
    prop_def('IsRunning','Boolean'),
    prop_def('HasEnded', 'Boolean'),
    prop_def('LabelMap', 'Dictionary'),
    prop_def('SubStack', 'Integer()'),
    prop_def('SubPtr',   'Integer'),
]

PLC_ENGINE_METHODS = [
    method('Initialize', '', '', [
        'ReDim XBits(%d)' % (MAX_X-1),
        'ReDim YBits(%d)' % (MAX_Y-1),
        'ReDim YShadow(%d)' % (MAX_Y-1),
        'ReDim MBits(%d)' % (MAX_M-1),
        'ReDim TCoil(%d)' % (MAX_T-1),
        'ReDim TContact(%d)' % (MAX_T-1),
        'ReDim TPreset(%d)' % (MAX_T-1),
        'ReDim TCurrent(%d)' % (MAX_T-1),
        'ReDim CCoil(%d)' % (MAX_C-1),
        'ReDim CContact(%d)' % (MAX_C-1),
        'ReDim CPreset(%d)' % (MAX_C-1),
        'ReDim CCurrent(%d)' % (MAX_C-1),
        'ReDim CPrevCoil(%d)' % (MAX_C-1),
        'ReDim DRegs(%d)' % (MAX_D-1),
        'ReDim ZReg(7)',
        'ReDim XPrev(%d)' % (MAX_X-1),
        'ReDim YPrev(%d)' % (MAX_Y-1),
        'ReDim MPrev(%d)' % (MAX_M-1),
        'ReDim MStack(10)',
        'ReDim MRStack(10)',
        'ReDim MCStack(7)',
        'ReDim SubStack(31)',
        'StkPtr = 0',
        'MCPtr = 0',
        'SubPtr = 0',
        'ScanCount = 0',
        'IsRunning = False',
        'HasEnded = False',
        'LabelMap = New Dictionary',
    ]),
    method('LoadProgram', 'ilText As String', '', [
        'Dim lines() As String',
        'lines = ilText.Split(EndOfLine)',
        'ReDim Instructions(-1)',
        'LabelMap = New Dictionary',
        'Dim lineNo As Integer = 0',
        'For Each line As String In lines',
        '  Dim t As String = line.Trim',
        '  If t = "" Or t.Left(2) = "//" Or t.Left(1) = ";" Then',
        '    lineNo = lineNo + 1',
        '    Continue For',
        '  End If',
        '  // strip inline comments',
        '  Dim ci As Integer = t.IndexOf("//")',
        '  If ci >= 0 Then t = t.Left(ci).Trim',
        '  If t = "" Then',
        '    lineNo = lineNo + 1',
        '    Continue For',
        '  End If',
        '  Dim instr As New PLCInstruction(t)',
        '  instr.LineNumber = lineNo',
        '  If instr.IsLabel Then',
        '    LabelMap.Value(instr.LabelName) = UBound(Instructions) + 1',
        '  End If',
        '  Instructions.Append(instr)',
        '  lineNo = lineNo + 1',
        'Next',
        'StkPtr = 0',
        'MCPtr = 0',
        'SubPtr = 0',
        'HasEnded = False',
    ]),
    method('BeginScan', '', '', [
        '// Clear output shadow',
        'Dim i As Integer',
        'For i = 0 To %d' % (MAX_Y-1),
        '  YShadow(i) = False',
        'Next',
        'StkPtr = 0',
        'MCPtr = 0',
    ]),
    method('EndScan', '', '', [
        '// Copy output shadow to physical outputs',
        'Dim i As Integer',
        'For i = 0 To %d' % (MAX_Y-1),
        '  YBits(i) = YShadow(i)',
        'Next',
        '// Update timers (100ms per scan assumed)',
        'For i = 0 To %d' % (MAX_T-1),
        '  If TCoil(i) Then',
        '    If TCurrent(i) < TPreset(i) Then',
        '      TCurrent(i) = TCurrent(i) + 1',
        '    End If',
        '    If TCurrent(i) >= TPreset(i) And TPreset(i) > 0 Then',
        '      TContact(i) = True',
        '    End If',
        '  Else',
        '    TCurrent(i) = 0',
        '    TContact(i) = False',
        '  End If',
        'Next',
        '// Update counters (on rising edge of coil)',
        'For i = 0 To %d' % (MAX_C-1),
        '  If CCoil(i) And Not CPrevCoil(i) Then',
        '    CCurrent(i) = CCurrent(i) + 1',
        '    If CCurrent(i) >= CPreset(i) And CPreset(i) > 0 Then',
        '      CContact(i) = True',
        '    End If',
        '  End If',
        '  CPrevCoil(i) = CCoil(i)',
        'Next',
        'ScanCount = ScanCount + 1',
        '// Save state for edge detection AFTER scan outputs are settled',
        'Dim j As Integer',
        'For j = 0 To %d' % (MAX_X-1),
        '  XPrev(j) = XBits(j)',
        'Next',
        'For j = 0 To %d' % (MAX_Y-1),
        '  YPrev(j) = YBits(j)',
        'Next',
        'For j = 0 To %d' % (MAX_M-1),
        '  MPrev(j) = MBits(j)',
        'Next',
    ]),
    method('GetBit', 'rt As String, idx As Integer', 'Boolean', [
        'Select Case rt',
        'Case "X"',
        '  If idx >= 0 And idx < %d Then Return XBits(idx)' % MAX_X,
        'Case "Y"',
        '  If idx >= 0 And idx < %d Then Return YBits(idx)' % MAX_Y,
        'Case "M"',
        '  If idx >= 0 And idx < %d Then Return MBits(idx)' % MAX_M,
        'Case "T"',
        '  If idx >= 0 And idx < %d Then Return TContact(idx)' % MAX_T,
        'Case "C"',
        '  If idx >= 0 And idx < %d Then Return CContact(idx)' % MAX_C,
        'Case "SM"',
        '  Select Case idx',
        '  Case 400',
        '    Return True',
        '  Case 401',
        '    Return False',
        '  Case 402',
        '    Return (ScanCount = 0)',
        '  End Select',
        'End Select',
        'Return False',
    ]),
    method('GetRise', 'rt As String, idx As Integer', 'Boolean', [
        'Dim cur As Boolean = GetBit(rt, idx)',
        'Dim prev As Boolean = False',
        'Select Case rt',
        'Case "X"',
        '  If idx >= 0 And idx < %d Then prev = XPrev(idx)' % MAX_X,
        'Case "Y"',
        '  If idx >= 0 And idx < %d Then prev = YPrev(idx)' % MAX_Y,
        'Case "M"',
        '  If idx >= 0 And idx < %d Then prev = MPrev(idx)' % MAX_M,
        'End Select',
        'Return cur And Not prev',
    ]),
    method('GetFall', 'rt As String, idx As Integer', 'Boolean', [
        'Dim cur As Boolean = GetBit(rt, idx)',
        'Dim prev As Boolean = False',
        'Select Case rt',
        'Case "X"',
        '  If idx >= 0 And idx < %d Then prev = XPrev(idx)' % MAX_X,
        'Case "Y"',
        '  If idx >= 0 And idx < %d Then prev = YPrev(idx)' % MAX_Y,
        'Case "M"',
        '  If idx >= 0 And idx < %d Then prev = MPrev(idx)' % MAX_M,
        'End Select',
        'Return Not cur And prev',
    ]),
    method('SetBit', 'rt As String, idx As Integer, v As Boolean', '', [
        'Select Case rt',
        'Case "X"',
        '  If idx >= 0 And idx < %d Then XBits(idx) = v' % MAX_X,
        'Case "Y"',
        '  If idx >= 0 And idx < %d Then' % MAX_Y,
        '    YShadow(idx) = v',
        '    YBits(idx) = v',
        '  End If',
        'Case "M"',
        '  If idx >= 0 And idx < %d Then MBits(idx) = v' % MAX_M,
        'Case "T"',
        '  If idx >= 0 And idx < %d Then' % MAX_T,
        '    TContact(idx) = v',
        '    If Not v Then TCurrent(idx) = 0',
        '  End If',
        'Case "C"',
        '  If idx >= 0 And idx < %d Then' % MAX_C,
        '    If Not v Then',
        '      CCurrent(idx) = 0',
        '      CContact(idx) = False',
        '    End If',
        '  End If',
        'End Select',
    ]),
    method('GetWord', 'rt As String, idx As Integer', 'Integer', [
        'Select Case rt',
        'Case "D"',
        '  If idx >= 0 And idx < %d Then Return DRegs(idx)' % MAX_D,
        'Case "T"',
        '  If idx >= 0 And idx < %d Then Return TCurrent(idx)' % MAX_T,
        'Case "C"',
        '  If idx >= 0 And idx < %d Then Return CCurrent(idx)' % MAX_C,
        'Case "Z"',
        '  If idx >= 0 And idx <= 7 Then Return ZReg(idx)',
        'End Select',
        'Return 0',
    ]),
    method('SetWord', 'rt As String, idx As Integer, v As Integer', '', [
        'Select Case rt',
        'Case "D"',
        '  If idx >= 0 And idx < %d Then DRegs(idx) = v' % MAX_D,
        'Case "Z"',
        '  If idx >= 0 And idx <= 7 Then ZReg(idx) = v',
        'End Select',
    ]),
    method('ResolveWord', 'op As String', 'Integer', [
        '// Resolves K100, H1F, D0, T0, C0 etc to integer value',
        'If op = "" Then Return 0',
        'Dim rtyp As String = op.Left(1)',
        'Dim suf As String = op.Mid(2)',
        'Select Case rtyp',
        'Case "K"',
        '  Return suf.ToInteger',
        'Case "H"',
        '  Return Val("&H" + suf)',
        'Case "D"',
        '  Return GetWord("D", suf.ToInteger)',
        'Case "T"',
        '  Return GetWord("T", suf.ToInteger)',
        'Case "C"',
        '  Return GetWord("C", suf.ToInteger)',
        'Case "Z"',
        '  Return GetWord("Z", suf.ToInteger)',
        'Case "R"',
        '  Return GetWord("D", suf.ToInteger)',
        'End Select',
        'Return op.ToInteger',
    ]),
    method('ExecuteScan', '', '', [
        'If UBound(Instructions) < 0 Then Return',
        'BeginScan',
        'Dim acc As Boolean = False',
        'Dim pc As Integer = 0',
        'Dim maxPC As Integer = UBound(Instructions)',
        'Dim mcActive As Boolean = True',
        '',
        'While pc <= maxPC',
        '  Dim ins As PLCInstruction = Instructions(pc)',
        '  Dim op As String = ins.OpCode',
        '  Dim o1 As String = ins.Operand1',
        '  Dim o2 As String = ins.Operand2',
        '  Dim o3 As String = ins.Operand3',
        '  Dim rt As String = ins.GetRegType',
        '  Dim idx As Integer = ins.RegIndex',
        '',
        '  // Master control gate',
        '  Dim gated As Boolean = mcActive',
        '',
        '  Select Case op',
        '  // ── Basic contacts ──────────────────────────────────────',
        '  Case "LD"',
        '    acc = GetBit(rt, idx)',
        '  Case "LDI"',
        '    acc = Not GetBit(rt, idx)',
        '  Case "LDP"',
        '    acc = GetRise(rt, idx)',
        '  Case "LDF"',
        '    acc = GetFall(rt, idx)',
        '  Case "AND"',
        '    acc = acc And GetBit(rt, idx)',
        '  Case "ANI"',
        '    acc = acc And Not GetBit(rt, idx)',
        '  Case "ANDP"',
        '    acc = acc And GetRise(rt, idx)',
        '  Case "ANDF"',
        '    acc = acc And GetFall(rt, idx)',
        '  Case "OR"',
        '    acc = acc Or GetBit(rt, idx)',
        '  Case "ORI"',
        '    acc = acc Or Not GetBit(rt, idx)',
        '  Case "ORP"',
        '    acc = acc Or GetRise(rt, idx)',
        '  Case "ORF"',
        '    acc = acc Or GetFall(rt, idx)',
        '  // ── Block instructions ───────────────────────────────────',
        '  Case "ANB"',
        '    If StkPtr > 0 Then',
        '      StkPtr = StkPtr - 1',
        '      acc = MStack(StkPtr) And acc',
        '    End If',
        '  Case "ORB"',
        '    If StkPtr > 0 Then',
        '      StkPtr = StkPtr - 1',
        '      acc = MStack(StkPtr) Or acc',
        '    End If',
        '  // ── Stack ───────────────────────────────────────────────',
        '  Case "MPS"',
        '    If StkPtr <= 10 Then',
        '      MStack(StkPtr) = acc',
        '      StkPtr = StkPtr + 1',
        '    End If',
        '  Case "MRD"',
        '    If StkPtr > 0 Then acc = MStack(StkPtr - 1)',
        '  Case "MPP"',
        '    If StkPtr > 0 Then',
        '      StkPtr = StkPtr - 1',
        '      acc = MStack(StkPtr)',
        '    End If',
        '  // ── Output instructions ──────────────────────────────────',
        '  Case "OUT"',
        '    If gated Then',
        '      If rt = "Y" And idx >= 0 And idx < %d Then' % MAX_Y,
        '        YShadow(idx) = acc',
        '      ElseIf rt = "M" And idx >= 0 And idx < %d Then' % MAX_M,
        '        MBits(idx) = acc',
        '      ElseIf rt = "T" And idx >= 0 And idx < %d Then' % MAX_T,
        '        TCoil(idx) = acc',
        '        TPreset(idx) = ins.KValue(o2)',
        '      ElseIf rt = "C" And idx >= 0 And idx < %d Then' % MAX_C,
        '        CCoil(idx) = acc',
        '        CPreset(idx) = ins.KValue(o2)',
        '      End If',
        '    End If',
        '  Case "OUTP"  // Pulse output - follows power flow each scan',
        '    If gated Then SetBit rt, idx, acc',
        '  Case "SET"',
        '    If acc And gated Then SetBit rt, idx, True',
        '  Case "RST"',
        '    If acc And gated Then',
        '      If rt = "T" And idx >= 0 And idx < %d Then' % MAX_T,
        '        TCurrent(idx) = 0',
        '        TContact(idx) = False',
        '        TCoil(idx) = False',
        '      ElseIf rt = "C" And idx >= 0 And idx < %d Then' % MAX_C,
        '        CCurrent(idx) = 0',
        '        CContact(idx) = False',
        '        CPrevCoil(idx) = False',
        '      Else',
        '        SetBit rt, idx, False',
        '      End If',
        '    End If',
        '  // ── Comparison load contacts ─────────────────────────────',
        '  Case "LD="',
        '    acc = ResolveWord(o1) = ResolveWord(o2)',
        '  Case "LD<>"',
        '    acc = ResolveWord(o1) <> ResolveWord(o2)',
        '  Case "LD<"',
        '    acc = ResolveWord(o1) < ResolveWord(o2)',
        '  Case "LD>"',
        '    acc = ResolveWord(o1) > ResolveWord(o2)',
        '  Case "LD<="',
        '    acc = ResolveWord(o1) <= ResolveWord(o2)',
        '  Case "LD>="',
        '    acc = ResolveWord(o1) >= ResolveWord(o2)',
        '  Case "AND="',
        '    acc = acc And (ResolveWord(o1) = ResolveWord(o2))',
        '  Case "AND<>"',
        '    acc = acc And (ResolveWord(o1) <> ResolveWord(o2))',
        '  Case "AND<"',
        '    acc = acc And (ResolveWord(o1) < ResolveWord(o2))',
        '  Case "AND>"',
        '    acc = acc And (ResolveWord(o1) > ResolveWord(o2))',
        '  Case "AND<="',
        '    acc = acc And (ResolveWord(o1) <= ResolveWord(o2))',
        '  Case "AND>="',
        '    acc = acc And (ResolveWord(o1) >= ResolveWord(o2))',
        '  Case "OR="',
        '    acc = acc Or (ResolveWord(o1) = ResolveWord(o2))',
        '  Case "OR<>"',
        '    acc = acc Or (ResolveWord(o1) <> ResolveWord(o2))',
        '  Case "OR<"',
        '    acc = acc Or (ResolveWord(o1) < ResolveWord(o2))',
        '  Case "OR>"',
        '    acc = acc Or (ResolveWord(o1) > ResolveWord(o2))',
        '  Case "OR<="',
        '    acc = acc Or (ResolveWord(o1) <= ResolveWord(o2))',
        '  Case "OR>="',
        '    acc = acc Or (ResolveWord(o1) >= ResolveWord(o2))',
        '  // ── Application instructions ─────────────────────────────',
        '  Case "MOV"',
        '    If acc Then  // execute when power flows',
        '      SetWord o2.Left(1), o2.Mid(2).ToInteger, ResolveWord(o1)',
        '    End If',
        '  Case "MOVP"',
        '    If acc Then SetWord o2.Left(1), o2.Mid(2).ToInteger, ResolveWord(o1)',
        '  Case "ADD"',
        '    If acc Then',
        '      Dim r As Integer = ResolveWord(o1) + ResolveWord(o2)',
        '      SetWord o3.Left(1), o3.Mid(2).ToInteger, r',
        '    End If',
        '  Case "ADDP"',
        '    If acc Then',
        '      Dim r As Integer = ResolveWord(o1) + ResolveWord(o2)',
        '      SetWord o3.Left(1), o3.Mid(2).ToInteger, r',
        '    End If',
        '  Case "SUB"',
        '    If acc Then',
        '      Dim r As Integer = ResolveWord(o1) - ResolveWord(o2)',
        '      SetWord o3.Left(1), o3.Mid(2).ToInteger, r',
        '    End If',
        '  Case "SUBP"',
        '    If acc Then',
        '      Dim r As Integer = ResolveWord(o1) - ResolveWord(o2)',
        '      SetWord o3.Left(1), o3.Mid(2).ToInteger, r',
        '    End If',
        '  Case "MUL","MULP"',
        '    If acc Then',
        '      Dim r As Integer = ResolveWord(o1) * ResolveWord(o2)',
        '      SetWord o3.Left(1), o3.Mid(2).ToInteger, r',
        '    End If',
        '  Case "DIV","DIVP"',
        '    If acc Then',
        '      Dim dv As Integer = ResolveWord(o2)',
        '      If dv <> 0 Then',
        '        SetWord o3.Left(1), o3.Mid(2).ToInteger, ResolveWord(o1) \\ dv',
        '      End If',
        '    End If',
        '  Case "INC"',
        '    If acc Then',
        '      Dim cur As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)',
        '      SetWord o1.Left(1), o1.Mid(2).ToInteger, cur + 1',
        '    End If',
        '  Case "INCP"',
        '    If acc Then',
        '      Dim cur As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)',
        '      SetWord o1.Left(1), o1.Mid(2).ToInteger, cur + 1',
        '    End If',
        '  Case "DEC"',
        '    If acc Then',
        '      Dim cur As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)',
        '      SetWord o1.Left(1), o1.Mid(2).ToInteger, cur - 1',
        '    End If',
        '  Case "DECP"',
        '    If acc Then',
        '      Dim cur As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)',
        '      SetWord o1.Left(1), o1.Mid(2).ToInteger, cur - 1',
        '    End If',
        '  // ── Bit operations ───────────────────────────────────────',
        '  Case "BSET"',
        '    If acc Then',
        '      Dim bidx As Integer = ResolveWord(o2)',
        '      Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)',
        '      SetWord o1.Left(1), o1.Mid(2).ToInteger, w Or Bitwise.ShiftLeft(1, bidx)',
        '    End If',
        '  Case "BCLR"',
        '    If acc Then',
        '      Dim bidx As Integer = ResolveWord(o2)',
        '      Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)',
        '      SetWord o1.Left(1), o1.Mid(2).ToInteger, w And Not Bitwise.ShiftLeft(1, bidx)',
        '    End If',
        '  Case "BTEST"  // sets M based on bit test',
        '    If acc Then',
        '      Dim bidx As Integer = ResolveWord(o2)',
        '      Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)',
        '      Dim res As Boolean = (w And Bitwise.ShiftLeft(1, bidx)) <> 0',
        '      MBits(o3.Mid(2).ToInteger) = res',
        '    End If',
        '  // ── Word logical ops ─────────────────────────────────────',
        '  Case "WAND","WANDP"',
        '    If acc Then',
        '      Dim r As Integer = ResolveWord(o1) And ResolveWord(o2)',
        '      SetWord o3.Left(1), o3.Mid(2).ToInteger, r',
        '    End If',
        '  Case "WOR","WORP"',
        '    If acc Then',
        '      Dim r As Integer = ResolveWord(o1) Or ResolveWord(o2)',
        '      SetWord o3.Left(1), o3.Mid(2).ToInteger, r',
        '    End If',
        '  Case "WXOR","WXORP"',
        '    If acc Or op = "WXOR" Then',
        '      Dim r As Integer = ResolveWord(o1) Xor ResolveWord(o2)',
        '      SetWord o3.Left(1), o3.Mid(2).ToInteger, r',
        '    End If',
        '  Case "CML"   // complement',
        '    If acc Then',
        '      Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)',
        '      SetWord o2.Left(1), o2.Mid(2).ToInteger, Not w',
        '    End If',
        '  // ── Shift/Rotate ─────────────────────────────────────────',
        '  Case "SHL","SHLP"',
        '    If acc Then',
        '      Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)',
        '      SetWord o1.Left(1), o1.Mid(2).ToInteger, Bitwise.ShiftLeft(w, ResolveWord(o2))',
        '    End If',
        '  Case "SHR","SHRP"',
        '    If acc Then',
        '      Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)',
        '      SetWord o1.Left(1), o1.Mid(2).ToInteger, Bitwise.ShiftRight(w, ResolveWord(o2))',
        '    End If',
        '  Case "ROL","ROLP"',
        '    If acc Then',
        '      Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)',
        '      Dim n As Integer = ResolveWord(o2) Mod 16',
        '      w = (Bitwise.ShiftLeft(w, n) Or Bitwise.ShiftRight(w, 16 - n)) And 65535',
        '      SetWord o1.Left(1), o1.Mid(2).ToInteger, w',
        '    End If',
        '  Case "ROR","RORP"',
        '    If acc Then',
        '      Dim w As Integer = GetWord(o1.Left(1), o1.Mid(2).ToInteger)',
        '      Dim n As Integer = ResolveWord(o2) Mod 16',
        '      w = (Bitwise.ShiftRight(w, n) Or Bitwise.ShiftLeft(w, 16 - n)) And 65535',
        '      SetWord o1.Left(1), o1.Mid(2).ToInteger, w',
        '    End If',
        '  // ── Compare (result in M flags) ──────────────────────────',
        '  Case "CMP"',
        '    Dim s1 As Integer = ResolveWord(o1)',
        '    Dim s2 As Integer = ResolveWord(o2)',
        '    Dim mBase As Integer = o3.Mid(2).ToInteger',
        '    MBits(mBase)     = (s1 > s2)',
        '    MBits(mBase + 1) = (s1 = s2)',
        '    MBits(mBase + 2) = (s1 < s2)',
        '  // ── Program flow ─────────────────────────────────────────',
        '  Case "CJ"',
        '    If acc Then',
        '      Dim lbl As String = o1',
        '      If lbl.Left(1) = "P" Then lbl = lbl.Mid(2)',
        '      If LabelMap.HasKey(lbl) Then',
        '        pc = CType(LabelMap.Value(lbl), Integer)',
        '        Continue While',
        '      End If',
        '    End If',
        '  Case "JMP"',
        '    Dim lbl As String = o1',
        '    If lbl.Left(1) = "P" Then lbl = lbl.Mid(2)',
        '    If LabelMap.HasKey(lbl) Then',
        '      pc = CType(LabelMap.Value(lbl), Integer)',
        '      Continue While',
        '    End If',
        '  Case "CALL"',
        '    If acc Then',
        '      Dim lbl As String = o1',
        '      If lbl.Left(1) = "P" Then lbl = lbl.Mid(2)',
        '      If LabelMap.HasKey(lbl) And SubPtr < 31 Then',
        '        SubStack(SubPtr) = pc + 1',
        '        SubPtr = SubPtr + 1',
        '        pc = CType(LabelMap.Value(lbl), Integer)',
        '        Continue While',
        '      End If',
        '    End If',
        '  Case "RET"',
        '    If SubPtr > 0 Then',
        '      SubPtr = SubPtr - 1',
        '      pc = SubStack(SubPtr)',
        '      Continue While',
        '    End If',
        '  Case "MC"   // Master Control - o1=N level, o2=M coil',
        '    If MCPtr < 7 Then',
        '      MCStack(MCPtr) = mcActive',
        '      MCPtr = MCPtr + 1',
        '    End If',
        '    mcActive = acc',
        '  Case "MCR"  // Master Control Reset',
        '    If MCPtr > 0 Then',
        '      MCPtr = MCPtr - 1',
        '      mcActive = MCStack(MCPtr)',
        '    Else',
        '      mcActive = True',
        '    End If',
        '  Case "LABEL"  // internal label marker - skip',
        '    // nothing',
        '  Case "FEND"   // end of main program body',
        '    Exit While',
        '  Case "END"',
        '    HasEnded = True',
        '    Exit While',
        '  Case "NOP"',
        '    // nothing',
        '  End Select',
        '  pc = pc + 1',
        'Wend',
        '',
        'EndScan',
    ]),
    method('GetRegisterDump', '', 'String', [
        'Dim sb As String = ""',
        'Dim i As Integer',
        'sb = sb + "=== INPUT BITS (X) ===" + EndOfLine',
        'For i = 0 To 15',
        '  sb = sb + "X" + i.ToString + "=" + If(XBits(i),"1","0") + " "',
        '  If (i+1) Mod 8 = 0 Then sb = sb + EndOfLine',
        'Next',
        'sb = sb + EndOfLine + "=== OUTPUT BITS (Y) ===" + EndOfLine',
        'For i = 0 To 15',
        '  sb = sb + "Y" + i.ToString + "=" + If(YBits(i),"1","0") + " "',
        '  If (i+1) Mod 8 = 0 Then sb = sb + EndOfLine',
        'Next',
        'sb = sb + EndOfLine + "=== INTERNAL RELAYS (M) ===" + EndOfLine',
        'For i = 0 To 15',
        '  sb = sb + "M" + i.ToString + "=" + If(MBits(i),"1","0") + " "',
        '  If (i+1) Mod 8 = 0 Then sb = sb + EndOfLine',
        'Next',
        'sb = sb + EndOfLine + "=== TIMERS (T) ===" + EndOfLine',
        'For i = 0 To 7',
        '  sb = sb + "T" + i.ToString + " PV=" + TPreset(i).ToString + " CV=" + TCurrent(i).ToString + " DN=" + If(TContact(i),"1","0") + " "',
        'Next',
        'sb = sb + EndOfLine + "=== COUNTERS (C) ===" + EndOfLine',
        'For i = 0 To 7',
        '  sb = sb + "C" + i.ToString + " PV=" + CPreset(i).ToString + " CV=" + CCurrent(i).ToString + " DN=" + If(CContact(i),"1","0") + " "',
        'Next',
        'sb = sb + EndOfLine + "=== DATA REGS (D) ===" + EndOfLine',
        'For i = 0 To 15',
        '  sb = sb + "D" + i.ToString + "=" + DRegs(i).ToString + " "',
        '  If (i+1) Mod 8 = 0 Then sb = sb + EndOfLine',
        'Next',
        'Return sb',
    ]),
]

# ── PLCCanvas class (DesktopCanvas subclass) ──────────────────────────────────
PLC_CANVAS_PROPS = [
    prop_def('Engine', 'PLCEngine'),
    prop_def('ScrollY','Integer'),
]

DRAW_RUNG_LINES = [
    '// Draw one rung of the ladder diagram',
    '// Called from Paint event',
    'Sub DrawRung(g As Graphics, ins() As PLCInstruction, startIdx As Integer, endIdx As Integer, x As Integer, y As Integer)',
    '  Const RH As Integer = 50    // rung height',
    '  Const EW As Integer = 60    // element width',
    '  Const EH As Integer = 24    // element height',
    '  g.DrawLine(0, y + RH\\2, x, y + RH\\2)     // left power rail',
    '  Dim cx As Integer = x',
    '  Dim branchY As Integer = y',
    '  Dim branchX As Integer = cx',
    '  Dim inBranch As Boolean = False',
    '  Dim branchAcc As Boolean = False',
    '  Dim branchStartX As Integer = cx',
    '  ',
    '  Dim k As Integer = startIdx',
    '  Do While k <= endIdx',
    '    Dim ins1 As PLCInstruction = ins(k)',
    '    Dim op1 As String = ins1.OpCode',
    '    Dim o1 As String = ins1.Operand1',
    '    Dim rt As String = ins1.GetRegType',
    '    Dim idx As Integer = ins1.RegIndex',
    '    Dim state As Boolean = If(Engine <> Nil, Engine.GetBit(rt, idx), False)',
    '    ',
    '    Select Case op1',
    '    Case "LD","LDI","LDP","LDF"',
    '      DrawContact(g, cx, y + RH\\2 - EH\\2, EW, EH, o1, state, op1)',
    '      cx = cx + EW',
    '    Case "AND","ANI","ANDP","ANDF"',
    '      DrawContact(g, cx, y + RH\\2 - EH\\2, EW, EH, o1, state, op1)',
    '      cx = cx + EW',
    '    Case "OR","ORI","ORP","ORF"',
    '      // Parallel branch starts below',
    '      inBranch = True',
    '      branchStartX = cx - EW',
    '      branchY = y + RH',
    '      DrawContact(g, branchStartX, branchY + RH\\2 - EH\\2, EW, EH, o1, state, op1)',
    '      branchX = branchStartX + EW',
    '    Case "OUT","OUTI","OUTP"',
    '      DrawCoil(g, cx, y + RH\\2 - EH\\2, EW, EH, o1, state, op1)',
    '      cx = cx + EW',
    '    Case "SET","RST"',
    '      DrawCoilSR(g, cx, y + RH\\2 - EH\\2, EW, EH, o1, state, op1)',
    '      cx = cx + EW',
    '    Case Else',
    '      DrawFunctionBlock(g, cx, y + RH\\2 - EH\\2, EW*2, EH*2, op1, o1, ins1.Operand2)',
    '      cx = cx + EW*2',
    '    End Select',
    '    k = k + 1',
    '  Loop',
    '  ',
    '  // Close parallel branch',
    '  If inBranch Then',
    '    g.DrawLine(branchStartX, y + RH\\2, branchStartX, branchY + RH\\2)',
    '    g.DrawLine(branchX, branchY + RH\\2, cx, branchY + RH\\2)',
    '    g.DrawLine(cx, y + RH\\2, cx, branchY + RH\\2)',
    '  End If',
    '  ',
    '  // Connect to right power rail',
    '  g.DrawLine(cx, y + RH\\2, g.Width - 2, y + RH\\2)',
    'End Sub',
]

PLC_CANVAS_EVENTS = [
    method('Paint', 'g As Graphics, areas() As Rect', '', [
        'g.AntiAlias = False',
        'g.DrawingColor = Color.White',
        'g.FillRectangle(0, 0, g.Width, g.Height)',
        '',
        'If Engine Is Nil Or UBound(Engine.Instructions) < 0 Then',
        '  g.DrawingColor = &c888888',
        '  g.DrawText("No program loaded. Enter IL code and click Load.", 20, g.Height\\2)',
        '  Return',
        'End If',
        '',
        'Const RAIL_W As Integer = 4',
        'Const LEFT_X As Integer = 80',
        'Dim RIGHT_X As Integer = g.Width - 80',
        'Const RUNG_H As Integer = 70',
        'Const ELEM_W As Integer = 70',
        'Const ELEM_H As Integer = 28',
        'Dim COIL_X As Integer = RIGHT_X - 90',
        '',
        '// Draw power rails',
        'g.DrawingColor = &c001080',
        'g.FillRectangle(0, 0, RAIL_W, g.Height)',
        'g.FillRectangle(g.Width - RAIL_W, 0, RAIL_W, g.Height)',
        '',
        '// Parse instructions into rungs',
        '// A rung begins with LD/LDI/LDP/LDF and ends with OUT/SET/RST/END',
        'Dim y As Integer = 10 - ScrollY',
        'Dim rungStart As Integer = 0',
        'Dim ins As PLCInstruction',
        'Dim n As Integer = UBound(Engine.Instructions)',
        'Dim rungNum As Integer = 1',
        '',
        'Do',
        '  Dim rungEnd As Integer = rungStart',
        '  // Find end of this rung (first OUT/SET/RST/END/NOP after contacts)',
        '  Dim k As Integer = rungStart',
        '  Dim contactX As Integer = LEFT_X + RAIL_W',
        '  Dim hasPower As Boolean = False',
        '  Dim lastCoilIdx As Integer = -1',
        '',
        '  // Draw rung number',
        '  g.DrawingColor = &c666666',
        '  g.DrawText(rungNum.ToString, 8, y + RUNG_H\\2 + 5)',
        '',
        '  // Draw horizontal rung bus',
        '  g.DrawingColor = &c001080',
        '  g.DrawLine(RAIL_W, y + RUNG_H\\2, g.Width - RAIL_W, y + RUNG_H\\2)',
        '',
        '  // Draw elements',
        '  Dim cx As Integer = LEFT_X',
        '  Dim branchOpen As Boolean = False',
        '  Dim branchTopX As Integer = cx',
        '  Dim branchBotY As Integer = y + RUNG_H + 10',
        '  Dim branchBotX As Integer = cx',
        '',
        '  While k <= n',
        '    ins = Engine.Instructions(k)',
        '    Dim op As String = ins.OpCode',
        '    Dim o1 As String = ins.Operand1',
        '    Dim rt As String = ins.GetRegType',
        '    Dim bi As Integer = ins.RegIndex',
        '    Dim bstate As Boolean = If(Engine <> Nil, Engine.GetBit(rt, bi), False)',
        '    Dim isActive As Boolean = bstate',
        '',
        '    Select Case op',
        '    Case "LD","LDI","LDP","LDF","AND","ANI","ANDP","ANDF"',
        '      // Series contact',
        '      Dim nc As Boolean = (op = "LDI" Or op = "ANI" Or op = "ANDF")',
        '      Dim pe As Boolean = (op.Right(1) = "P")',
        '      Dim fe As Boolean = (op.Right(1) = "F")',
        '      If nc Then isActive = Not isActive',
        '      DrawContactElement(g, cx, y + RUNG_H\\2 - ELEM_H\\2, ELEM_W, ELEM_H, o1, isActive, nc, pe, fe)',
        '      cx = cx + ELEM_W',
        '    Case "LD=","LD<>","LD<","LD>","LD<=","LD>=","AND=","AND<>","AND<","AND>","AND<=","AND>="',
        '      DrawContactElement(g, cx, y + RUNG_H\\2 - ELEM_H\\2, ELEM_W, ELEM_H, ins.Operand1 + If(op.Left(3) = "AND", op.Mid(4), op.Mid(3)) + ins.Operand2, False, False, False, False)',
        '      cx = cx + ELEM_W',
        '    Case "OR","ORI","ORP","ORF"',
        '      // Parallel branch - draw below current rung',
        '      If Not branchOpen Then',
        '        branchOpen = True',
        '        branchTopX = cx - ELEM_W',
        '        branchBotY = y + RUNG_H + 8',
        '      End If',
        '      Dim nc As Boolean = (op = "ORI" Or op = "ORF")',
        '      Dim bst As Boolean = If(Engine <> Nil, Engine.GetBit(ins.GetRegType, ins.RegIndex), False)',
        '      If nc Then bst = Not bst',
        '      DrawContactElement(g, branchBotX, branchBotY, ELEM_W, ELEM_H, o1, bst, nc, (op.Right(1)="P"), (op.Right(1)="F"))',
        '      branchBotX = branchBotX + ELEM_W',
        '    Case "ORB"',
        '      // Close parallel branch',
        '      If branchOpen Then',
        '        g.DrawingColor = &c001080',
        '        g.DrawLine(branchTopX, y + RUNG_H\\2, branchTopX, branchBotY + ELEM_H\\2)',
        '        g.DrawLine(cx, y + RUNG_H\\2, cx, branchBotY + ELEM_H\\2)',
        '        g.DrawLine(branchTopX, branchBotY + ELEM_H\\2, cx, branchBotY + ELEM_H\\2)',
        '        branchOpen = False',
        '      End If',
        '    Case "MPS"',
        '      // Stack push - just a junction dot',
        '      g.DrawingColor = &c001080',
        '      g.FillOval(cx - 4, y + RUNG_H\\2 - 4, 8, 8)',
        '    Case "MRD","MPP"',
        '      // Stack read/pop - junction dot',
        '      g.DrawingColor = &c001080',
        '      g.FillOval(cx - 4, y + RUNG_H\\2 - 4, 8, 8)',
        '    Case "OUT","OUTP"',
        '      // Output coil',
        '      Dim ost As Boolean = If(Engine <> Nil, Engine.GetBit(ins.GetRegType, ins.RegIndex), False)',
        '      DrawCoilElement(g, COIL_X, y + RUNG_H\\2 - ELEM_H\\2, ELEM_W, ELEM_H, o1, ost, False)',
        '      lastCoilIdx = k',
        '    Case "SET"',
        '      Dim ost As Boolean = If(Engine <> Nil, Engine.GetBit(ins.GetRegType, ins.RegIndex), False)',
        '      DrawCoilElement(g, COIL_X, y + RUNG_H\\2 - ELEM_H\\2, ELEM_W, ELEM_H, "S:" + o1, ost, False)',
        '      lastCoilIdx = k',
        '    Case "RST"',
        '      Dim ost As Boolean = If(Engine <> Nil, Engine.GetBit(ins.GetRegType, ins.RegIndex), False)',
        '      DrawCoilElement(g, COIL_X, y + RUNG_H\\2 - ELEM_H\\2, ELEM_W, ELEM_H, "R:" + o1, ost, True)',
        '      lastCoilIdx = k',
        '    Case "MOV","MOVP","ADD","ADDP","SUB","SUBP","MUL","MULP","DIV","DIVP","CMP","INC","INCP","DEC","DECP","BSET","BCLR","BTEST","SHL","SHLP","SHR","SHRP","ROL","ROLP","ROR","RORP","WAND","WANDP","WOR","WORP","WXOR","WXORP","CML","CALL","CJ","JMP","MC","MCR"',
        '      DrawFBElement(g, COIL_X - ELEM_W, y + RUNG_H\\2 - ELEM_H, ELEM_W*2, ELEM_H*2, op, o1, ins.Operand2, ins.Operand3)',
        '      lastCoilIdx = k',
        '    Case "END","FEND","NOP","LABEL"',
        '      lastCoilIdx = k',
        '      k = k + 1',
        '      Exit While',
        '    End Select',
        '',
        '    k = k + 1',
        '    // Start new rung on next LD/LDI after an output',
        '    If k <= n Then',
        '      Dim nop As String = Engine.Instructions(k).OpCode',
        '      If (nop.Left(2) = "LD") And lastCoilIdx >= 0 Then',
        '        Exit While',
        '      ElseIf nop = "MRD" Or nop = "MPP" Then',
        '        Exit While',
        '      End If',
        '    End If',
        '  Wend',
        '',
        '  rungStart = k',
        '  y = y + RUNG_H + (If(branchOpen Or branchBotX > LEFT_X, 60, 0))',
        '  rungNum = rungNum + 1',
        '  If rungStart > n Then Exit Do',
        'Loop',
    ], is_event=True),
]

PLC_CANVAS_METHODS = [
    method('DrawContactElement', 'g As Graphics, x As Integer, y As Integer, w As Integer, h As Integer, lbl As String, active As Boolean, nc As Boolean, isRise As Boolean, isFall As Boolean', '', [
        'Dim clr As Color = If(active, &c0000FF, &c444444)',
        'g.DrawingColor = clr',
        '// Horizontal lines above and below contact',
        'g.DrawLine(x, y + h\\2, x + 8, y + h\\2)',
        'g.DrawLine(x + w - 8, y + h\\2, x + w, y + h\\2)',
        '// Left bar',
        'g.DrawLine(x + 8, y + 2, x + 8, y + h - 2)',
        '// Right bar',
        'g.DrawLine(x + w - 8, y + 2, x + w - 8, y + h - 2)',
        '// Normally closed diagonal',
        'If nc Then g.DrawLine(x + 8, y + h - 2, x + w - 8, y + 2)',
        '// Rising/Falling edge markers',
        'If isRise Then',
        '  g.DrawText("P", x + w\\2 - 4, y - 2)',
        'ElseIf isFall Then',
        '  g.DrawText("N", x + w\\2 - 4, y - 2)',
        'End If',
        '// Label',
        'g.DrawingColor = &c001080',
        'g.DrawText(lbl, x + w\\2 - g.TextWidth(lbl)\\2, y + h + 12)',
        '// Power glow',
        'If active Then',
        '  g.DrawingColor = &c0000FF',
        '  g.FillRectangle(x + 9, y + 3, w - 18, h - 6)',
        'End If',
    ]),
    method('DrawCoilElement', 'g As Graphics, x As Integer, y As Integer, w As Integer, h As Integer, lbl As String, active As Boolean, isReset As Boolean', '', [
        'Dim clr As Color = If(active, &cFF4400, &c444444)',
        'g.DrawingColor = clr',
        '// Horizontal connections',
        'g.DrawLine(x, y + h\\2, x + 8, y + h\\2)',
        'g.DrawLine(x + w - 8, y + h\\2, x + w, y + h\\2)',
        '// Circle for coil',
        'g.DrawOval(x + 8, y + 2, w - 16, h - 4)',
        '// Reset coil extra line',
        'If isReset Then g.DrawLine(x + 8, y + h - 2, x + w - 8, y + 2)',
        '// Active fill',
        'If active Then',
        '  g.DrawingColor = &cFF4400',
        '  g.FillOval(x + 9, y + 3, w - 18, h - 6)',
        'End If',
        '// Label',
        'g.DrawingColor = &c001080',
        'g.DrawText(lbl, x + w\\2 - g.TextWidth(lbl)\\2, y + h + 12)',
    ]),
    method('DrawFBElement', 'g As Graphics, x As Integer, y As Integer, w As Integer, h As Integer, op As String, o1 As String, o2 As String, o3 As String', '', [
        'g.DrawingColor = &c333333',
        'g.DrawRectangle(x, y, w, h)',
        'g.DrawingColor = &c001080',
        'g.DrawText(op, x + w\\2 - g.TextWidth(op)\\2, y + 14)',
        'g.DrawingColor = Color.Black',
        'Dim info As String = o1',
        'If o2 <> "" Then info = info + " " + o2',
        'If o3 <> "" Then info = info + " " + o3',
        'g.DrawText(info, x + 4, y + 28)',
        '// Connect to rung',
        'g.DrawingColor = &c001080',
        'g.DrawLine(x - 10, y + h\\2, x, y + h\\2)',
    ]),
]

# ── MainWindow class ──────────────────────────────────────────────────────────
SAMPLE_IL = """// === Program 1: Basic I/O (Timer, Counter, Latch) ===
// X0: start T0 timer (1s), T0 -> Y0
// X1: pulse C0 counter (target 5), C0 -> Y1
// X2: reset counter C0
// X3: SET M0 latch, X4: RST M0 latch, M0 -> Y2
// X5: when on, add D0+D1 -> D2 (use Set Reg to set D0/D1)
// Comparison contact: D2>K100 -> Y3

LD X0
OUT T0 K10

LD T0
OUT Y0

LD X1
OUT C0 K5

LD C0
OUT Y1

LD X2
RST C0

LD X3
SET M0

LD X4
RST M0

LD M0
OUT Y2

LD X5
ADD D0 D1 D2

LD> D2 K100
OUT Y3

END"""

SAMPLE_IL_2 = """// === Program 2: Arithmetic & Compare ===
// X0: load D0=25, D1=10; compute D2..D5
//   D2=D0+D1=35  D3=D0-D1=15  D4=D0*D1=250  D5=D0/D1=2
// X1: INC D6 each scan
// X2: DEC D7 each scan
// CMP D0 D1 M0 -> M0=(D0>D1), M1=(D0=D1), M2=(D0<D1)
// Y0/Y1/Y2 reflect compare result

LD X0
MOV K25 D0

LD X0
MOV K10 D1

LD X0
ADD D0 D1 D2

LD X0
SUB D0 D1 D3

LD X0
MUL D0 D1 D4

LD X0
DIV D0 D1 D5

LD X1
INC D6

LD X2
DEC D7

LD> D0 D1
OUT Y0

LD= D0 D1
OUT Y1

LD< D0 D1
OUT Y2

END"""

SAMPLE_IL_3 = """// === Program 3: Stack Operations (MPS/MRD/MPP) ===
// X0 is master; X1->Y0, X2->Y1, X3->Y2, direct->Y3
// MPS saves X0 state; MRD peeks for each branch; MPP pops last

LD X0
MPS
AND X1
OUT Y0
MRD
AND X2
OUT Y1
MRD
AND X3
OUT Y2
MPP
OUT Y3

// Rung 2: X4 master; X5 -> SET M1, NOT X5 -> RST M1
LD X4
MPS
AND X5
SET M1
MPP
ANI X5
RST M1

LD M1
OUT Y4

// Rung 3: three outputs share one condition (X0)
LD X0
MPS
MOV K100 D0
MRD
MOV K200 D1
MPP
ADD D0 D1 D2

END"""

SAMPLE_IL_4 = """// === Program 4: Bit & Word Operations ===
// Use Set Reg to set D0 to a value (e.g. D0=0)
// X0: set bit 4 of D0  (OR with 16)
// X1: clear bit 4 of D0
// X2: test bit 4 -> M0 -> Y0
// X3: D1 = D0 AND K255  (lower byte mask)
// X4: D2 = D0 OR K256   (force bit 8 high)
// X5: shift/rotate on D3..D6

LD X0
BSET D0 K4

LD X1
BCLR D0 K4

LD X2
BTEST D0 K4 M0

LD M0
OUT Y0

LD X3
MOV K255 D10
WAND D0 D10 D1

LD X4
MOV K256 D11
WOR D0 D11 D2

LD X5
MOV K3 D3
SHL D3 K2

LD X5
MOV K12 D4
SHR D4 K2

LD X5
MOV K1 D5
ROL D5 K1

LD X5
MOV K2 D6
ROR D6 K1

END"""

SAMPLE_IL_5 = """// === Program 5: Subroutines & Conditional Jumps ===
// Set D0=10 D1=20 via Set Reg first
// X0: CALL subroutine 1 -> D2=D0+D1=30, D3=D0*D1=200
// X1: CJ P2 - when ON, skips MOV K999 D5
// X2: JMP P3 - when ON, skips MOV K888 D6

LD X0
CALL P1

LD> D2 K0
OUT Y0

LD X1
CJ P2

LD X0
MOV K999 D5

2:

LD X2
JMP P3

LD X0
MOV K888 D6

3:

LD X0
OUT Y1

FEND

// Subroutine 1: D2 = D0+D1, D3 = D0*D1
1:
ADD D0 D1 D2
MUL D0 D1 D3
RET

END"""

SAMPLE_IL_6 = """// === Program 6: Timer & Counter Patterns ===
// X0: on-delay timer T0 (1 second=K10) -> Y0
// X1: auto-repeat oscillator T1 (2s) -> Y1 pulses
// X2: count presses -> C0 target 5 -> Y2
// X3: reset C0
// X4: falling edge of X4 sets M2 -> Y3; X5 clears it

LD X0
OUT T0 K10

LD T0
OUT Y0

LD X1
ANI T1
OUT T1 K20

LD T1
OUT Y1

LD X2
OUT C0 K5

LD X3
RST C0

LD C0
OUT Y2

LDF X4
SET M2

LD X5
RST M2

LD M2
OUT Y3

END"""

SAMPLES = [SAMPLE_IL, SAMPLE_IL_2, SAMPLE_IL_3, SAMPLE_IL_4, SAMPLE_IL_5, SAMPLE_IL_6]
SAMPLE_NAMES = [
    "1: Basic I/O (Timer/Counter/Latch)",
    "2: Arithmetic (ADD/SUB/MUL/DIV/CMP)",
    "3: Stack (MPS/MRD/MPP)",
    "4: Bit & Word Ops (BSET/SHL/WAND)",
    "5: Subroutines & Jumps (CALL/CJ/JMP)",
    "6: Timer & Counter Patterns",
]

def make_xojo_str(text):
    """Embed multi-line text as a Xojo string concatenation."""
    lines = text.strip().split('\n')
    parts = ['"' + l.replace('\\', '\\\\').replace('"', '\\"') + '"' for l in lines]
    return ' + EndOfLine + '.join(parts)

MAIN_WINDOW_PROPS = [
    prop_def('Engine',     'PLCEngine'),
    prop_def('ScanTimer',  'Timer'),
    prop_def('LDView',     'PLCCanvas'),
    prop_def('ILEdit',     'DesktopTextArea'),
    prop_def('SampleMenu', 'DesktopPopupMenu'),
    prop_def('RegList',    'DesktopTextArea'),
    prop_def('SetRegField','DesktopTextField'),
    prop_def('StatusLbl',  'DesktopLabel'),
    prop_def('ScanLbl',    'DesktopLabel'),
    prop_def('X0Btn',      'DesktopButton'),
    prop_def('X1Btn',      'DesktopButton'),
    prop_def('X2Btn',      'DesktopButton'),
    prop_def('X3Btn',      'DesktopButton'),
    prop_def('X4Btn',      'DesktopButton'),
    prop_def('X5Btn',      'DesktopButton'),
]

MAIN_WINDOW_EVENTS = [
    method('Opening', '', '', [
        'Self.Title = "Mitsubishi MELSEC PLC Simulator"',
        'Self.Width = 1400',
        'Self.Height = 820',
        '',
        '// Create PLC Engine',
        'Engine = New PLCEngine',
        'Engine.Initialize',
        '',
        '// ── Toolbar (top 50px) ─────────────────────────────',
        'Const TB As Integer = 50',
        '',
        'Dim loadBtn As New DesktopButton',
        'loadBtn.Caption = "Load IL"',
        'loadBtn.Left = 10',
        'loadBtn.Top = 8',
        'loadBtn.Width = 90',
        'loadBtn.Height = 34',
        'Self.AddControl(loadBtn)',
        'AddHandler loadBtn.Pressed, AddressOf LoadBtn_Pressed',
        '',
        'Dim runBtn As New DesktopButton',
        'runBtn.Caption = "▶ RUN"',
        'runBtn.Left = 110',
        'runBtn.Top = 8',
        'runBtn.Width = 90',
        'runBtn.Height = 34',
        'Self.AddControl(runBtn)',
        'AddHandler runBtn.Pressed, AddressOf RunBtn_Pressed',
        '',
        'Dim stopBtn As New DesktopButton',
        'stopBtn.Caption = "■ STOP"',
        'stopBtn.Left = 210',
        'stopBtn.Top = 8',
        'stopBtn.Width = 90',
        'stopBtn.Height = 34',
        'Self.AddControl(stopBtn)',
        'AddHandler stopBtn.Pressed, AddressOf StopBtn_Pressed',
        '',
        'Dim stepBtn As New DesktopButton',
        'stepBtn.Caption = "» STEP"',
        'stepBtn.Left = 310',
        'stepBtn.Top = 8',
        'stepBtn.Width = 90',
        'stepBtn.Height = 34',
        'Self.AddControl(stepBtn)',
        'AddHandler stepBtn.Pressed, AddressOf StepBtn_Pressed',
        '',
        'Dim resetBtn As New DesktopButton',
        'resetBtn.Caption = "↺ RESET"',
        'resetBtn.Left = 410',
        'resetBtn.Top = 8',
        'resetBtn.Width = 90',
        'resetBtn.Height = 34',
        'Self.AddControl(resetBtn)',
        'AddHandler resetBtn.Pressed, AddressOf ResetBtn_Pressed',
        '',
        'StatusLbl = New DesktopLabel',
        'StatusLbl.Text = "STOP"',
        'StatusLbl.Left = 520',
        'StatusLbl.Top = 12',
        'StatusLbl.Width = 120',
        'StatusLbl.Height = 26',
        'Self.AddControl(StatusLbl)',
        '',
        'ScanLbl = New DesktopLabel',
        'ScanLbl.Text = "Scan: 0"',
        'ScanLbl.Left = 660',
        'ScanLbl.Top = 12',
        'ScanLbl.Width = 140',
        'ScanLbl.Height = 26',
        'Self.AddControl(ScanLbl)',
        '',
        'Dim scrollUpBtn As New DesktopButton',
        'scrollUpBtn.Caption = Chr(9650)',
        'scrollUpBtn.Left = 806',
        'scrollUpBtn.Top = 8',
        'scrollUpBtn.Width = 34',
        'scrollUpBtn.Height = 34',
        'Self.AddControl(scrollUpBtn)',
        'AddHandler scrollUpBtn.Pressed, AddressOf ScrollUp_Pressed',
        '',
        'Dim scrollDnBtn As New DesktopButton',
        'scrollDnBtn.Caption = Chr(9660)',
        'scrollDnBtn.Left = 842',
        'scrollDnBtn.Top = 8',
        'scrollDnBtn.Width = 34',
        'scrollDnBtn.Height = 34',
        'Self.AddControl(scrollDnBtn)',
        'AddHandler scrollDnBtn.Pressed, AddressOf ScrollDown_Pressed',
        '',
        '// ── Input toggles ─────────────────────────────────',
        'Dim xLbl As New DesktopLabel',
        'xLbl.Text = "Inputs:"',
        'xLbl.Left = 880',
        'xLbl.Top = 14',
        'xLbl.Width = 60',
        'xLbl.Height = 24',
        'Self.AddControl(xLbl)',
        '',
        'Dim xLabels() As String',
        'xLabels = Array("X0","X1","X2","X3","X4","X5")',
        'Dim xBtns() As DesktopButton',
        'ReDim xBtns(5)',
        'Dim xi As Integer',
        'For xi = 0 To 5',
        '  Dim xb As New DesktopButton',
        '  xb.Caption = xLabels(xi)',
        '  xb.Left = 950 + xi * 70',
        '  xb.Top = 8',
        '  xb.Width = 62',
        '  xb.Height = 34',
        '  Self.AddControl(xb)',
        '  xBtns(xi) = xb',
        'Next',
        'AddHandler xBtns(0).Pressed, AddressOf X0_Pressed',
        'AddHandler xBtns(1).Pressed, AddressOf X1_Pressed',
        'AddHandler xBtns(2).Pressed, AddressOf X2_Pressed',
        'AddHandler xBtns(3).Pressed, AddressOf X3_Pressed',
        'AddHandler xBtns(4).Pressed, AddressOf X4_Pressed',
        'AddHandler xBtns(5).Pressed, AddressOf X5_Pressed',
        '',
        '// ── Ladder Diagram Canvas ─────────────────────────',
        'LDView = New PLCCanvas',
        'LDView.Engine = Engine',
        'LDView.Left = 0',
        'LDView.Top = TB',
        'LDView.Width = 900',
        'LDView.Height = 550',
        'LDView.LockLeft = True',
        'LDView.LockTop = True',
        'LDView.LockBottom = True',
        'Self.AddControl(LDView)',
        '',
        '// ── Sample selector ───────────────────────────────',
        'SampleMenu = New DesktopPopupMenu',
        'SampleMenu.Left = 902',
        'SampleMenu.Top = TB',
        'SampleMenu.Width = 354',
        'SampleMenu.Height = 34',
] + [
        'SampleMenu.AddRow "%s"' % n for n in SAMPLE_NAMES
] + [
        'Self.AddControl(SampleMenu)',
        'Dim loadSmpBtn As New DesktopButton',
        'loadSmpBtn.Caption = "Load Sample"',
        'loadSmpBtn.Left = 1260',
        'loadSmpBtn.Top = TB',
        'loadSmpBtn.Width = 138',
        'loadSmpBtn.Height = 34',
        'Self.AddControl(loadSmpBtn)',
        'AddHandler loadSmpBtn.Pressed, AddressOf LoadSample_Pressed',
        '',
        '// ── IL Editor ─────────────────────────────────────',
        'ILEdit = New DesktopTextArea',
        'ILEdit.Left = 902',
        'ILEdit.Top = TB + 40',
        'ILEdit.Width = 498',
        'ILEdit.Height = 510',
        'ILEdit.Multiline = True',
        'ILEdit.LockRight = True',
        'ILEdit.LockTop = True',
        'ILEdit.LockLeft = False',
        'ILEdit.Text = "' + SAMPLE_IL.replace('"', '\\"').replace('\n', '" + EndOfLine + "') + '"',
        'Self.AddControl(ILEdit)',
        '',
        '// ── Register Monitor ──────────────────────────────',
        '// ── Set Register row ───────────────────────────────',
        'Dim setLbl As New DesktopLabel',
        'setLbl.Text = "Set Reg (e.g. D0=100, X0=1):"',
        'setLbl.Left = 4',
        'setLbl.Top = TB + 556',
        'setLbl.Width = 240',
        'setLbl.Height = 26',
        'Self.AddControl(setLbl)',
        'SetRegField = New DesktopTextField',
        'SetRegField.Left = 248',
        'SetRegField.Top = TB + 552',
        'SetRegField.Width = 160',
        'SetRegField.Height = 34',
        'Self.AddControl(SetRegField)',
        'Dim setBtn As New DesktopButton',
        'setBtn.Caption = "Set"',
        'setBtn.Left = 414',
        'setBtn.Top = TB + 552',
        'setBtn.Width = 60',
        'setBtn.Height = 34',
        'Self.AddControl(setBtn)',
        'AddHandler setBtn.Pressed, AddressOf SetRegBtn_Pressed',
        '',
        '// ── Register Monitor ──────────────────────────────',
        'RegList = New DesktopTextArea',
        'RegList.Left = 0',
        'RegList.Top = TB + 592',
        'RegList.Width = 1400',
        'RegList.Height = 178',
        'RegList.ReadOnly = True',
        'RegList.LockBottom = True',
        'RegList.LockLeft = True',
        'RegList.LockRight = True',
        'Self.AddControl(RegList)',
        '',
        '// ── Scan Timer ────────────────────────────────────',
        'ScanTimer = New Timer',
        'ScanTimer.Period = 100',
        'ScanTimer.Mode = 2',
        'AddHandler ScanTimer.Action, AddressOf ScanTimer_Action',
        '',
        '// Load the sample program',
        'LoadCurrentProgram',
    ], is_event=True),
]

MAIN_WINDOW_METHODS = [
    method('LoadCurrentProgram', '', '', [
        'Engine.LoadProgram(ILEdit.Text)',
        'LDView.Refresh',
        'UpdateRegisters',
        'StatusLbl.Text = "STOP  (" + CStr(UBound(Engine.Instructions)) + "+1 instr)"',
    ]),
    method('LoadBtn_Pressed', 'sender As DesktopButton', '', [
        'LoadCurrentProgram',
    ]),
    method('RunBtn_Pressed', 'sender As DesktopButton', '', [
        'Engine.IsRunning = True',
        'ScanTimer.Mode = 2',
        'StatusLbl.Text = "RUN"',
    ]),
    method('StopBtn_Pressed', 'sender As DesktopButton', '', [
        'Engine.IsRunning = False',
        'ScanTimer.Mode = 0',
        'StatusLbl.Text = "STOP"',
    ]),
    method('StepBtn_Pressed', 'sender As DesktopButton', '', [
        'Engine.ExecuteScan',
        'LDView.Refresh',
        'UpdateRegisters',
        'ScanLbl.Text = "Scan: " + Engine.ScanCount.ToString',
    ]),
    method('ResetBtn_Pressed', 'sender As DesktopButton', '', [
        'Engine.Initialize',
        'Engine.LoadProgram(ILEdit.Text)',
        'LDView.Refresh',
        'UpdateRegisters',
        'ScanLbl.Text = "Scan: 0"',
        'StatusLbl.Text = "RESET"',
    ]),
    method('ScanTimer_Action', 'sender As Timer', '', [
        'If Not Engine.IsRunning Then Return',
        'Engine.ExecuteScan',
        'LDView.Refresh',
        'UpdateRegisters',
        'ScanLbl.Text = "Scan: " + Engine.ScanCount.ToString',
    ]),
    method('UpdateRegisters', '', '', [
        'RegList.Text = Engine.GetRegisterDump',
    ]),
    method('GetSample', 'idx As Integer', 'String',
        ['Select Case idx'] +
        sum([['Case %d' % i, '  Return %s' % make_xojo_str(s)] for i, s in enumerate(SAMPLES)], []) +
        ['End Select', 'Return ""']
    ),
    method('LoadSample_Pressed', 'sender As DesktopButton', '', [
        'Engine.Initialize',
        'ILEdit.Text = GetSample(SampleMenu.SelectedRowIndex)',
        'LoadCurrentProgram',
    ]),
    method('ApplySetReg', '', '', [
        'Dim input As String = SetRegField.Text.Trim',
        'If input = "" Then Return',
        'Dim eqPos As Integer = input.IndexOf("=")',
        'If eqPos < 0 Then Return',
        'Dim regName As String = input.Left(eqPos).Trim.Uppercase',
        'Dim valStr As String = input.Mid(eqPos + 2).Trim',
        'Dim val As Integer = valStr.ToInteger',
        'Dim rt As String = regName.Left(1)',
        'Dim idx As Integer = regName.Mid(2).ToInteger',
        'If rt = "D" Or rt = "T" Or rt = "C" Then',
        '  Engine.SetWord(rt, idx, val)',
        'ElseIf rt = "X" Or rt = "Y" Or rt = "M" Then',
        '  Engine.SetBit(rt, idx, val <> 0)',
        'End If',
        'SetRegField.Text = ""',
        'UpdateRegisters',
        'LDView.Refresh',
    ]),
    method('SetRegBtn_Pressed', 'sender As DesktopButton', '', [
        'ApplySetReg',
    ]),
    method('SetRegField_Action', 'sender As DesktopTextField', '', [
        'ApplySetReg',
    ]),
    method('ScrollUp_Pressed', 'sender As DesktopButton', '', [
        'LDView.ScrollY = LDView.ScrollY - 140',
        'If LDView.ScrollY < 0 Then LDView.ScrollY = 0',
        'LDView.Refresh',
    ]),
    method('ScrollDown_Pressed', 'sender As DesktopButton', '', [
        'LDView.ScrollY = LDView.ScrollY + 140',
        'LDView.Refresh',
    ]),
    method('X0_Pressed', 'sender As DesktopButton', '', ['Engine.XBits(0) = Not Engine.XBits(0)']),
    method('X1_Pressed', 'sender As DesktopButton', '', ['Engine.XBits(1) = Not Engine.XBits(1)']),
    method('X2_Pressed', 'sender As DesktopButton', '', ['Engine.XBits(2) = Not Engine.XBits(2)']),
    method('X3_Pressed', 'sender As DesktopButton', '', ['Engine.XBits(3) = Not Engine.XBits(3)']),
    method('X4_Pressed', 'sender As DesktopButton', '', ['Engine.XBits(4) = Not Engine.XBits(4)']),
    method('X5_Pressed', 'sender As DesktopButton', '', ['Engine.XBits(5) = Not Engine.XBits(5)']),
]

# ═══════════════════════════════════════════════════════════════════════════════
# BUILD SETTINGS (copy from MitsubishiPLCSim binary)
# ═══════════════════════════════════════════════════════════════════════════════
with open("/Users/brooksg44/Xojo/QuickStarts/MitsubishiPLCSim.xojo_binary_project", "rb") as f:
    REF = f.read()

def extract_block(data, offset):
    """Extract one block from binary starting at offset"""
    if offset + 8 > len(data):
        return None, offset
    block_type = data[offset+4:offset+8]
    size = struct.unpack('>I', data[offset+28:offset+32])[0] if offset+32 <= len(data) else 0

    # For build blocks, size is at offset+16
    size2 = struct.unpack('>I', data[offset+16:offset+20])[0] if offset+20 <= len(data) else 0
    # Use the one that makes sense (multiple of 1024)
    if size2 % 1024 == 0 and size2 > 0:
        block_size = size2
    elif size % 1024 == 0 and size > 0:
        block_size = size
    else:
        block_size = 0x400  # default

    return data[offset:offset+block_size], offset+block_size

# Extract build blocks from reference binary
BUILD_BLOCKS_DATA = []
for btype in [(0x281c,'BSts'),(0x2c1c,'Bsls'),(0x301c,'BSbu'),(0x341c,'Bsls'),(0x381c,'BSbu'),(0x3c1c,'BSsn'),(0x401c,'Bsls'),(0x441c,'BSbu')]:
    offset, name = btype
    blk, _ = extract_block(REF, offset)
    if blk:
        BUILD_BLOCKS_DATA.append(blk)

# ═══════════════════════════════════════════════════════════════════════════════
# ASSEMBLE PROJECT
# ═══════════════════════════════════════════════════════════════════════════════

random.seed(42)
_CTR[0] = 0x100  # start counter at 256

# ── BlokProj ─────────────────────────────────────────────────────────────────
proj_content  = s('PSIV', '2026.012')
proj_content += i('IDEv', 0x01352506)
proj_content += s('Ver1', '1')
proj_content += s('Ver2', '0')
proj_content += s('Ver3', '0')
proj_content += s('Rels', '0')
proj_content += s('NnRl', '0')
proj_content += s('Regn', '')
proj_content += s('SVer', '')
proj_content += s('LVer', '')
proj_content += s('IVer', '')
proj_content += i('aivi', 0)
proj_content += i('DVew', 0x23342aff)  # MainWindow block ID (seed=42, 5th xojo_id call)
proj_content += i('prTp', 0)           # 0=Desktop (not 1=Console)
proj_content += i('DLan', 0)
proj_content += i('CLan', 0)
proj_content += i('DEnc', 0)
proj_content += i('Bflg', 0x00004900)  # match SimpleBrowser flags
proj_content += i('UsBF', 1)
proj_content += i('prWA', 0)
proj_content += grp('Icon', b'')
proj_content += s('MacC', '')          # String, not Integer
proj_content += s('BCMO', 'MitsubishiPLCSim')
proj_content += s('BunI', 'com.xojo.mitsubishiplcsim')
proj_content += s('MDIc', '')
proj_content += s('BWin', 'MitsubishiPLCSim.exe')
proj_content += i('BMDI', 0)
proj_content += s('WcmN', 'Xojo')
proj_content += s('WpNm', '')
proj_content += s('WiNm', '')
proj_content += s('WiFd', '')
proj_content += i('GDIp', 0)
proj_content += i('hidp', 1)          # high-DPI support
proj_content += i('dkmd', 1)          # dark mode support
proj_content += s('BL86', 'MitsubishiPLCSim')
proj_content += s('DgCL', '')
proj_content += i('linA', 1)          # macOS arm64
proj_content += i('macA', 4)          # macOS x86_64
proj_content += i('winA', 1)          # Windows x64
proj_content += i('oPtL', 0)
proj_content += i('lncs', 1)          # line count
proj_content += i('cRDW', 0)
proj_content += i('IPDB', 0)
proj_content += i('WUI3', 0)
proj_content += i('NWUI', 0)
proj_content += s('WinV', '')
proj_content += i('runA', 0)
proj_content += s('MacV', '')
proj_content += s('plis', '')          # property list
proj_content += s('MASc', '')          # Mac App Store
proj_content += s('sPWD', '')          # password
blok_proj = make_block('Proj', proj_content)

# ── App class ────────────────────────────────────────────────────────────────
app_open_ev = method('Opening', '', '', [
    'Dim w As New MainWindow',
    'w.Show',
], is_event=True)

app_pdefs = [
    builtin_prop_val('MenuBar', 'Integer', '', vis=1, is_int=True, int_val=0),
]

app_body = code_obj('App', 'DesktopApplication',
                    events=(app_open_ev,),
                    pdefs=app_pdefs,
                    is_app=True)
blok_app = make_block('pObj', app_body)

# ── PLCInstruction class ──────────────────────────────────────────────────────
pinstr_body = code_obj('PLCInstruction', 'Object',
                       pdefs=PLC_INSTR_PROPS,
                       methods=PLC_INSTR_METHODS)
blok_pinstr = make_block('pObj', pinstr_body)

# ── PLCEngine class ───────────────────────────────────────────────────────────
pengine_body = code_obj('PLCEngine', 'Object',
                        pdefs=PLC_ENGINE_PROPS,
                        methods=PLC_ENGINE_METHODS)
blok_pengine = make_block('pObj', pengine_body)

# ── PLCCanvas class ───────────────────────────────────────────────────────────
pcanvas_body = code_obj('PLCCanvas', 'DesktopCanvas',
                        pdefs=PLC_CANVAS_PROPS,
                        events=PLC_CANVAS_EVENTS,
                        methods=PLC_CANVAS_METHODS)
blok_pcanvas = make_block('pObj', pcanvas_body)

# ── MainWindow class ──────────────────────────────────────────────────────────
mw_body = code_obj('MainWindow', 'DesktopWindow',
                   pdefs=MAIN_WINDOW_PROPS,
                   events=MAIN_WINDOW_EVENTS,
                   methods=MAIN_WINDOW_METHODS)
blok_mw = make_block('pDWn', mw_body)

# ── UI State block ────────────────────────────────────────────────────────────
blok_puis = make_puis_block()

# ── Assemble file ─────────────────────────────────────────────────────────────
file_header = b'RbBF' + b'\x00\x00\x00\x02' + b'\x00' * 8 + b'\x00\x00\x00\x1c' + b'\x00\x00\x00\x00' + bytes.fromhex('0134627c')

blocks = [blok_proj, blok_app, blok_pinstr, blok_pengine, blok_pcanvas, blok_mw]
for bd in BUILD_BLOCKS_DATA:
    blocks.append(bd)
blocks.append(blok_puis)

out_path = '/Users/brooksg44/Xojo/mitsubishi-plc-sim/MitsubishiPLCSim.xojo_binary_project'
with open(out_path, 'wb') as f:
    f.write(file_header)
    for blk in blocks:
        f.write(blk)
    f.write(b'EOF!')   # required end-of-file marker

sz = os.path.getsize(out_path)
print(f"Written: {out_path}")
print(f"Size: {sz:,} bytes ({sz//1024} KB)")
print(f"Blocks: {len(blocks)}")

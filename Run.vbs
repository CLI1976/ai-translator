' �ϥδ��N�覡���o�}�����|
VBS_PATH = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\") - 1)
AHK_PATH = VBS_PATH
AHK_EXE = AHK_PATH & "\AutoHotkey64.exe"
SCRIPT_PATH = AHK_PATH & "\ai-translator.ahk"

' �Ы� Shell ����
Set WshShell = CreateObject("WScript.Shell")
' �إߩR�O�C
cmd = """" & AHK_EXE & """ """ & SCRIPT_PATH & """"
' ����R�O�]0 ������õ����^
WshShell.Run cmd, 0, False
' �M�z
Set WshShell = Nothing
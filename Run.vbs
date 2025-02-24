' 使用替代方式取得腳本路徑
VBS_PATH = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\") - 1)
AHK_PATH = VBS_PATH
AHK_EXE = AHK_PATH & "\AutoHotkey64.exe"
SCRIPT_PATH = AHK_PATH & "\ai-translator.ahk"

' 創建 Shell 物件
Set WshShell = CreateObject("WScript.Shell")
' 建立命令列
cmd = """" & AHK_EXE & """ """ & SCRIPT_PATH & """"
' 執行命令（0 表示隱藏視窗）
WshShell.Run cmd, 0, False
' 清理
Set WshShell = Nothing